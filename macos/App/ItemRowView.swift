import DropAgentShelf
import SwiftUI

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
            .accessibilityHint(Copy.t("从列表拿掉，不删文件", "Remove from the list without deleting files"))
            .help(Copy.t("隐藏", "Hide"))
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
            .accessibilityHint(Copy.t("删除 DropAgent 里的副本，原件保留", "Delete DropAgent’s copy. The original stays."))
            .help(Copy.t("删除", "Delete"))
            .accessibilityIdentifier(deleteID)
        }
        .background(visible ? Palette.panel2 : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }
}

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
