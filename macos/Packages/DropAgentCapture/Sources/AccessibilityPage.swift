import AppKit
import ApplicationServices
import Foundation

public enum AccessibilityPage {
    public static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func hasSiblingDropAgent() -> Bool {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.contains { app in
            guard app.processIdentifier != selfPID, !app.isTerminated else { return false }
            let bid = app.bundleIdentifier?.lowercased() ?? ""
            let exe = app.executableURL?.lastPathComponent.lowercased() ?? ""
            return bid == "local.dropagent" || bid == "local.dropagent.review" || exe == "dropagent"
        }
    }

    public static func requestTrustIfNeeded() {
        if isTrusted() { return }
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static func read(pid: pid_t) -> (url: URL, title: String)? {
        guard AccessibilityPage.isTrusted() else { return nil }
        let deadline = Date().addingTimeInterval(1.2)
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.35)
        for window in windowsToRead(of: app) {
            if Date() > deadline { return nil }
            if let page = readWindow(window, deadline: deadline) {
                return page
            }
        }
        return nil
    }

    public static func roleRank(_ role: String) -> Int {
        switch role {
        case "AXWebArea": return 3
        case "AXComboBox", "AXTextField": return 2
        case "AXToolbar", "AXGroup": return 1
        default: return 0
        }
    }

    public static func childVisitOrder(roles: [String]) -> [Int] {
        roles.indices.sorted { roleRank(roles[$0]) > roleRank(roles[$1]) }
    }

    public static func windowScore(subrole: String?) -> Int {
        switch subrole {
        case "AXStandardWindow": return 5
        case "AXDialog", "AXSystemDialog", "AXFloatingWindow": return 0
        default: return 1
        }
    }

    public static func httpURL(from raw: Any) -> URL? {
        if let url = raw as? URL { return isHTTP(url) ? url : nil }
        if let text = raw as? String {
            return parse(text)
        }
        if let text = raw as? NSString {
            return parse(text as String)
        }
        return nil
    }

    static func windowsToRead(of app: AXUIElement) -> [AXUIElement] {
        var list: [AXUIElement] = []
        func append(_ window: AXUIElement?) {
            guard let window else { return }
            if list.contains(where: { CFEqual($0, window) }) { return }
            list.append(window)
        }
        append(copyElement(app, kAXFocusedWindowAttribute as CFString))
        append(copyElement(app, kAXMainWindowAttribute as CFString))
        for window in windows(of: app) {
            append(window)
        }
        return list
    }

