import DropAgentIngest
import Foundation

enum SetupCardPolicy {
    static func shouldShowCard(
        dismissed: Bool,
        captureReady: Bool,
        isDiagnostic: Bool,
        panelVisible: Bool,
        requested: Bool
    ) -> Bool {
        isDiagnostic == false
            && panelVisible
            && dismissed == false
            && captureReady == false
            && requested
    }

    static func captureReady(_ setup: PageAdmitSetup) -> Bool {
        setup.captureReady
    }

    static func gearNeedsAttention(hasAgent: Bool, setup: PageAdmitSetup) -> Bool {
        hasAgent == false
            || setup.accessibilityTrusted == false
            || (setup.browsers.isEmpty == false && setup.browsers.contains(where: \.allowed) == false)
    }

    static func shouldShowCaptureBanner(
        onboarded: Bool,
        isEmpty: Bool,
        captureReady: Bool,
        dismissed: Bool,
        isDiagnostic: Bool,
        covering: Bool
    ) -> Bool {
        onboarded
            && isEmpty
            && captureReady == false
            && dismissed == false
            && isDiagnostic == false
            && covering == false
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
    static var title: String { Copy.t("权限与连接", "Permissions & connections") }

    static var overlayLead: String {
        Copy.t(
            "按需开启网页抓取和 Finder 文件导入。直接拖入文件无需授权。",
            "Enable page capture and Finder import as needed. Dropping files requires no permissions."
        )
    }

    static var later: String { Copy.t("暂不设置", "Not now") }

    static var prepare: String { Copy.t("设置权限", "Set up permissions") }

    static var bannerTitle: String { Copy.t("网页抓取需要授权", "Page capture needs permission") }

    static var bannerDetail: String { Copy.t("添加文件和本机文字提取可直接使用。", "Adding files and on-device text extraction are ready to use.") }

    static var captureGroupTitle: String { Copy.t("抓当前页", "Page capture") }

    static var captureGroupLead: String {
        Copy.t(
            "只需授权要使用的浏览器。",
            "Allow access to the browsers you use."
        )
    }

    static var agentSection: String { Copy.t("终端", "Terminal") }

    static var finderSection: String { Copy.t("从 Finder 加入", "Finder") }

    static var agentTitle: String { Copy.t("终端 Agent", "Terminal agent") }

    static func agentReady(_ name: String) -> String {
        Copy.t("已发现 \(name)", "Found \(name)")
    }

    static var agentMissing: String {
        Copy.t(
            "未检测到本机 Agent。添加文件和文字提取仍可使用。",
            "No local agent found. Adding files and text extraction are still available."
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
            "把 Finder 里选中的文件加入材料，需要允许控制 Finder。",
            "Adding Finder selection needs control of Finder."
        )
    }

    static var accessibilityTitle: String { Copy.t("辅助功能", "Accessibility") }

    static var accessibilityReady: String { Copy.t("已打开", "On") }

    static var accessibilityNeed: String {
        Copy.t(
            "读取当前页地址需要它。点允许后，在系统提示里打开设置，并打开 DropAgent。",
            "Needed to read the current page address. Allow, then turn DropAgent on in the system prompt."
        )
    }

    static var accessibilityNeedShort: String {
        Copy.t("读取当前页地址需要它。", "Needed to read the current page address.")
    }

    static var accessibilityForeign: String {
        Copy.t(
            "系统列表里开着的可能是另一份 DropAgent。请核对该应用。",
            "The toggle in System Settings may belong to another copy of DropAgent. Check which app was allowed."
        )
    }

    static var openAccessibilitySettings: String {
        Copy.t("打开辅助功能设置", "Open Accessibility Settings")
    }

    static func automationStatus(_ row: PageAdmitBrowserRow, compact: Bool = false) -> String {
        switch row.state {
        case .allowed: return browserReady(row.displayName)
        case .denied:
            return Copy.t(
                "还没允许控制\(row.displayName)。可再请求一次，或打开自动化设置。",
                "Control of \(row.displayName) is not allowed. Request again, or open Automation settings."
            )
        case .notDetermined:
            return compact
                ? browserNeed(row.displayName)
                : Copy.t("尚未允许控制\(row.displayName)。", "Control of \(row.displayName) has not been allowed yet.")
        case .unavailable:
            return row.running
                ? Copy.t("暂时无法检测\(row.displayName)的授权状态。", "Cannot currently determine access to \(row.displayName).")
                : browserClosed(row.displayName)
        }
    }

    static var authorize: String { Copy.t("允许", "Allow") }

    static var openAndAuthorize: String { Copy.t("打开并允许", "Open and allow") }

    static var openAutomationSettings: String { Copy.t("打开自动化设置", "Open Automation Settings") }

    static func browserReady(_ name: String) -> String {
        Copy.t("已允许控制\(name)", "Allowed to control \(name)")
    }

    static func browserNeed(_ name: String) -> String {
        Copy.t("抓 \(name) 当前页需要允许控制它。", "Capturing a \(name) page needs control of it.")
    }

    static func browserClosed(_ name: String) -> String {
        Copy.t("打开\(name)后再允许。", "Open \(name), then allow.")
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
