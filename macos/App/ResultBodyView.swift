import SwiftUI

@MainActor
enum ResultBodyView {
    static func json(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func code(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.tty)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
            .accessibilityLabel(Copy.t("代码", "Code"))
    }

    static func markdown(_ body: String, baseDirectory: URL? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(ResultMarkdown.blocks(body).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    Text(inlineMarkdown(text))
                        .font(headingFont(level))
                        .foregroundStyle(Palette.text)
                case .item(let text):
                    listItem(marker: "•", text: text)
                case .orderedItem(let marker, let text):
                    listItem(marker: marker, text: text)
                case .paragraph(let text):
                    Text(inlineMarkdown(text))
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.text)
                        .lineSpacing(4)
                case .code(let text):
                    code(text)
                case .quote(let text):
                    Text(inlineMarkdown(text))
                        .font(.system(size: 13).italic())
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Palette.line)
                                .frame(width: 1)
                        }
                        .accessibilityLabel(Copy.t("引用", "Quote"))
                case .image(let alt, let url):
                    ResultMarkdownImage(alt: alt, url: url, baseDirectory: baseDirectory)
                case .table(let header, let rows):
                    table(header: header, rows: rows)
                }
            }
        }
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            if SourceLink.isOpenable(url) {
                SourceLink.open(url)
                return .handled
            }
            return .discarded
        })
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func listItem(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.muted)
                .frame(minWidth: 14, alignment: .trailing)
            Text(inlineMarkdown(text))
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static func inlineMarkdown(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .system(size: 21, weight: .semibold)
        case 2: return .system(size: 16, weight: .semibold)
        case 3: return .system(size: 14, weight: .semibold)
        default: return .system(size: 12, weight: .medium)
        }
    }

    @ViewBuilder
    private static func table(header: [String], rows: [[String]]) -> some View {
        let columns = max(header.count, rows.map(\.count).max() ?? 0, 1)
        let table = VStack(alignment: .leading, spacing: 0) {
            tableRow(paddedRow(header, columns: columns), emphasis: true)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                tableRow(paddedRow(row, columns: columns), emphasis: false)
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Palette.line)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(Copy.t("表格", "Table"))
        if columns > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                table
            }
        } else {
            table
        }
    }

    private static func tableRow(_ cells: [String], emphasis: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(inlineMarkdown(cell))
                    .font(.system(size: 11, weight: emphasis ? .medium : .regular))
                    .foregroundStyle(emphasis ? Palette.text : Palette.muted)
                    .frame(minWidth: 56, maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 5)
                    .fixedSize(horizontal: false, vertical: true)
                if index < cells.count - 1 {
                    Rectangle()
                        .fill(Palette.line)
                        .frame(width: 1)
                }
            }
        }
    }

    private static func paddedRow(_ row: [String], columns: Int) -> [String] {
        if row.count >= columns { return Array(row.prefix(columns)) }
        return row + Array(repeating: "", count: columns - row.count)
    }
}
