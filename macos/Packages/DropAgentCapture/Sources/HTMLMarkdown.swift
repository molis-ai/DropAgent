import Foundation

public enum HTMLMarkdown {
    public static func documentTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "(?is)<title[^>]*>(.*?)</title>") else {
            return nil
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let inner = Range(match.range(at: 1), in: html)
        else {
            return nil
        }
        let text = decodeEntities(stripTags(String(html[inner])))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    public static func convert(_ html: String, baseURL: URL? = nil) -> String {
        var text = html
        text = text.replacingOccurrences(
            of: "(?is)<(script|style|noscript)\\b[^>]*>.*?</\\1>",
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: "(?is)<head\\b[^>]*>.*?</head>",
            with: "",
            options: .regularExpression
        )
        if let article = innerHTML(text, tag: "article") ?? innerHTML(text, tag: "main") {
            text = article
        }
        text = replace(text, pattern: "(?is)<pre\\b[^>]*>(.*?)</pre>") { match in
            var inner = stripTags(match[1])
            inner = inner.replacingOccurrences(of: "^\\n+", with: "", options: .regularExpression)
            inner = inner.replacingOccurrences(of: "\\n+$", with: "", options: .regularExpression)
            return inner.isEmpty ? "" : "\n\n```\n\(inner)\n```\n\n"
        }
        text = replace(text, pattern: "(?is)<img\\b[^>]*>") { match in
            markdownImage(match[0], base: baseURL)
        }
        text = replace(text, pattern: "(?is)<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>(.*?)</a>") { match in
            let label = stripTags(match[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let href = resolvedHREF(match[1], base: baseURL) else {
                return label
            }
            if label.isEmpty { return href }
            return "[\(label)](\(href))"
        }
        text = replace(text, pattern: "(?is)<(strong|b)\\b[^>]*>(.*?)</\\1>") { match in
            let inner = stripTags(match[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            return inner.isEmpty ? "" : "**\(inner)**"
        }
        text = replace(text, pattern: "(?is)<(em|i)\\b[^>]*>(.*?)</\\1>") { match in
            let inner = stripTags(match[2]).trimmingCharacters(in: .whitespacesAndNewlines)
            return inner.isEmpty ? "" : "*\(inner)*"
        }
        text = replace(text, pattern: "(?is)<table\\b[^>]*>(.*?)</table>") { match in
            markdownTable(match[1])
        }
        text = replace(text, pattern: "(?is)<blockquote\\b[^>]*>(.*?)</blockquote>") { match in
            markdownQuote(match[1])
        }
        text = text.replacingOccurrences(of: "(?is)<h1\\b[^>]*>", with: "\n# ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<h2\\b[^>]*>", with: "\n## ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<h3\\b[^>]*>", with: "\n### ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<h[4-6]\\b[^>]*>", with: "\n#### ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<li\\b[^>]*>", with: "\n- ", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<br\\b\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)<p\\b[^>]*>", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?is)</(h[1-6]|p|div|li|ul|ol|blockquote)>", with: "\n", options: .regularExpression)
        text = replace(text, pattern: "(?is)<code\\b[^>]*>(.*?)</code>") { match in
            let inner = stripTags(match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            return inner.isEmpty ? "" : "`\(inner)`"
        }
        text = stripTags(text)
        text = decodeEntities(text)
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var collapsed: [String] = []
        var blank = false
        for line in lines {
            if line.isEmpty {
                if !blank, !collapsed.isEmpty {
                    collapsed.append("")
                    blank = true
                }
            } else {
                collapsed.append(line)
                blank = false
            }
        }
        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func resolvedHREF(_ href: String, base: URL?) -> String? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let lowered = trimmed.lowercased()
        if lowered.hasPrefix("javascript:") || lowered.hasPrefix("data:") {
            return nil
        }
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") || lowered.hasPrefix("mailto:") {
            return trimmed
        }
        guard let base else { return trimmed }
        return URL(string: trimmed, relativeTo: base)?.absoluteString ?? trimmed
    }

    private static func markdownImage(_ tag: String, base: URL?) -> String {
        let alt = (attribute(tag, "alt") ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "]", with: "")
        let src = attribute(tag, "src") ?? ""
        guard let href = resolvedHREF(src, base: base) else {
            return alt
        }
        return "![\(alt)](\(href))"
    }

    private static func attribute(_ tag: String, _ name: String) -> String? {
        let pattern = "(?is)\\b\(name)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(tag.startIndex..., in: tag)
        guard let match = regex.firstMatch(in: tag, range: range) else { return nil }
        for index in 1..<match.numberOfRanges {
            if let inner = Range(match.range(at: index), in: tag) {
                let value = String(tag[inner]).trimmingCharacters(in: .whitespacesAndNewlines)
                if value.isEmpty == false { return value }
            }
        }
        return nil
    }

    private static func innerHTML(_ html: String, tag: String) -> String? {
        let pattern = "(?is)<\(tag)[^>]*>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let inner = Range(match.range(at: 1), in: html)
        else { return nil }
        let text = String(html[inner]).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func markdownTable(_ html: String) -> String {
        if html.lowercased().contains("<table") {
            let plain = stripTags(html).trimmingCharacters(in: .whitespacesAndNewlines)
            return plain.isEmpty ? "" : "\n\n\(plain)\n\n"
        }
        let rows = matches(html, pattern: "(?is)<tr[^>]*>(.*?)</tr>").compactMap { row -> [String]? in
            let cells = matches(row, pattern: "(?is)<(th|td)[^>]*>(.*?)</\\1>").compactMap { cell -> String? in
                let text = stripTags(cell)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return text
            }
            return cells.isEmpty ? nil : cells
        }
        guard let header = rows.first, header.isEmpty == false else { return "" }
        let width = rows.map(\.count).max() ?? header.count
        func padded(_ row: [String]) -> [String] {
            if row.count >= width { return Array(row.prefix(width)) }
            return row + Array(repeating: "", count: width - row.count)
        }
        func line(_ row: [String]) -> String {
            "| " + padded(row).joined(separator: " | ") + " |"
        }
        var lines = [line(header), "| " + Array(repeating: "---", count: width).joined(separator: " | ") + " |"]
        for row in rows.dropFirst() {
            lines.append(line(row))
        }
        return "\n\n" + lines.joined(separator: "\n") + "\n\n"
    }

    private static func markdownQuote(_ html: String) -> String {
        let lines = stripTags(html)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        if lines.isEmpty { return "" }
        return "\n\n" + lines.map { "> \($0)" }.joined(separator: "\n") + "\n\n"
    }

    private static func matches(_ html: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        var values: [String] = []
        regex.enumerateMatches(in: html, range: range) { match, _, _ in
            guard let match else { return }
            let index = match.numberOfRanges > 2 ? 2 : 1
            if match.numberOfRanges > index, let inner = Range(match.range(at: index), in: html) {
                values.append(String(html[inner]))
            } else if let whole = Range(match.range, in: html) {
                values.append(String(html[whole]))
            }
        }
        return values
    }

    private static func stripTags(_ html: String) -> String {
        html.replacingOccurrences(of: "(?is)<[^>]+>", with: "", options: .regularExpression)
    }

    private static func replace(_ text: String, pattern: String, transform: ([String]) -> String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match, let whole = Range(match.range, in: text) else { return }
            output += text[cursor..<whole.lowerBound]
            var groups: [String] = [String(text[whole])]
            for index in 1..<match.numberOfRanges {
                if let inner = Range(match.range(at: index), in: text) {
                    groups.append(String(text[inner]))
                } else {
                    groups.append("")
                }
            }
            output += transform(groups)
            cursor = whole.upperBound
        }
        output += text[cursor...]
        return output
    }

    private static func decodeEntities(_ text: String) -> String {
        var result = text
        let named: [(String, String)] = [
            ("&nbsp;", " "),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&"),
        ]
        for (entity, value) in named {
            result = result.replacingOccurrences(of: entity, with: value)
        }
        result = replace(result, pattern: "&#x([0-9a-fA-F]+);") { match in
            guard let value = UInt32(match[1], radix: 16), let scalar = UnicodeScalar(value) else {
                return match[0]
            }
            return String(Character(scalar))
        }
        result = replace(result, pattern: "&#([0-9]+);") { match in
            guard let value = UInt32(match[1]), let scalar = UnicodeScalar(value) else {
                return match[0]
            }
            return String(Character(scalar))
        }
        return result
    }
}
