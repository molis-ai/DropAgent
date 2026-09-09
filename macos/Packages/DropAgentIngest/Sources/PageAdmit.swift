import AppKit
import DropAgentCapture
import Foundation

public struct PageAdmitToken: Equatable, Sendable {
    public static let none = PageAdmitToken(front: nil, explicitNone: true)

    let front: BrowserFront?
    let explicitNone: Bool

    public static func snapshot() -> PageAdmitToken {
        PageAdmitToken(front: CaptureLaunch.frozen ?? BrowserFront.current(), explicitNone: false)
    }

    var browser: BrowserFront? {
        explicitNone ? nil : front
    }
}

public struct PageAdmitDecision: Equatable, Sendable {
    public var proceed: Bool
    public var message: String
    public var offerPrivacySettings: Bool
    public var promptAccessibility: Bool

    public static let proceed = PageAdmitDecision(
        proceed: true,
        message: "",
        offerPrivacySettings: false,
        promptAccessibility: false
    )
}

public enum PageAdmitCopy {
    public static let noBrowser = CaptureRecovery.noBrowser
    public static let noBrowserHotKey = CaptureRecovery.noBrowserHotKey
    public static let needAccessibility = CaptureRecovery.needAccessibility
    public static let needAccessibilityRetry = CaptureRecovery.needAccessibilityRetry
}

public enum PageAdmitAutomation: Equatable, Sendable {
    case allowed
    case denied
    case notDetermined
    case unavailable

    init(_ state: AutomationState) {
        switch state {
        case .allowed: self = .allowed
        case .denied: self = .denied
        case .notDetermined: self = .notDetermined
        case .unavailable: self = .unavailable
        }
    }
}

public struct PageAdmitBrowserRow: Equatable, Sendable, Identifiable {
    public var id: String { bundleIdentifier }
    public var displayName: String
    public var bundleIdentifier: String
    public var running: Bool
    public var state: PageAdmitAutomation

    public var allowed: Bool { state == .allowed }

    public init(
        displayName: String,
        bundleIdentifier: String,
        running: Bool,
        state: PageAdmitAutomation
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.running = running
        self.state = state
    }
}

public struct PageAdmitSetup: Equatable, Sendable {
    public var accessibilityTrusted: Bool
    public var accessibilityForeignCopy: Bool
    public var browsers: [PageAdmitBrowserRow]
    public var finder: PageAdmitBrowserRow

    public init(
        accessibilityTrusted: Bool,
        accessibilityForeignCopy: Bool = false,
        browsers: [PageAdmitBrowserRow],
        finder: PageAdmitBrowserRow = PageAdmitBrowserRow(
            displayName: "Finder",
            bundleIdentifier: "com.apple.finder",
            running: true,
            state: .notDetermined
        )
    ) {
        self.accessibilityTrusted = accessibilityTrusted
        self.accessibilityForeignCopy = accessibilityForeignCopy
        self.browsers = browsers
        self.finder = finder
    }

    public var captureReady: Bool {
        accessibilityTrusted && (browsers.isEmpty || browsers.contains(where: \.allowed))
    }

    public static let empty = PageAdmitSetup(accessibilityTrusted: false, browsers: [])
}

public enum PageAdmit {
    public static func freezeFrontBrowser() {
        CaptureLaunch.freeze()
    }

    public static func isTrusted() -> Bool {
        AccessibilityPage.isTrusted()
    }

    public static func requestTrustIfNeeded() {
        AccessibilityPage.requestTrustIfNeeded()
    }

    public static func setupStatus() -> PageAdmitSetup {
        wrap(
            CapturePermissions.liveStatus(),
            foreignCopy: AccessibilityPage.isTrusted() == false && AccessibilityPage.hasSiblingDropAgent()
        )
    }

    public static func setupStatus(_ status: CapturePermissionStatus) -> PageAdmitSetup {
        wrap(status, foreignCopy: false)
    }

    public static func privacyTargetOffMain(token: PageAdmitToken) async -> PageAdmitBrowserRow? {
        await PermissionWork.run { privacyTarget(token: token) }
    }

    public static func decideOffMain(token: PageAdmitToken) async -> PageAdmitDecision {
        await PermissionWork.run { decide(token: token) }
    }

    public static func failureOffMain(token: PageAdmitToken) async -> PageAdmitDecision {
        await PermissionWork.run { failure(token: token) }
    }

    public static func setupStatusOffMain() async -> PageAdmitSetup {
        await PermissionWork.run { setupStatus() }
    }

    public static func requestAutomationOffMain(bundleIdentifier: String) async -> PageAdmitAutomation {
        PageAdmitAutomation(await AutomationAccess.requestIfNeededOffMain(bundleIdentifier: bundleIdentifier))
    }

    public static func privacyTarget(token: PageAdmitToken) -> PageAdmitBrowserRow? {
        guard let browser = token.browser, browser.kind.usesAppleScript else { return nil }
        let bundle = NSRunningApplication(processIdentifier: browser.pid)?.bundleIdentifier
            ?? browser.kind.primaryBundleIdentifier
        let running = NSRunningApplication(processIdentifier: browser.pid) != nil
        return PageAdmitBrowserRow(
            displayName: browser.kind.appleScriptName,
            bundleIdentifier: bundle,
            running: running,
            state: PageAdmitAutomation(AutomationAccess.probe(bundleIdentifier: bundle))
        )
    }

    private static func wrap(_ status: CapturePermissionStatus, foreignCopy: Bool) -> PageAdmitSetup {
        PageAdmitSetup(
            accessibilityTrusted: status.accessibilityTrusted,
            accessibilityForeignCopy: foreignCopy,
            browsers: status.browsers.map {
                PageAdmitBrowserRow(
                    displayName: $0.kind.appleScriptName,
                    bundleIdentifier: $0.bundleIdentifier,
                    running: $0.running,
                    state: PageAdmitAutomation($0.state)
                )
            },
            finder: FrontAdmit.finderRow()
        )
    }

    public static func decide(token: PageAdmitToken) -> PageAdmitDecision {
        let target = token.browser
        let ax = AccessibilityPage.isTrusted()
        let automation = automationAllowed(for: target)
        switch CaptureRecovery.decision(target: target, axTrusted: ax, automationAllowed: automation) {
        case .proceed:
            return .proceed
        case .stop(let message, let offer):
            return PageAdmitDecision(
                proceed: false,
                message: message,
                offerPrivacySettings: offer,
                promptAccessibility: offer && ax == false
            )
        }
    }

    public static func failure(token: PageAdmitToken) -> PageAdmitDecision {
        let target = token.browser
        let ax = AccessibilityPage.isTrusted()
        let automation = automationAllowed(for: target)
        let failed = CaptureRecovery.failure(target: target, axTrusted: ax, automationAllowed: automation)
        return PageAdmitDecision(
            proceed: false,
            message: failed.message,
            offerPrivacySettings: failed.offerPrivacySettings,
            promptAccessibility: failed.offerPrivacySettings && ax == false
        )
    }

    private static func automationAllowed(for target: BrowserFront?) -> Bool {
        guard let target else { return false }
        switch target.kind {
        case .safari, .chrome, .edge, .brave:
            let bundle = NSRunningApplication(processIdentifier: target.pid)?.bundleIdentifier
                ?? target.kind.primaryBundleIdentifier
            return AutomationAccess.isAllowed(bundleIdentifier: bundle)
        case .arc, .firefox:
            return false
        }
    }
}
