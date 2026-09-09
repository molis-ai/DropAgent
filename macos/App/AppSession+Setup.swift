import AppKit
import DropAgentIngest
import Foundation

extension AppSession {
    func retryCapture() {
        guard isCapturing == false, isAdmittingFiles == false else { return }
        if retryFrontFiles {
            Task { await admitFrontSelection() }
        } else {
            Task { await captureCurrentPage() }
        }
    }

    func dismissError() {
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        retryFrontFiles = false
        filesPrivacy = .none
    }

    func openPrivacySettings() {
        Task { await authorizeCaptureFailure() }
    }

    func refreshSetup() {
        if let override = setupPermissionsOverride {
            applySetup(override)
            return
        }
        // AX trust can change while Automation is waiting for system consent.
        let trusted = PageAdmit.isTrusted()
        if setup.accessibilityTrusted != trusted { setup.accessibilityTrusted = trusted }
        guard setupRefreshing == false, authorizingID == nil else { return }
        setupRefreshing = true
        Task {
            let updated = await PageAdmit.setupStatusOffMain()
            setupRefreshing = false
            guard setupPermissionsOverride == nil else { return }
            applySetup(updated)
        }
    }

    private func applySetup(_ updated: PageAdmitSetup) {
        let showing = setupLoaded && showsSetupCard
        if setup != updated { setup = updated }
        if !setupLoaded { setupLoaded = true }
        if showing && SetupCardPolicy.captureReady(setup) {
            dismissSetupCard()
        }
    }

    func dismissSetupCard() {
        guard prefs.setupCardDismissed == false else { return }
        prefs.setupCardDismissed = true
        prefs.save()
    }

    func beginSetupWatch() {
        setupWatchCount += 1
        guard setupWatchTask == nil else { return }
        setupWatchTask = Task { @MainActor in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard Task.isCancelled == false else { break }
                refreshSetup()
            }
        }
    }

    func endSetupWatch() {
        setupWatchCount = max(0, setupWatchCount - 1)
        guard setupWatchCount == 0 else { return }
        setupWatchTask?.cancel()
        setupWatchTask = nil
    }

    func openAutomationSettings() {
        openSystemPane(Self.automationPanes)
    }

    func authorizeAccessibility() {
        Task { await authorizeAccessibilityNow() }
    }

    func authorizeBrowser(_ row: PageAdmitBrowserRow) {
        Task { await authorizeBrowserRow(row, openSettingsIfDenied: true) }
    }

    private func authorizeAccessibilityNow() async {
        guard authorizingID == nil else { return }
        authorizingID = "ax"
        StatusChrome.hideForPrompt()
        PageAdmit.requestTrustIfNeeded()
        openSystemPane(Self.accessibilityPanes)
        StatusChrome.finishPromptKeepHidden()
        authorizingID = nil
        refreshSetup()
    }

    private func authorizeCaptureFailure() async {
        if retryFrontFiles {
            switch filesPrivacy {
            case .finder:
                await authorizeBrowserRow(setup.finder, openSettingsIfDenied: true)
            case .accessibility, .none:
                await authorizeAccessibilityNow()
            }
            return
        }
        if PageAdmit.isTrusted() == false {
            await authorizeAccessibilityNow()
            return
        }
        let token = lastCaptureToken ?? .snapshot()
        if let target = await PageAdmit.privacyTargetOffMain(token: token) {
            await authorizeBrowserRow(target, openSettingsIfDenied: true)
            return
        }
    }

    private func authorizeBrowserRow(_ row: PageAdmitBrowserRow, openSettingsIfDenied: Bool) async {
        guard authorizingID == nil else { return }
        authorizingID = row.bundleIdentifier
        authorizationSlow = false
        let waiting = Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard Task.isCancelled == false else { return }
            authorizationSlow = true
        }
        defer {
            waiting.cancel()
            authorizingID = nil
            authorizationSlow = false
            refreshSetup()
        }
        let bundle = row.bundleIdentifier
        var running = row.running
        if running == false {
            running = await openBrowser(bundleIdentifier: bundle)
            refreshSetup()
            if running == false {
                authorizingID = nil
                return
            }
        }
        let state = await PageAdmit.requestAutomationOffMain(bundleIdentifier: bundle)
        if openSettingsIfDenied && state == .denied {
            openSystemPane(Self.automationPanes)
        }
    }

    private func openBrowser(bundleIdentifier: String) async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            return false
        }
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if isBrowserRunning(bundleIdentifier) { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return isBrowserRunning(bundleIdentifier)
    }

    private func isBrowserRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    private func openSystemPane(_ panes: [String]) {
        for pane in panes {
            if let url = URL(string: pane), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private static let accessibilityPanes = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    ]

    private static let automationPanes = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
    ]
}