    static func windows(of app: AXUIElement) -> [AXUIElement] {
        var listRef: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &listRef)
        let list = (listRef as? [AXUIElement]) ?? []
        return list.sorted { a, b in
            windowScore(subrole: subrole(a)) > windowScore(subrole: subrole(b))
        }
    }

    static func copyElement(_ parent: AXUIElement, _ attribute: CFString) -> AXUIElement? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute, &ref) == .success,
              let ref,
              CFGetTypeID(ref) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return unsafeDowncast(ref, to: AXUIElement.self)
    }

    static func subrole(_ element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &ref)
        return ref as? String
    }

    private static func readWindow(_ window: AXUIElement, deadline: Date) -> (url: URL, title: String)? {
        AXUIElementSetMessagingTimeout(window, 0.35)
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = PageTitle.cleaned(titleRef as? String ?? "")
        if Date() > deadline { return nil }

        var documentRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &documentRef) == .success,
           let url = httpURL(from: documentRef as Any)
        {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        var windowURL: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXURL" as CFString, &windowURL) == .success,
           let url = httpURL(from: windowURL as Any)
        {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        if let url = webAreaURL(in: window, deadline: deadline) {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        if let url = toolbarURL(in: window, deadline: deadline) {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        var descriptionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXDescriptionAttribute as CFString, &descriptionRef) == .success,
           let url = httpURL(from: descriptionRef as Any)
        {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        if let url = httpURL(from: title) {
            return (url, title)
        }

        if let url = firstURL(in: window, deadline: deadline) {
            return (url, title.isEmpty ? url.absoluteString : title)
        }
        return nil
    }

    private static func parse(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), isHTTP(url) {
            return url
        }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range),
              let url = match.url
        else { return nil }
        return isHTTP(url) ? url : nil
    }

    private static func toolbarURL(in window: AXUIElement, deadline: Date) -> URL? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement]
        else { return nil }
        for child in list.prefix(20) {
            if Date() > deadline { return nil }
            AXUIElementSetMessagingTimeout(child, 0.2)
            if let url = urlValue(child) { return url }
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""
            guard role == "AXToolbar" || role == "AXGroup" || role == "AXTabGroup" else { continue }
            var nested: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &nested) == .success,
                  let kids = nested as? [AXUIElement]
            else { continue }
            for kid in kids.prefix(24) {
                if Date() > deadline { return nil }
                AXUIElementSetMessagingTimeout(kid, 0.2)
                if let url = urlValue(kid) { return url }
                var kidRole: CFTypeRef?
                AXUIElementCopyAttributeValue(kid, kAXRoleAttribute as CFString, &kidRole)
                if (kidRole as? String) == "AXGroup" {
                    var inner: CFTypeRef?
                    if AXUIElementCopyAttributeValue(kid, kAXChildrenAttribute as CFString, &inner) == .success,
                       let innerKids = inner as? [AXUIElement]
                    {
                        for nestedKid in innerKids.prefix(16) {
                            AXUIElementSetMessagingTimeout(nestedKid, 0.2)
                            if let url = urlValue(nestedKid) { return url }
                        }
                    }
                }
            }
        }
        return nil
    }

    private static func webAreaURL(in element: AXUIElement, deadline: Date, depth: Int = 0) -> URL? {
        if Date() > deadline { return nil }
        AXUIElementSetMessagingTimeout(element, 0.15)
        let roleName = role(element)
        if roleName == "AXWebArea" {
            AXUIElementSetMessagingTimeout(element, 0.4)
            return urlValue(element)
        }
        guard depth < 6 else { return nil }
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
              let list = children as? [AXUIElement], list.isEmpty == false
        else {
            return nil
        }
        let ordered = Array(list.prefix(12)).enumerated()
            .sorted { roleRank(role($0.element)) > roleRank(role($1.element)) }
            .map(\.element)
        for child in ordered {
            if let url = webAreaURL(in: child, deadline: deadline, depth: depth + 1) {
                return url
            }
        }
        return nil
    }

    private static func firstURL(in window: AXUIElement, deadline: Date) -> URL? {
        var remaining = 24
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var index = 0
        while index < queue.count, remaining > 0 {
            if Date() > deadline { return nil }
            remaining -= 1
            let (element, depth) = queue[index]
            index += 1
            AXUIElementSetMessagingTimeout(element, 0.15)
            if let url = urlValue(element) { return url }
            guard depth < 6 else { continue }
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
                  let list = children as? [AXUIElement]
            else { continue }
            let ranked = list.prefix(16).sorted { roleRank(role($0)) > roleRank(role($1)) }
            for child in ranked {
                queue.append((child, depth + 1))
            }
        }
        return nil
    }

    private static func role(_ element: AXUIElement) -> String {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        return roleRef as? String ?? ""
    }

    private static func urlValue(_ element: AXUIElement) -> URL? {
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""

        var urlRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXURL" as CFString, &urlRef) == .success,
           let url = httpURL(from: urlRef as Any)
        {
            return url
        }
        if role == "AXWebArea" || role == "AXTextField" || role == "AXComboBox" {
            var valueRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
               let url = httpURL(from: valueRef as Any)
            {
                return url
            }
        }
        return nil
    }

    private static func isHTTP(_ url: URL) -> Bool {
        url.scheme == "http" || url.scheme == "https"
    }
}
