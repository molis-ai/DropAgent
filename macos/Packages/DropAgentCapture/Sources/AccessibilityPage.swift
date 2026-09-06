import ApplicationServices
import Foundation

public enum AccessibilityPage {
    public static func isTrusted() -> Bool {
        AXIsProcessTrusted()
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
        for window in windows(of: app) {
            if Date() > deadline { return nil }
            if let page = readWindow(window, deadline: deadline) {
                return page
            }
        }
        return nil
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

    private static func windows(of app: AXUIElement) -> [AXUIElement] {
        var listRef: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &listRef)
        let list = (listRef as? [AXUIElement]) ?? []
        return list.sorted { a, b in
            windowScore(subrole: subrole(a)) > windowScore(subrole: subrole(b))
        }
    }

    private static func subrole(_ element: AXUIElement) -> String? {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &ref)
        return ref as? String
    }

    private static func readWindow(_ window: AXUIElement, deadline: Date) -> (url: URL, title: String)? {
        AXUIElementSetMessagingTimeout(window, 0.35)
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        let title = cleanedTitle(titleRef as? String ?? "")
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

        var descriptionRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXDescriptionAttribute as CFString, &descriptionRef) == .success,
           let url = httpURL(from: descriptionRef as Any)
        {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        if let url = httpURL(from: title) {
            return (url, title)
        }

        if let url = toolbarURL(in: window, deadline: deadline) {
            return (url, title.isEmpty ? url.absoluteString : title)
        }

        if let url = firstURL(in: window, deadline: deadline) {
            return (url, title.isEmpty ? url.absoluteString : title)
        }
        return nil
    }

    private static func cleanedTitle(_ title: String) -> String {
        let suffixes = [
            " - Google Chrome",
            " — Google Chrome",
            " - Microsoft Edge",
            " - Brave",
        ]
        for suffix in suffixes where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title
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

    private static func firstURL(in window: AXUIElement, deadline: Date) -> URL? {
        var remaining = 80
        var queue: [(AXUIElement, Int)] = [(window, 0)]
        var index = 0
        while index < queue.count, remaining > 0 {
            if Date() > deadline { return nil }
            remaining -= 1
            let (element, depth) = queue[index]
            index += 1
            AXUIElementSetMessagingTimeout(element, 0.2)
            if let url = urlValue(element) { return url }
            guard depth < 8 else { continue }
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children) == .success,
                  let list = children as? [AXUIElement]
            else { continue }
            let ranked = list.prefix(16).sorted { rank($0) > rank($1) }
            for child in ranked {
                queue.append((child, depth + 1))
            }
        }
        return nil
    }

    private static func rank(_ element: AXUIElement) -> Int {
        AXUIElementSetMessagingTimeout(element, 0.2)
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        switch roleRef as? String {
        case "AXWebArea": return 3
        case "AXComboBox", "AXTextField": return 2
        case "AXToolbar", "AXGroup": return 1
        default: return 0
        }
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
