import Foundation

public enum PageTitle {
    public static func resolved(browserTitle: String, url: URL, html: String?) -> String {
        let browser = cleaned(browserTitle)
        if isUsable(browser, url: url) { return browser }
        if let html, let fromHTML = HTMLMarkdown.documentTitle(html), isUsable(fromHTML, url: url) {
            return fromHTML
        }
        if let host = url.host, host.isEmpty == false { return host }
        return url.absoluteString
    }

    public static func cleaned(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = [
            " - Google Chrome",
            " — Google Chrome",
            " - Microsoft Edge",
            " - Brave",
            " - Safari",
            " — Safari",
            " – Safari",
        ]
        for suffix in suffixes where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    public static func isUsable(_ title: String, url: URL) -> Bool {
        if title.isEmpty { return false }
        if title == url.absoluteString { return false }
        switch title.lowercased() {
        case "未命名", "untitled", "untitled page", "new tab", "新标签页", "新分頁",
             "safari", "chrome", "google chrome", "microsoft edge", "brave":
            return false
        default:
            return true
        }
    }
}
