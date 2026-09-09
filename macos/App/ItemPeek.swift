import AppKit
import DropAgentIngest
import DropAgentShelf
import Foundation
import PDFKit

enum ItemPeek {
    static let cardLimit = 88
    private static let hoverLimit = 900
    private static let maxBytes = 64 * 1024

    enum HoverBody: Equatable {
        case markdown(String, baseDirectory: URL?, fromHTML: Bool)
        case json(String)
        case code(String)
        case plain(String)
    }

    static func cardText(for item: Item) -> String? {
        clipped(rawText(for: item), limit: cardLimit)
    }

    static func hoverBody(for item: Item) -> HoverBody? {
        switch item.kind {
        case .image:
            return nil
        case .url:
            return .plain(displayURL(item.sourceURL))
        case .web:
            if let body = webBody(item) {
                let base = item.parts.first(where: { $0.name.hasSuffix(".md") })?.url.deletingLastPathComponent()
                return .markdown(clipPreservingBreaks(body), baseDirectory: base, fromHTML: false)
            }
            return .plain(displayURL(item.sourceURL))
        case .folder:
            return nil
        case .pdf:
            guard let text = pdfText(item) else { return nil }
            return .plain(clipPreservingBreaks(text))
        case .clip:
            guard let text = fileText(item) else { return nil }
            return .plain(text)
        case .markdown, .file:
            return fileHover(item)
        }
    }

    static func showsTextCard(_ item: Item) -> Bool {
        item.kind != .image && item.kind != .clip && cardText(for: item) != nil
    }

