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
