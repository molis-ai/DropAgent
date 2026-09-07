import AppKit
import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct SourceLinkText: View {
    let url: URL
    var size: CGFloat = 12

    var body: some View {
        let text = url.absoluteString
        if SourceLink.isOpenable(url) {
            Button(text) { SourceLink.open(url) }
                .buttonStyle(.plain)
                .font(.system(size: size))
                .foregroundStyle(Palette.ice)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .accessibilityLabel(Copy.t("打开 \(text)", "Open \(text)"))
        } else {
            Text(text)
                .font(.system(size: size))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
        }
    }
}

struct StagedPeek: View {
    let item: Item

    var body: some View {
        switch item.kind {
        case .web:
            webPeek
        case .image:
            Text(Copy.t("点「结果」看这张图。", "Open Results to see this image."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .accessibilityLabel(Copy.t("图片 \(item.title)，点结果看图", "Image \(item.title). Open Results to view it."))
                .padding(.bottom, 4)
        case .clip:
            peekLine(Copy.t("点「结果」看这段字。", "Open Results to read this text."))
        case .url:
            VStack(alignment: .leading, spacing: 4) {
                SourceLinkText(url: item.sourceURL, size: 11)
                peekLine(Copy.t("点「结果」看链接。", "Open Results to see the link."))
            }
        case .markdown:
            if item.output == nil {
                peekLine(Copy.t("点「结果」看正文。", "Open Results to read the body."))
            }
        case .folder:
            peekLine(Copy.t("点「结果」看里面有什么。", "Open Results to see what’s inside."))
        case .pdf, .file:
            if item.output == nil {
                if item.kind == .file, PanelInspect.htmlURL(item) != nil {
                    peekLine(Copy.t("点「结果」看正文。", "Open Results to read the body."))
                } else {
                    peekLine(Copy.t("点「结果」看怎么打开。", "Open Results to see how to open it."))
                }
            }
        }
    }

    @ViewBuilder
    private var webPeek: some View {
        VStack(alignment: .leading, spacing: 4) {
            SourceLinkText(url: item.sourceURL, size: 11)
            if item.event.isEmpty == false {
                Text(item.event)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.warning)
                    .lineLimit(2)
            }
            Text(Copy.t("点「结果」看正文和截图。", "Open Results to see the body and screenshot."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .accessibilityLabel(Copy.t("网站 \(item.title)，点结果看正文和截图", "Page \(item.title). Open Results for body and screenshot."))
        }
        .padding(.bottom, 4)
    }

    private func peekLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .padding(.bottom, 4)
    }
}

enum PanelInspect {
    static func htmlURL(_ item: Item) -> URL? {
        if ReadableHTML.isHTMLFile(item.sourceURL) { return item.parts.first?.url ?? item.sourceURL }
        if let part = item.parts.first(where: { ReadableHTML.isHTMLFile($0.url) }) { return part.url }
        if ReadableHTML.isHTMLFile(URL(fileURLWithPath: item.title)) {
            return item.parts.first?.url
        }
        return nil
    }
}
