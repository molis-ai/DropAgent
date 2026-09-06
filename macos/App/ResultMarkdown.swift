import Foundation

enum ResultMarkdown {
    enum Block: Equatable {
        case heading(String)
        case item(String)
        case paragraph(String)
        case code(String)
        case quote(String)
        case image(alt: String, url: String)
    }

    static func blocks(_ body: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var code: [String] = []
        var table: [String] = []
        var quotes: [String] = []
        var inCode = false

        func flushParagraph() {
            let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false { blocks.append(.paragraph(text)) }
            paragraph = []
        }

        func flushCode() {
            let text = code.joined(separator: "\n")
            if text.isEmpty == false { blocks.append(.code(text)) }
            code = []
            inCode = false
        }

        func flushTable() {
            if table.isEmpty == false {
                blocks.append(.code(table.joined(separator: "\n")))
                table = []
            }
        }

        func flushQuotes() {
            if quotes.isEmpty == false {
                blocks.append(.quote(quotes.joined(separator: "\n")))
                quotes = []
            }
        }

        for raw in body.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let original = String(raw)
            let trimmed = original.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    flushCode()
                } else {
                    flushParagraph()
                    flushTable()
                    flushQuotes()
                    inCode = true
                }
                continue
            }
            if inCode {
                code.append(original)
                continue
            }
            if isTableRow(trimmed) {
                flushParagraph()
                flushQuotes()
                table.append(trimmed)
                continue
            }
            flushTable()
            if isQuote(trimmed) {
                flushParagraph()
                quotes.append(quoteText(trimmed))
                continue
            }
            flushQuotes()
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            if let image = imageLine(trimmed) {
                flushParagraph()
                blocks.append(.image(alt: image.0, url: image.1))
                continue
            }
            if trimmed.hasPrefix("#") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                if title.isEmpty == false { blocks.append(.heading(title)) }
                continue
            }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.item(String(trimmed.dropFirst(2))))
                continue
            }
            if let numbered = numberedListItem(trimmed) {
                flushParagraph()
                blocks.append(.item(numbered))
                continue
            }
            paragraph.append(trimmed)
        }
        if inCode {
            flushCode()
        } else {
            flushTable()
            flushQuotes()
            flushParagraph()
        }
        return blocks
    }

    private static func isTableRow(_ line: String) -> Bool {
        line.hasPrefix("|") && line.hasSuffix("|") && line.filter { $0 == "|" }.count >= 2
    }

    private static func isQuote(_ line: String) -> Bool {
        line == ">" || line.hasPrefix("> ")
    }

    private static func quoteText(_ line: String) -> String {
        if line.hasPrefix("> ") { return String(line.dropFirst(2)) }
        if line.hasPrefix(">") { return String(line.dropFirst()).trimmingCharacters(in: .whitespaces) }
        return line
    }

    private static func numberedListItem(_ line: String) -> String? {
        guard let dot = line.firstIndex(of: "."), dot > line.startIndex else { return nil }
        let index = line[line.startIndex..<dot]
        guard index.allSatisfy(\.isNumber), line[dot...].hasPrefix(". ") else { return nil }
        return String(line[line.index(dot, offsetBy: 2)...])
    }

    private static func imageLine(_ line: String) -> (String, String)? {
        guard line.hasPrefix("!["), line.hasSuffix(")"), let close = line.lastIndex(of: "]") else {
            return nil
        }
        let after = line.index(after: close)
        guard after < line.endIndex, line[after] == "(" else { return nil }
        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart..<close])
        let urlStart = line.index(after: after)
        let urlEnd = line.index(before: line.endIndex)
        guard urlStart <= urlEnd else { return nil }
        let url = String(line[urlStart..<urlEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard url.isEmpty == false else { return nil }
        return (alt, url)
    }
}