    static func clipLines(for item: Item) -> (title: String, body: String)? {
        guard item.kind == .clip, let raw = rawText(for: item) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let lines = trimmed.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        guard let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty == false }) else {
            return (item.title, "")
        }
        let title = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        let body = lines.dropFirst(index + 1).joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, body)
    }

    static func image(for item: Item) -> NSImage? {
        if item.kind == .image { return raster(from: item) }
        if item.kind == .web, let png = item.parts.first(where: { $0.name.lowercased().hasSuffix(".png") }) {
            return NSImage(contentsOf: png.url)
        }
        return nil
    }

    static func pdfPage(for item: Item) -> NSImage? {
        guard item.kind == .pdf, let url = fileURL(for: item) else { return nil }
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 160 / max(bounds.height, 1)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        return page.thumbnail(of: size, for: .mediaBox)
    }

    static func folderNames(for item: Item) -> [String] {
        guard item.kind == .folder else { return [] }
        let url = item.parts.first?.url ?? item.sourceURL
        let kids = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return kids
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(".") == false }
            .sorted()
    }

    private static func rawText(for item: Item) -> String? {
        switch item.kind {
        case .image:
            return nil
        case .url:
            return displayURL(item.sourceURL)
        case .web:
            return webBody(item) ?? displayURL(item.sourceURL)
        case .folder:
            let names = folderNames(for: item)
            return names.isEmpty ? nil : names.prefix(6).joined(separator: " · ")
        case .pdf:
            return pdfText(item)
        case .clip, .markdown, .file:
            return fileText(item)
        }
    }

    private static func fileText(_ item: Item) -> String? {
        if let output = item.output, let text = readableText(url: output) { return text }
        if let html = PanelInspect.htmlURL(item),
           let raw = utf8(url: html),
           ReadableHTML.isHTMLFile(html)
        {
            let markdown = ReadableHTML.markdown(from: raw, baseURL: html)
            if markdown.isEmpty == false { return markdown }
        }
        let preferred = item.parts.first { part in
            let name = part.name.lowercased()
            return name.hasSuffix(".txt") || name.hasSuffix(".md") || name.hasSuffix(".markdown")
                || name.hasSuffix(".json") || name.hasSuffix(".swift") || name.hasSuffix(".py")
                || name.hasSuffix(".yaml") || name.hasSuffix(".yml") || name.hasSuffix(".xml")
                || name.hasSuffix(".css") || name.hasSuffix(".html") || name.hasSuffix(".htm")
        }
        if let preferred, let text = readableText(url: preferred.url) { return text }
        if let part = item.parts.first, let text = readableText(url: part.url) { return text }
        if item.sourceURL.isFileURL, let text = readableText(url: item.sourceURL) { return text }
        if item.event.isEmpty == false { return item.event }
        return nil
    }

    private static func webBody(_ item: Item) -> String? {
        guard let md = item.parts.first(where: { $0.name.hasSuffix(".md") }),
              let body = utf8(url: md.url)
        else { return nil }
        var display = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if display.hasPrefix(item.title) {
            let rest = display.dropFirst(item.title.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if rest.isEmpty == false { display = rest }
        }
        return display.isEmpty ? nil : display
    }

    private static func pdfText(_ item: Item) -> String? {
        guard let url = fileURL(for: item), let document = PDFDocument(url: url) else { return nil }
        var parts: [String] = []
        let pages = min(document.pageCount, 2)
        for index in 0..<pages {
            if let page = document.page(at: index), let text = page.string {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false { parts.append(trimmed) }
            }
        }
        let joined = parts.joined(separator: "\n")
        return joined.isEmpty ? nil : joined
    }

    private static func fileURL(for item: Item) -> URL? {
        if let output = item.output { return output }
        if let part = item.parts.first { return part.url }
        return item.sourceURL.isFileURL ? item.sourceURL : nil
    }

    private static func raster(from item: Item) -> NSImage? {
        let part = item.parts.first { part in
            let name = part.name.lowercased()
            return name.hasSuffix(".png") || name.hasSuffix(".jpg") || name.hasSuffix(".jpeg")
                || name.hasSuffix(".gif") || name.hasSuffix(".webp") || name.hasSuffix(".tif")
                || name.hasSuffix(".tiff") || name.hasSuffix(".heic")
        }
        if let part { return NSImage(contentsOf: part.url) }
        if item.sourceURL.isFileURL { return NSImage(contentsOf: item.sourceURL) }
        return nil
    }

    private static func readableText(url: URL) -> String? {
        if ReadableHTML.isHTMLFile(url), let raw = utf8(url: url) {
            let markdown = ReadableHTML.markdown(from: raw, baseURL: url)
            return markdown.isEmpty ? nil : markdown
        }
        return utf8(url: url)
    }

    private static func utf8(url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        let slice = data.prefix(maxBytes)
        if slice.contains(0) { return nil }
        guard let text = String(data: slice, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func displayURL(_ url: URL) -> String {
        url.absoluteString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private static func fileHover(_ item: Item) -> HoverBody? {
        if let output = item.output {
            return documentHover(url: output, title: output.lastPathComponent)
        }
        if let html = PanelInspect.htmlURL(item),
           ReadableHTML.isHTMLFile(html),
           let raw = utf8(url: html)
        {
            let markdown = ReadableHTML.markdown(from: raw, baseURL: html)
            if markdown.isEmpty == false {
                return .markdown(
                    clipPreservingBreaks(markdown),
                    baseDirectory: html.deletingLastPathComponent(),
                    fromHTML: true
                )
            }
        }
        let preferred = item.parts.first { part in
            let name = part.name.lowercased()
            return name.hasSuffix(".txt") || name.hasSuffix(".md") || name.hasSuffix(".markdown")
                || name.hasSuffix(".json") || name.hasSuffix(".swift") || name.hasSuffix(".py")
                || name.hasSuffix(".yaml") || name.hasSuffix(".yml") || name.hasSuffix(".xml")
                || name.hasSuffix(".css") || name.hasSuffix(".html") || name.hasSuffix(".htm")
        }
        if let preferred, let body = documentHover(url: preferred.url, title: preferred.name) {
            return body
        }
        if let part = item.parts.first, let body = documentHover(url: part.url, title: part.name) {
            return body
        }
        if item.sourceURL.isFileURL, let body = documentHover(url: item.sourceURL, title: item.title) {
            return body
        }
        if item.event.isEmpty == false { return .plain(clipPreservingBreaks(item.event)) }
        return nil
    }

    private static func documentHover(url: URL, title: String) -> HoverBody? {
        if ReadableHTML.isHTMLFile(url), let raw = utf8(url: url) {
            let markdown = ReadableHTML.markdown(from: raw, baseURL: url)
            guard markdown.isEmpty == false else { return nil }
            return .markdown(
                clipPreservingBreaks(markdown),
                baseDirectory: url.deletingLastPathComponent(),
                fromHTML: true
            )
        }
        guard let text = utf8(url: url) else { return nil }
        switch StagedPreview.mode(title: title, body: text) {
        case .json:
            return .json(clipPreservingBreaks(ResultJSON.pretty(text) ?? text))
        case .code:
            return .code(clipPreservingBreaks(text))
        case .markdown:
            return .markdown(
                clipPreservingBreaks(text),
                baseDirectory: url.deletingLastPathComponent(),
                fromHTML: false
            )
        }
    }

    private static func clipped(_ text: String?, limit: Int) -> String? {
        guard let text else { return nil }
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard collapsed.isEmpty == false else { return nil }
        if collapsed.count <= limit { return collapsed }
        return String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func clipPreservingBreaks(_ text: String, limit: Int = hoverLimit) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return trimmed }
        if trimmed.count <= limit { return trimmed }
        let prefix = String(trimmed.prefix(limit))
        if let idx = prefix.lastIndex(of: "\n") {
            let cut = String(prefix[..<idx]).trimmingCharacters(in: .whitespacesAndNewlines)
            if cut.isEmpty == false { return cut + "\n…" }
        }
        return prefix.trimmingCharacters(in: .whitespaces) + "…"
    }
}
