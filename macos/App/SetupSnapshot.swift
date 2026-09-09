import DropAgentIngest
import Foundation

enum SetupCardPolicy {
    static func shouldShowCard(
        dismissed: Bool,
        captureReady: Bool,
        isDiagnostic: Bool,
        panelVisible: Bool
    ) -> Bool {
        isDiagnostic == false && panelVisible && dismissed == false && captureReady == false
    }

    static func captureReady(_ setup: PageAdmitSetup) -> Bool {
        setup.captureReady
    }

    static func gearNeedsAttention(hasAgent: Bool, setup: PageAdmitSetup) -> Bool {
        hasAgent == false
            || setup.accessibilityTrusted == false
            || (setup.browsers.isEmpty == false && setup.browsers.contains(where: \.allowed) == false)
    }

    /// A silent denial may precede registration; keep an explicit request available.
    static func browserAction(allowed: Bool, running: Bool) -> BrowserSetupAction {
        if allowed { return .ready }
        if running == false { return .openAndAuthorize }
        return .authorize
    }
}

enum BrowserSetupAction: Equatable {
    case ready
    case authorize
    case openAndAuthorize
}

@MainActor
enum SetupCopy {
    static var title: String { Copy.t("使用准备", "Setup") }

    static var later: String { Copy.t("以后再说", "Later") }

    static var agentTitle: String { Copy.t("终端 Agent", "Terminal agent") }

    static func agentReady(_ name: String) -> String {
        Copy.t("已发现 \(name)", "Found \(name)")
    }

    static var agentMissing: String {
        Copy.t(
            "未发现终端 Agent。可以先把文件放在架子上。",
            "No terminal agent found. You can still put files on the shelf."
        )
    }

    static var installAgent: String { Copy.t("如何安装", "How to install") }

    static var toggleTitle: String {
        Copy.t("打开面板 \(HotKeyCenter.shared.toggleChord.label)", "Open panel \(HotKeyCenter.shared.toggleChord.label)")
    }

    static var toggleReady: String { Copy.t("可用", "Available") }

    static var toggleTaken: String {
        Copy.t("被占用，点菜单栏图标打开。", "Already in use. Click the menu bar icon to open.")
    }

    static var captureTitle: String {
        Copy.t("抓当前页 \(HotKeyCenter.shared.captureChord.label)", "Capture page \(HotKeyCenter.shared.captureChord.label)")
    }

    static var captureTaken: String {
        Copy.t("被占用，用菜单抓页。", "Already in use. Capture from the menu.")
    }

    static var filesTitle: String {
        Copy.t("加入选中文件 \(HotKeyCenter.shared.filesChord.label)", "Add selected files \(HotKeyCenter.shared.filesChord.label)")
    }

    static var filesTaken: String {
        Copy.t("被占用，用菜单加入选中文件。", "Already in use. Add selected files from the menu.")
    }

    static var finderTitle: String { Copy.t("Finder", "Finder") }

    static var finderReady: String { Copy.t("已允许控制 Finder", "Allowed to control Finder") }

    static var finderNeed: String {
        Copy.t(
            "把 Finder 里选中的文件加入架子，需要允许控制 Finder。",
            "Adding Finder selection needs control of Finder."
        )
    }

    static var accessibilityTitle: String { Copy.t("辅助功能", "Accessibility") }

    static var accessibilityReady: String { Copy.t("已开", "Enabled") }

    static var accessibilityNeed: String {
        Copy.t(
            "当前进程未获得辅助功能访问。若系统开关已开，请核对下方应用位置，并在授权后退出重开。",
            "This process does not have Accessibility access. If the system toggle is on, check the app location below and quit and reopen after granting access."
        )
    }

    static var accessibilityForeign: String {
        Copy.t(
            "检测到另一份 DropAgent 进程；当前进程尚未获得辅助功能访问。请核对授权的应用位置。",
            "Another DropAgent process was detected; this process lacks Accessibility access. Check which app location was granted access."
        )
    }

    static func automationStatus(_ row: PageAdmitBrowserRow) -> String {
        switch row.state {
        case .allowed: return browserReady(row.displayName)
        case .denied: return Copy.t("系统未许可控制\(row.displayName)。可请求授权，或到系统自动化设置核对。", "The system has not permitted control of \(row.displayName). Request access or check Automation settings.")
        case .notDetermined: return Copy.t("尚未决定是否允许控制\(row.displayName)。", "Access to \(row.displayName) has not been decided.")
        case .unavailable:
            return row.running
                ? Copy.t("暂时无法检测\(row.displayName)的授权状态。", "Cannot currently determine access to \(row.displayName).")
                : browserClosed(row.displayName)
        }
    }

    static var authorize: String { Copy.t("去授权", "Authorize") }

    static var openAndAuthorize: String { Copy.t("打开并授权", "Open and authorize") }

    static func browserReady(_ name: String) -> String {
        Copy.t("已允许控制\(name)", "Allowed to control \(name)")
    }

    static func browserNeed(_ name: String) -> String {
        Copy.t("抓页时要允许控制\(name)。", "Page capture needs control of \(name).")
    }

    static func browserClosed(_ name: String) -> String {
        Copy.t("打开\(name)后再授权。", "Open \(name), then authorize.")
    }
}

enum SetupFixtures {
    static let incomplete = PageAdmitSetup(
        accessibilityTrusted: false,
        browsers: [
            PageAdmitBrowserRow(
                displayName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                running: true,
                state: .notDetermined
            ),
            PageAdmitBrowserRow(
                displayName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                running: true,
                state: .notDetermined
            ),
        ]
    )

    static let ready = PageAdmitSetup(
        accessibilityTrusted: true,
        browsers: [
            PageAdmitBrowserRow(
                displayName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                running: true,
                state: .allowed
            ),
        ]
    )
}
