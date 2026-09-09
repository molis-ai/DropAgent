import SwiftUI

@MainActor
enum ResultBodyView {
    static func json(_ body: String, fillWidth: Bool = true) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .fixedSize(horizontal: fillWidth == false, vertical: false)
    }

    static func code(_ body: String, fillWidth: Bool = true) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.tty)
            .textSelection(.enabled)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .fixedSize(horizontal: fillWidth == false, vertical: false)
            .padding(8)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
            .accessibilityLabel(Copy.t("代码", "Code"))
    }

    static func markdown(
        _ body: String,
        baseDirectory: URL? = nil,
        compact: Bool = false,
        wrapWidth: CGFloat? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            ForEach(Array(ResultMarkdown.blocks(body).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    wrapped(
                        Text(inlineMarkdown(text))
                            .font(headingFont(level, compact: compact))
                            .foregroundStyle(Palette.text),
                        width: wrapWidth
                    )
                case .item(let text):
                    wrapped(listItem(marker: "•", text: text, compact: compact), width: wrapWidth)
                case .orderedItem(let marker, let text):
                    wrapped(listItem(marker: marker, text: text, compact: compact), width: wrapWidth)
                case .paragraph(let text):
                    wrapped(
                        Text(inlineMarkdown(text))
                            .font(.system(size: compact ? 12 : 13))
                            .foregroundStyle(Palette.text)
                            .lineSpacing(compact ? 2 : 4),
                        width: wrapWidth
                    )
                case .code(let text):
                    code(text, fillWidth: wrapWidth == nil)
                case .quote(let text):
                    wrapped(
                        Text(inlineMarkdown(text))
                            .font(.system(size: compact ? 12 : 13).italic())
                            .foregroundStyle(Palette.muted)
                            .frame(maxWidth: wrapWidth ?? .infinity, alignment: .leading)
                            .padding(.leading, 12)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Palette.line)
                                    .frame(width: 1)
                            }
                            .accessibilityLabel(Copy.t("引用", "Quote")),
                        width: wrapWidth
                    )
                case .image(let alt, let url):
                    if compact {
                        wrapped(
                            Text(alt.isEmpty ? Copy.t("图片", "Image") : alt)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.muted),
                            width: wrapWidth
                        )
                    } else {
                        ResultMarkdownImage(alt: alt, url: url, baseDirectory: baseDirectory)
                    }
                case .table(let header, let rows):
                    table(header: header, rows: rows, compact: compact)
                }
            }
        }
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            if compact { return .discarded }
            if SourceLink.isOpenable(url) {
                SourceLink.open(url)
                return .handled
            }
            return .discarded
        })
        .frame(maxWidth: wrapWidth == nil ? .infinity : nil, alignment: .leading)
    }

    @ViewBuilder
    private static func wrapped(_ view: some View, width: CGFloat?) -> some View {
        if let width {
            view.frame(maxWidth: width, alignment: .leading)
        } else {
            view
        }
    }

    private static func listItem(marker: String, text: String, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.system(size: compact ? 11 : 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Palette.muted)
                .frame(minWidth: 14, alignment: .trailing)
            Text(inlineMarkdown(text))
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(Palette.text)
                .lineSpacing(compact ? 2 : 3)
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

    private static func headingFont(_ level: Int, compact: Bool) -> Font {
        if compact {
            switch level {
            case 1: return .system(size: 16, weight: .semibold)
            case 2: return .system(size: 13, weight: .semibold)
            default: return .system(size: 12, weight: .medium)
            }
        }
        switch level {
        case 1: return .system(size: 21, weight: .semibold)
        case 2: return .system(size: 16, weight: .semibold)
        case 3: return .system(size: 14, weight: .semibold)
        default: return .system(size: 12, weight: .medium)
        }
    }

    @ViewBuilder
    private static func table(header: [String], rows: [[String]], compact: Bool) -> some View {
        let columns = max(header.count, rows.map(\.count).max() ?? 0, 1)
        let table = VStack(alignment: .leading, spacing: 0) {
            tableRow(paddedRow(header, columns: columns), emphasis: true, compact: compact)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                tableRow(paddedRow(row, columns: columns), emphasis: false, compact: compact)
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
        if compact {
            table.fixedSize(horizontal: true, vertical: false)
        } else if columns > 4 {
            ScrollView(.horizontal, showsIndicators: false) {
                table
            }
        } else {
            table
        }
    }

    private static func tableRow(_ cells: [String], emphasis: Bool, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                Text(inlineMarkdown(cell))
                    .font(.system(size: compact ? 10 : 11, weight: emphasis ? .medium : .regular))
                    .foregroundStyle(emphasis ? Palette.text : Palette.muted)
                    .frame(
                        minWidth: compact ? 72 : 56,
                        maxWidth: compact ? 220 : .infinity,
                        alignment: .leading
                    )
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
