import AppKit
import Foundation

public struct BrowserWindowOwner: Equatable, Sendable {
    public var bundleID: String
    public var pid: pid_t
    public var layer: Int

    public init(bundleID: String, pid: pid_t, layer: Int) {
        self.bundleID = bundleID
        self.pid = pid
        self.layer = layer
    }
}

public struct BrowserFront: Equatable, Sendable {
        public enum Kind: String, Sendable {
        case safari
        case chrome
        case edge
        case brave
        case arc
        case firefox

        public static func from(bundleID: String) -> Kind? {
            switch bundleID.lowercased() {
            case "com.apple.safari":
                return .safari
            case "com.google.chrome", "com.google.chrome.canary", "com.google.chrome.beta", "com.google.chrome.dev":
                return .chrome
            case "com.microsoft.edgemac":
                return .edge
            case "com.brave.browser":
                return .brave
            case "company.thebrowser.browser":
                return .arc
            case "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition":
                return .firefox
            default:
                return nil
            }
        }

        public var appleScriptName: String {
            switch self {
            case .safari: return "Safari"
            case .chrome: return "Google Chrome"
            case .edge: return "Microsoft Edge"
            case .brave: return "Brave Browser"
            case .arc: return "Arc"
            case .firefox: return "Firefox"
            }
        }

        public var primaryBundleIdentifier: String {
            switch self {
            case .safari: return "com.apple.Safari"
            case .chrome: return "com.google.chrome"
            case .edge: return "com.microsoft.edgemac"
            case .brave: return "com.brave.Browser"
            case .arc: return "company.thebrowser.Browser"
            case .firefox: return "org.mozilla.firefox"
            }
        }

        public var usesAppleScript: Bool {
            switch self {
            case .safari, .chrome, .edge, .brave: return true
            case .arc, .firefox: return false
            }
        }
    }

    public var kind: Kind
    public var pid: pid_t

    public init(kind: Kind, pid: pid_t) {
        self.kind = kind
        self.pid = pid
    }

    public static func resolve(
        frontmostBundle: String?,
        frontmostPID: pid_t,
        selfBundle: String,
        windows: [BrowserWindowOwner]
    ) -> BrowserFront? {
        if let bundle = frontmostBundle, let kind = Kind.from(bundleID: bundle) {
            return BrowserFront(kind: kind, pid: frontmostPID)
        }
        guard isSelfApp(frontmostBundle, selfBundle: selfBundle) else {
            return nil
        }
        for window in windows where window.layer == 0 {
            if let kind = Kind.from(bundleID: window.bundleID) {
                return BrowserFront(kind: kind, pid: window.pid)
            }
        }
        return nil
    }

    public static func current(selfBundle: String = Bundle.main.bundleIdentifier ?? "local.dropagent") -> BrowserFront? {
        let front = NSWorkspace.shared.frontmostApplication
        return resolve(
            frontmostBundle: front?.bundleIdentifier,
            frontmostPID: front?.processIdentifier ?? 0,
            selfBundle: selfBundle,
            windows: onScreenOwners()
        )
    }

    public static func onScreenOwners() -> [BrowserWindowOwner] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        return owners(from: list)
    }

    public static func owners(from windows: [[String: Any]]) -> [BrowserWindowOwner] {
        var order: [pid_t] = []
        var best: [pid_t: BrowserWindowOwner] = [:]
        for info in windows {
            guard let pid = CGWindowInfo.processID(info),
                  let layer = CGWindowInfo.layer(info)
            else { continue }
            let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
            let owner = BrowserWindowOwner(bundleID: bundle, pid: pid, layer: layer)
            if best[pid] == nil {
                order.append(pid)
                best[pid] = owner
            } else if best[pid]?.layer != 0 && layer == 0 {
                best[pid] = owner
            }
        }
        return order.compactMap { best[$0] }
    }

    private static func isSelfApp(_ bundle: String?, selfBundle: String) -> Bool {
        let id = (bundle ?? "").lowercased()
        if id == selfBundle.lowercased() { return true }
        return id.contains("dropagent")
    }
}

enum CGWindowInfo {
    static func processID(_ info: [String: Any]) -> pid_t? {
        let raw = info[kCGWindowOwnerPID as String]
        if let pid = raw as? pid_t { return pid }
        if let value = raw as? Int { return pid_t(value) }
        if let value = raw as? Int32 { return pid_t(value) }
        if let value = raw as? NSNumber { return pid_t(truncating: value) }
        return nil
    }

    static func layer(_ info: [String: Any]) -> Int? {
        let raw = info[kCGWindowLayer as String]
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        return nil
    }

    static func windowNumber(_ info: [String: Any]) -> CGWindowID? {
        let raw = info[kCGWindowNumber as String]
        if let number = raw as? CGWindowID { return number }
        if let value = raw as? Int { return CGWindowID(value) }
        if let value = raw as? UInt32 { return CGWindowID(value) }
        if let value = raw as? NSNumber { return CGWindowID(truncating: value) }
        return nil
    }

    static func area(_ info: [String: Any]) -> CGFloat {
        guard let bounds = info[kCGWindowBounds as String] as? [String: Any] else { return 0 }
        return cgFloat(bounds["Width"]) * cgFloat(bounds["Height"])
    }

    private static func cgFloat(_ raw: Any?) -> CGFloat {
        if let value = raw as? CGFloat { return value }
        if let value = raw as? Double { return CGFloat(value) }
        if let value = raw as? Int { return CGFloat(value) }
        if let value = raw as? NSNumber { return CGFloat(truncating: value) }
        return 0
    }
}
