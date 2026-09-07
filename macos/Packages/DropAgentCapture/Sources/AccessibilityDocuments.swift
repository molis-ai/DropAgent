import AppKit
import ApplicationServices
import Foundation

extension AccessibilityPage {
    public static func readFileDocuments(pid: pid_t) -> [URL] {
        guard isTrusted() else { return [] }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.35)
        var found: [URL] = []
        for window in windowsToRead(of: app) {
            var documentRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &documentRef) == .success,
               let url = existingFileURL(from: documentRef as Any),
               found.contains(url) == false
            {
                found.append(url)
            }
        }
        return found
    }

    public static func existingFileURL(from raw: Any) -> URL? {
        let parsed: URL?
        if let url = raw as? URL {
            parsed = url
        } else if let text = raw as? String {
            parsed = parseFileURL(text)
        } else if let text = raw as? NSString {
            parsed = parseFileURL(text as String)
        } else {
            parsed = nil
        }
        guard let parsed, parsed.isFileURL else { return nil }
        let resolved = parsed.standardizedFileURL
        guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }
        return resolved
    }

    private static func parseFileURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.isFileURL { return url }
        if trimmed.hasPrefix("/") { return URL(fileURLWithPath: trimmed) }
        return nil
    }
}
