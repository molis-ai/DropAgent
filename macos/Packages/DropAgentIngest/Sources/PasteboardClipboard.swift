import AppKit
import Foundation

public extension ClipboardPayload {
    static func from(pasteboard: NSPasteboard) -> ClipboardPayload {
        if let url = httpURL(from: pasteboard) {
            return .text(url.absoluteString)
        }
        let files = fileURLs(from: pasteboard)
        if files.isEmpty == false {
            return .files(files)
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let tiff = images.first?.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return .image(png)
        }
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return .text(text)
        }
        if let rtf = pasteboard.data(forType: .rtf), let text = plainText(fromRTF: rtf) {
            return .text(text)
        }
        return .empty
    }

    static func plainText(fromRTF data: Data) -> String? {
        guard let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var found: [URL] = []
        func append(_ url: URL) {
            let resolved = url.standardizedFileURL
            guard resolved.isFileURL else { return }
            guard FileManager.default.fileExists(atPath: resolved.path) else { return }
            if found.contains(resolved) == false {
                found.append(resolved)
            }
        }
        if let names = pasteboard.propertyList(forType: filenamesType) as? [String] {
            names.forEach { append(URL(fileURLWithPath: $0)) }
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            urls.forEach(append)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            urls.filter(\.isFileURL).forEach(append)
        }
        for item in pasteboard.pasteboardItems ?? [] {
            if let text = item.string(forType: .fileURL) {
                if let url = URL(string: text), url.isFileURL {
                    append(url)
                } else if text.hasPrefix("/") {
                    append(URL(fileURLWithPath: text))
                }
            }
        }
        return found
    }

    static func httpURL(from pasteboard: NSPasteboard) -> URL? {
        for type in webURLTitleTypes {
            if let plist = pasteboard.propertyList(forType: type) as? [Any],
               let urls = plist.first as? [Any] {
                for item in urls {
                    if let url = httpLink(item) { return url }
                }
            }
        }
        for type in bookmarkListTypes {
            if let url = pasteboardURLFromBookmark(pasteboard.propertyList(forType: type)) {
                return url
            }
        }
        if let url = NSURL(from: pasteboard) as URL?, isHTTP(url) {
            return url
        }
        if let text = pasteboard.string(forType: .URL), let url = httpLinkString(text) {
            return url
        }
        if let url = pasteboardURLFromData(pasteboard.data(forType: .URL)) {
            return url
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            if let http = urls.first(where: { $0.scheme == "http" || $0.scheme == "https" }) {
                return http
            }
        }
        for item in pasteboard.pasteboardItems ?? [] {
            for type in itemURLTypes {
                if let text = item.string(forType: type), let url = httpLinkString(text) {
                    return url
                }
                if let url = pasteboardURLFromData(item.data(forType: type)) {
                    return url
                }
            }
        }
        return nil
    }
}

private let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

private let webURLTitleTypes: [NSPasteboard.PasteboardType] = [
    NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType"),
    NSPasteboard.PasteboardType("com.apple.webkit.WebURLsWithTitles"),
]

private let bookmarkListTypes: [NSPasteboard.PasteboardType] = [
    NSPasteboard.PasteboardType("org.chromium.bookmark-dictionary-list"),
    NSPasteboard.PasteboardType("org.chromium.bookmark-entry"),
]

private let itemURLTypes: [NSPasteboard.PasteboardType] = [
    .URL,
    .string,
]

private func pasteboardURLFromData(_ data: Data?) -> URL? {
    guard let data, data.isEmpty == false else { return nil }
    if let text = String(data: data, encoding: .utf8), let url = httpLinkString(text) {
        return url
    }
    if let text = String(data: data, encoding: .utf16), let url = httpLinkString(text) {
        return url
    }
    if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) {
        return httpLink(plist) ?? pasteboardURLFromBookmark(plist)
    }
    return nil
}

private func pasteboardURLFromBookmark(_ raw: Any?) -> URL? {
    guard let raw else { return nil }
    if let url = httpLink(raw) { return url }
    if let dict = raw as? [String: Any] {
        for key in ["URL", "url", "location"] {
            if let value = dict[key], let url = httpLink(value) { return url }
        }
        for value in dict.values {
            if let url = pasteboardURLFromBookmark(value) { return url }
        }
    }
    if let list = raw as? [Any] {
        for item in list {
            if let url = pasteboardURLFromBookmark(item) { return url }
        }
    }
    return nil
}

private func httpLink(_ raw: Any) -> URL? {
    if let url = raw as? URL {
        return isHTTP(url) ? url : nil
    }
    if let text = raw as? String {
        return httpLinkString(text)
    }
    if let text = raw as? NSString {
        return httpLinkString(text as String)
    }
    return nil
}

private func httpLinkString(_ text: String) -> URL? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: trimmed) else { return nil }
    return isHTTP(url) ? url : nil
}

private func isHTTP(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased()
    return scheme == "http" || scheme == "https"
}

public struct PasteboardClipboard: ClipboardReading {
    private let payload: ClipboardPayload

    public init(_ pasteboard: NSPasteboard) {
        payload = .from(pasteboard: pasteboard)
    }

    public func read() -> ClipboardPayload {
        payload
    }
}
