import Foundation

public enum CaptureRecovery: Equatable, Sendable {
    public static let noBrowser = "没读到当前页。把 Safari、Chrome 或 Edge 放到最前面，再抓一次。"
    public static let noBrowserHotKey = "没读到当前页。把 Safari、Chrome 或 Edge 放到最前面，再按 ⌃⌥W。"
    public static let needAccessibility = "第一次抓页需要授权。点「去授权」，允许辅助功能后再点「再试」。"
    public static let needAccessibilityRetry = "需要辅助功能才能读当前页地址。点「去授权」，允许后再点「再试」。"

    public enum Decision: Equatable, Sendable {
        case proceed
        case stop(message: String, offerPrivacySettings: Bool)
    }

    public struct Failure: Equatable, Sendable {
        public var message: String
        public var offerPrivacySettings: Bool

        public init(message: String, offerPrivacySettings: Bool) {
            self.message = message
            self.offerPrivacySettings = offerPrivacySettings
        }
    }

    public static func decision(
        target: BrowserFront?,
        axTrusted: Bool,
        automationAllowed: Bool
    ) -> Decision {
        guard target != nil else {
            return .stop(message: noBrowser, offerPrivacySettings: false)
        }
        if axTrusted == false && automationAllowed == false {
            return .stop(message: needAccessibility, offerPrivacySettings: true)
        }
        return .proceed
    }

    public static func failure(
        target: BrowserFront?,
        axTrusted: Bool,
        automationAllowed: Bool
    ) -> Failure {
        guard let target else {
            return Failure(message: noBrowser, offerPrivacySettings: false)
        }
        if axTrusted == false {
            return Failure(message: needAccessibilityRetry, offerPrivacySettings: true)
        }
        let name = target.kind.appleScriptName
        switch target.kind {
        case .safari, .chrome, .edge, .brave:
            if automationAllowed == false {
                return Failure(
                    message: "辅助功能已开，还要允许控制\(name)。点「去授权」。",
                    offerPrivacySettings: true
                )
            }
            return Failure(
                message: "读到了\(name)，但没拿到地址。确认当前是网页，再试一次。",
                offerPrivacySettings: false
            )
        case .arc, .firefox:
            return Failure(
                message: "读到了\(name)，但没拿到地址。把地址栏露出来再试。",
                offerPrivacySettings: false
            )
        }
    }
}
