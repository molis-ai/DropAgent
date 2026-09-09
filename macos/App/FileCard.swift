import AppKit
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct FileCard: View {
    let item: Item
    let selected: Bool
    var isResult = false
    var dragGroup: [Item] = []
    var onSelect: (Bool) -> Void
    var onOpen: (() -> Void)?
    var onHide: (() -> Void)?
    var onDelete: (() -> Void)?
    var onHoverPreview: ((Bool, CGRect) -> Void)?
    var onBeginDrag: (() -> Void)?
    @State private var hovering = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var clickTask: Task<Void, Never>?
    @State private var clickCount = 0
    @State private var screenRect: CGRect = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let snippet = ItemPeek.cardText(for: item), ItemPeek.showsTextCard(item) {
                Text(snippet)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.text)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                FileKindMark(item: item, compact: true)
                    .padding(.top, 6)
            } else {
                HStack(spacing: 10) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.text)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(caption)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(width: LivePanelChrome.fileCardWidth, height: LivePanelChrome.fileCardHeight, alignment: .topLeading)
        .background(Palette.panel)
        .overlay(
            RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                .stroke(selected ? Color(red: 168 / 255, green: 185 / 255, blue: 238 / 255) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        .overlay(alignment: .topTrailing) {
            if let onHide, let onDelete, item.status != .running, hovering || selected {
                RowEditButtons(
                    visible: true,
                    compact: true,
                    onHide: onHide,
                    onDelete: onDelete,
                    hideHint: Copy.t("隐藏", "Hide"),
                    deleteHint: Copy.t("删除", "Delete"),
                    hideID: isResult ? "hide-result" : "hide-item",
                    deleteID: isResult ? "delete-result" : "delete-item"
                )
                .padding(4)
            }
        }
        .contentShape(Rectangle())
        .background(ScreenRectProbe { screenRect = $0 })
        .onTapGesture {
            handleTap(command: ClickModifiers.command)
        }
        .contextMenu {
            if item.status != .running {
                if let onHide { Button(Copy.t("隐藏", "Hide")) { onHide() } }
                if let onDelete { Button(Copy.t("删除", "Delete"), role: .destructive) { onDelete() } }
            }
        }
        .modifier(RowDrag(item: item, group: dragGroup, onBegin: onBeginDrag))
        .onHover { on in
            hovering = on
            hoverTask?.cancel()
            if on {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 140_000_000)
                    guard !Task.isCancelled else { return }
                    onHoverPreview?(true, screenRect)
                }
            } else {
                onHoverPreview?(false, .zero)
            }
        }
        .onDisappear {
            hoverTask?.cancel()
            clickTask?.cancel()
            clickCount = 0
            onHoverPreview?(false, .zero)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel("\(item.displayTag) \(item.title)")
        .accessibilityIdentifier(isResult ? "result-\(item.id.rawValue)" : "item-\(item.id.rawValue)")
        .accessibilityAction(.default) { onSelect(false) }
    }

    private var caption: String {
        if isResult {
            return item.recipe ?? Copy.t("可拖走", "Ready")
        }
        let kind = Copy.kindWord(item.kind)
        switch item.status {
        case .running: return Copy.t("\(kind) · 运行中", "\(kind) · Running")
        case .sent: return Copy.t("\(kind) · 已进终端", "\(kind) · In terminal")
        case .confirm: return Copy.t("\(kind) · 未运行", "\(kind) · Not run")
        case .failed: return item.failureReason ?? Copy.t("失败", "Failed")
        default: return kind
        }
    }

    @ViewBuilder
    private var icon: some View {
        if item.kind == .image, let image = ItemPeek.image(for: item) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        } else {
            FileKindMark(item: item)
        }
    }

    private func handleTap(command: Bool) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        if command {
            clickTask?.cancel()
            clickCount = 0
            onSelect(true)
            return
        }
        clickCount += 1
        if clickCount >= 2 {
            clickTask?.cancel()
            clickCount = 0
            onOpen?()
            return
        }
        let shouldDeselectIfSingle = selected
        if selected == false {
            onSelect(false)
        }
        clickTask?.cancel()
        clickTask = Task { @MainActor in
            let nanos = UInt64(max(0.18, NSEvent.doubleClickInterval) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            if clickCount == 1, shouldDeselectIfSingle {
                onSelect(false)
            }
            clickCount = 0
        }
    }
}

private struct RowDrag: ViewModifier {
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
