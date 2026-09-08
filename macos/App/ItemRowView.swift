import AppKit
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct ItemRowView: View {
    let item: Item
    let selected: Bool
    var multiSelect = false
    var onSelect: (Bool) -> Void
    var onHide: () -> Void
    var onDelete: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ListStackRow(
            tag: item.displayTag,
            kind: item.kind,
            title: item.title,
            subtitle: Copy.metaLine(item),
            warning: item.status == .failed,
            time: item.timeLabel,
            selected: selected,
            hovering: hovering,
            checkbox: multiSelect ? selected : nil,
            showEdit: item.status != .running,
            hideHint: Copy.t("从列表拿掉，不删文件", "Remove from the list without deleting files"),
            deleteHint: Copy.t("删除 DropAgent 里的副本，原件保留", "Delete DropAgent’s copy. The original stays."),
            hideID: "hide-item",
            deleteID: "delete-item",
            onHide: onHide,
            onDelete: onDelete
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel("\(item.displayTag) \(item.title)")
        .accessibilityValue(selected ? Copy.t("已选，\(rowStatusSpoken(item))", "Selected, \(rowStatusSpoken(item))") : rowStatusSpoken(item))
        .accessibilityAction(.default) { select(command: false) }
        .onHover { hovering = $0 }
        .onTapGesture { select(command: ClickModifiers.command || multiSelect) }
        .contextMenu {
            if item.status != .running {
                Button(Copy.t("隐藏", "Hide")) { onHide() }
                Button(Copy.t("删除", "Delete"), role: .destructive) { onDelete() }
            }
        }
        .modifier(RowDrag(item: item))
    }

    private func select(command: Bool) {
        NSApp.keyWindow?.makeFirstResponder(nil)
        onSelect(command)
    }

    private func rowStatusSpoken(_ item: Item) -> String {
        var parts: [String] = []
        switch item.status {
        case .running: parts.append(Copy.t("运行中", "Running"))
        case .done: parts.append(Copy.t("可拖出", "Ready"))
        case .sent: parts.append(Copy.t("已进终端", "In terminal"))
        case .failed:
            parts.append(Copy.t("失败", "Failed"))
            if item.output != nil { parts.append(Copy.t("可拖出", "Ready")) }
        default:
            break
        }
        parts.append(Copy.metaLine(item))
        return parts.joined(separator: Copy.t("，", ", "))
    }
}

struct ListStackRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tag: String
    let kind: ItemKind
    let title: String
    let subtitle: String
    let warning: Bool
    let time: String
    let selected: Bool
    let hovering: Bool
    var checkbox: Bool? = nil
    var showEdit = true
    var hideHint: String
    var deleteHint: String
    var hideID: String
    var deleteID: String
    var onHide: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                if let checkbox {
                    Image(systemName: checkbox ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(checkbox ? Palette.accent : Palette.faint)
                        .accessibilityHidden(true)
                }
                Text(tag)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.3)
                    .accessibilityHidden(true)
                    .foregroundStyle(Palette.tagInk(kind: kind, tag: tag))
                    .padding(.horizontal, 5)
                    .frame(height: 18)
                    .background(Palette.tagFill(kind: kind, tag: tag))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer(minLength: 0)
                ZStack(alignment: .trailing) {
                    Text(time)
                        .font(.system(size: 10).monospacedDigit())
                        .accessibilityHidden(true)
                        .foregroundStyle(Palette.faint)
                        .opacity(showEdit && (hovering || selected) ? 0 : 1)
                    if showEdit {
                        RowEditButtons(
                            visible: hovering || selected, compact: true,
                            onHide: onHide, onDelete: onDelete,
                            hideHint: hideHint, deleteHint: deleteHint,
                            hideID: hideID, deleteID: deleteID
                        )
                    }
                }
                .frame(width: 48, height: 22, alignment: .trailing)
            }
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .accessibilityHidden(true)
                .foregroundStyle(Palette.text)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle)
                .font(.system(size: 10.5))
                .accessibilityHidden(true)
                .foregroundStyle(warning ? Palette.warning : Palette.faint)
                .lineLimit(1)
        }
        .padding(10)
        .background(selected ? Palette.panel : hovering ? Palette.panelHover : Color.clear)
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(selected ? Palette.accent.opacity(0.35) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : Palette.motion, value: selected)
        .animation(reduceMotion ? nil : Palette.motion, value: hovering)

    }
}

struct RowEditButtons: View {
    var visible: Bool
    var compact = false
    var onHide: () -> Void
    var onDelete: () -> Void
    var hideHint: String
    var deleteHint: String
    var hideID: String
    var deleteID: String

    var body: some View {
        let size: CGFloat = 24
        let height: CGFloat = compact ? 24 : 28
        HStack(spacing: 0) {
            Button(action: onHide) {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(visible ? Palette.text : Palette.faint)
                    .frame(width: size, height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.t("隐藏", "Hide"))
            .accessibilityHint(hideHint)
            .help(hideHint)
            .accessibilityIdentifier(hideID)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                    .foregroundStyle(visible ? Palette.danger : Palette.faint)
                    .frame(width: size, height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Copy.t("删除", "Delete"))
            .accessibilityHint(deleteHint)
            .help(deleteHint)
            .accessibilityIdentifier(deleteID)
        }
        .background(visible ? Palette.panel2 : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }
}

private struct RowDrag: ViewModifier {
    let item: Item

    func body(content: Content) -> some View {
        if item.status == .running {
            content
        } else {
            content.onDrag {
                PasteboardService.itemProvider(for: item)
            } preview: {
                DragLiftChip(item: item)
            }
        }
    }
}

struct DragLiftChip: View {
    let item: Item

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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 220, alignment: .leading)
        .background(Palette.panel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

struct DragOutButton: View {
    let item: Item
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label(Copy.t("拖出", "Drag out"), systemImage: "square.and.arrow.up")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(hovering ? Palette.bluePress : Palette.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(reduceMotion ? nil : Palette.motion, value: hovering)
            .onHover { hovering = $0 }
            .onDrag {
                PasteboardService.itemProvider(for: item)
            } preview: {
                DragLiftChip(item: item)
            }
            .accessibilityLabel(Copy.t("拖出结果文件", "Drag out the result file"))
    }
}
