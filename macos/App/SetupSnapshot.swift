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
            || setup.browsers.contains { $0.allowed == false }
    }

    /// Silent probe often reports denied before Chrome is even in the TCC list.
    /// The row must still request; opening Automation settings cannot add it.
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
    static var title: String { Copy.t("使用准备", "Getting ready") }

    static var later: String { Copy.t("以后再说", "Not now") }

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
        Copy.t("被占用，点菜单栏图标打开。", "Taken. Click the menu bar icon to open.")
    }

    static var captureTitle: String {
        Copy.t("抓当前页 \(HotKeyCenter.shared.captureChord.label)", "Capture page \(HotKeyCenter.shared.captureChord.label)")
    }

    static var captureTaken: String {
        Copy.t("被占用，用菜单抓页。", "Taken. Capture from the menu.")
    }

    static var filesTitle: String {
        Copy.t("加入选中文件 \(HotKeyCenter.shared.filesChord.label)", "Add selected files \(HotKeyCenter.shared.filesChord.label)")
    }

    static var filesTaken: String {
        Copy.t("被占用，用菜单加入选中文件。", "Taken. Add selected files from the menu.")
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

    static var accessibilityReady: String { Copy.t("已开", "On") }

    static var accessibilityNeed: String {
        Copy.t(
            "当前这份还没被信任。列表里开着的可能是另一份。只留菜单栏里这份，把开关关再开，然后完全退出再打开。",
            "This copy is not trusted yet. The one in System Settings may be another copy. Leave only this menu bar app, toggle Accessibility off and on, then fully quit and reopen."
        )
    }

    static var accessibilityForeign: String {
        Copy.t(
            "还有另一份 DropAgent 在跑。关掉其他份，只留菜单栏里这份，把开关关再开，然后完全退出再打开。",
            "Another DropAgent is running. Quit the others, leave this menu bar one, toggle Accessibility off and on, then fully quit and reopen."
        )
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
