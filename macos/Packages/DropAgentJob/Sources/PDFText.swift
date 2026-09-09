import Foundation
import PDFKit

public enum PDFTextError: Error, Equatable, Sendable {
    case unreadable
    case locked
}

public enum PDFText: Sendable {
    public static let emptyCopy = "这份 PDF 没有可选中的文字。"

    public static func pages(url: URL) async throws -> [String] {
        try await MainActor.run {
            try pagesSync(url: url)
        }
    }

    public static func markdown(files: [(name: String, pages: [String])]) -> String {
        guard files.isEmpty == false else { return emptyCopy + "\n" }
        let named = files.count > 1
        var blocks: [String] = []
        var anyText = false
        for file in files {
            if file.pages.isEmpty {
                if named {
                    blocks.append("## \(file.name)\n\n\(emptyCopy)")
                }
                continue
            }
            anyText = true
            var lines: [String] = []
            if named {
                lines.append("## \(file.name)")
                lines.append("")
            }
            let pageHeads = file.pages.count > 1
            for (index, text) in file.pages.enumerated() {
                if pageHeads {
                    lines.append(named ? "### 第 \(index + 1) 页" : "## 第 \(index + 1) 页")
                    lines.append("")
                }
                lines.append(text)
                if index < file.pages.count - 1 {
                    lines.append("")
                }
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        if anyText == false {
            return emptyCopy + "\n"
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    private static func pagesSync(url: URL) throws -> [String] {
        guard let document = PDFDocument(url: url) else { throw PDFTextError.unreadable }
        if document.isLocked { throw PDFTextError.locked }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty == false { pages.append(text) }
        }
        return pages
    }
}
