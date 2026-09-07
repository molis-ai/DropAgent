import AppKit
import ApplicationServices
import Foundation

public enum AutomationState: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
    case unavailable
}

/// Probe Automation (Apple Events) without presenting the system prompt.
/// Calling osascript when the user has not allowed control is what previously
/// put DropAgent into an uninterruptible wait on the TCC dialog.
public enum AutomationAccess {
    public static func isAllowed(bundleIdentifier: String) -> Bool {
        probe(bundleIdentifier: bundleIdentifier) == .allowed
    }

    public static func probe(bundleIdentifier: String) -> AutomationState {
        silentState(determine(bundleIdentifier: bundleIdentifier, ask: false))
    }

    /// Silent TCC reads often return denied before the app is in the list.
    public static func silentState(_ state: AutomationState) -> AutomationState {
        switch state {
        case .allowed:
            return .allowed
        case .denied, .notDetermined:
            return .notDetermined
        case .unavailable:
            return .unavailable
        }
    }

    /// In-process TCC prompt. Do not spawn osascript to trigger this.
    public static func requestIfNeeded(bundleIdentifier: String) -> AutomationState {
        let live = resolvedBundleIdentifier(bundleIdentifier)
        if probe(bundleIdentifier: live) == .allowed { return .allowed }
        let asked = determine(bundleIdentifier: live, ask: true)
        if asked == .allowed { return .allowed }
        guard runningRegularApp(live) != nil else { return asked }
        sendConsentPing(bundleIdentifier: live)
        return probe(bundleIdentifier: live)
    }

    /// Blocking prompt after the panel is hidden. TCC must run on the main thread.
    public static func requestIfNeededOffMain(bundleIdentifier: String) async -> AutomationState {
        let live = resolvedBundleIdentifier(bundleIdentifier)
        if probe(bundleIdentifier: live) == .allowed { return .allowed }
        return await MainActor.run {
            requestIfNeeded(bundleIdentifier: live)
        }
    }

    public static func resolvedBundleIdentifier(_ bundleIdentifier: String) -> String {
        runningRegularApp(bundleIdentifier)?.bundleIdentifier ?? bundleIdentifier
    }

    private static func determine(bundleIdentifier: String, ask: Bool) -> AutomationState {
        let live = resolvedBundleIdentifier(bundleIdentifier)
        let target = targetDescriptor(bundleIdentifier: live)
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            ask
        )
        return state(from: status)
    }

    private static func targetDescriptor(bundleIdentifier: String) -> NSAppleEventDescriptor {
        if let app = runningRegularApp(bundleIdentifier) {
            var pid = app.processIdentifier
            if let desc = NSAppleEventDescriptor(
                descriptorType: typeKernelProcessID,
                bytes: &pid,
                length: MemoryLayout<pid_t>.size
            ) {
                return desc
            }
        }
        return NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
    }

    /// One in-process read-only event so TCC records the running app.
    /// Do not spawn /usr/bin/osascript — that would own the consent.
    private static func sendConsentPing(bundleIdentifier: String) {
        let live = resolvedBundleIdentifier(bundleIdentifier)
        let escaped = live
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        guard let script = NSAppleScript(source: "tell application id \"\(escaped)\" to get name") else {
            return
        }
        var error: NSDictionary?
        _ = script.executeAndReturnError(&error)
    }

    private static func runningRegularApp(_ bundleIdentifier: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { app in
            app.activationPolicy == .regular
                && app.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    public static func state(from status: OSStatus) -> AutomationState {
        switch status {
        case noErr:
            return .allowed
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        default:
            return .unavailable
        }
    }
}
