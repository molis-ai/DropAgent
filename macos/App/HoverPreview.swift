import DropAgentShelf
import SwiftUI

struct HoverPreview: View {
    let item: Item
    var scrolling = false
    var cardHeight: CGFloat = 0
    var bridgeOnTrailing = true
    var lockCardWidth = true
    var includeBridge = true
    var unconstrained = false

    var body: some View {
        if includeBridge {
            HStack(spacing: 0) {
                if bridgeOnTrailing == false {
                    Color.clear.frame(width: HoverPlacement.gap)
                }
                card
                if bridgeOnTrailing {
                    Color.clear.frame(width: HoverPlacement.gap)
                }
            }
        } else {
            card
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Copy.kindWord(item.kind))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: HoverPlacement.innerWidth, alignment: .leading)
            if scrolling {
                ScrollView([.vertical, .horizontal], showsIndicators: true) {
                    payload
                        .frame(minWidth: payloadMinWidth, alignment: .topLeading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                payload
                    .frame(minWidth: payloadMinWidth, alignment: .topLeading)
            }
        }
        .padding(HoverPlacement.cardPadding)
        .frame(width: lockCardWidth ? HoverPlacement.width : nil, alignment: .leading)
        .frame(maxHeight: unconstrained ? nil : (scrolling ? cardHeight : HoverPlacement.maxHeight), alignment: .topLeading)
        .frame(height: scrolling && unconstrained == false ? cardHeight : nil, alignment: .topLeading)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 8)
        .fixedSize(horizontal: lockCardWidth == false, vertical: scrolling == false)
        .accessibilityHidden(true)
    }

    private var payloadMinWidth: CGFloat? {
        if ItemPeek.image(for: item) != nil, ItemPeek.hoverBody(for: item) == nil {
            return nil
        }
        if ItemPeek.pdfPage(for: item) != nil, ItemPeek.hoverBody(for: item) == nil {
            return nil
        }
        return HoverPlacement.innerWidth
    }

    private func fittedSize(for image: NSImage) -> CGSize {
        let width = max(image.size.width, 1)
        let height = max(image.size.height, 1)
        let scale = min(1, min(HoverPlacement.innerWidth / width, 140 / height))
        return CGSize(width: (width * scale).rounded(), height: (height * scale).rounded())
    }

    private func fittedImage(_ image: NSImage) -> some View {
        let size = fittedSize(for: image)
        return Image(nsImage: image)
            .resizable()
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var payload: some View {
        if let image = ItemPeek.image(for: item) {
            fittedImage(image)
        } else if let page = ItemPeek.pdfPage(for: item) {
            fittedImage(page)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Palette.line))
        }
        if let body = ItemPeek.hoverBody(for: item) {
            hoverContent(body)
        } else if item.kind == .folder {
            Text(Copy.t("这个文件夹是空的，或打不开。", "This folder is empty, or it cannot be opened."))
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        } else if item.kind != .image {
            Text(Copy.t("没有可读的正文。", "No readable text."))
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private func hoverContent(_ body: ItemPeek.HoverBody) -> some View {
        switch body {
        case .markdown(let text, let base, let fromHTML):
            VStack(alignment: .leading, spacing: 6) {
                if fromHTML {
                    Text(Copy.htmlExtractedHint)
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.faint)
                }
                ResultBodyView.markdown(
                    text,
                    baseDirectory: base,
                    compact: true,
                    wrapWidth: HoverPlacement.innerWidth
                )
            }
        case .json(let text):
            ResultBodyView.json(text, fillWidth: false)
        case .code(let text):
            ResultBodyView.code(text, fillWidth: false)
        case .plain(let text):
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Palette.text)
                .lineSpacing(3)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: HoverPlacement.innerWidth, alignment: .topLeading)
        }
    }
}
