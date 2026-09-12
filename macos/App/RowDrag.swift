import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct DragLiftChip: View {
    let item: Item
    var extraCount = 0

    var body: some View {
        HStack(spacing: 6) {
            Text(item.displayTag)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(Palette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.015)
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .truncationMode(.middle)
            if extraCount > 0 {
                Text(Copy.t("及另外 \(extraCount) 项", "and \(extraCount) more"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Palette.panel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

struct RowDrag: ViewModifier {
    let item: Item
    let group: [Item]
    var onBegin: (() -> Void)?

    func body(content: Content) -> some View {
        let payload = PasteboardService.exportGroup(starting: item, selection: group)
        if payload.isEmpty {
            content
        } else {
            content.onDrag {
                onBegin?()
                let urls = PasteboardService.fileURLs(for: payload)
                let provider = PasteboardService.itemProvider(for: payload)
                DispatchQueue.main.async {
                    if onBegin != nil {
                        PasteboardService.markShelfDrag()
                    }
                    if urls.count > 1 {
                        PasteboardService.attachFileListToDragPasteboard(urls)
                    }
                }
                return provider
            } preview: {
                DragLiftChip(item: payload[0], extraCount: max(0, payload.count - 1))
            }
        }
    }
}
