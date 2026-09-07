import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct ResultStack: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            ColumnHead(title: Copy.t("结果", "Results")) {
                EmptyView()
            }
            if session.results.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Copy.t("结果会出现在这里", "Results land here"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text(Copy.t("跑完可以拖到桌面，或拖回左边当新材料。", "Drag out when a job finishes, or back onto the left as new material."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(session.results) { record in
                            ResultRowView(
                                record: record,
                                selected: session.paneFocus == .result && session.selectedResultID == record.id,
                                onSelect: { session.selectResult(record.id) },
                                onHide: { session.hideResult(record.id) },
                                onDelete: { session.deleteResult(record.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if session.paneFocus == .result, session.selectedResultID != nil {
                    ResultTakeaway(session: session)
                }
            }
        }
        .frame(width: session.resultWidth)
        .frame(maxHeight: .infinity)
        .background(Palette.panel2)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("结果", "Results"))
        .accessibilityIdentifier("result-stack")
    }

}

private struct ResultRowView: View {
    let record: ResultRecord
    let selected: Bool
    var onSelect: () -> Void
    var onHide: () -> Void
    var onDelete: () -> Void
    @State private var hovering = false

    var body: some View {
        ListStackRow(
            tag: record.takeawayItem().displayTag,
            kind: record.kind,
            title: record.title,
            subtitle: record.status == .failed ? (record.failureReason ?? Copy.t("失败", "Failed")) : record.recipe,
            warning: record.status == .failed,
            time: record.timeLabel,
            selected: selected,
            hovering: hovering,
            hideHint: Copy.t("从列表拿掉，不删文件", "Remove from the list without deleting files"),
            deleteHint: Copy.t("删除这份产出在 DropAgent 里的文件", "Delete this result’s files inside DropAgent"),
            hideID: "hide-result",
            deleteID: "delete-result",
            onHide: onHide,
            onDelete: onDelete
        )
        .onHover { hovering = $0 }
        .onTapGesture { onSelect() }
        .onDrag {
            PasteboardService.itemProvider(for: record.takeawayItem())
        } preview: {
            DragLiftChip(item: record.takeawayItem())
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(record.title)
        .accessibilityIdentifier("result-\(record.id.rawValue)")
        .contextMenu {
            Button(Copy.t("隐藏", "Hide")) { onHide() }
            Button(Copy.t("删除", "Delete"), role: .destructive) { onDelete() }
        }
    }
}
