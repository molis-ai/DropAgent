import AppKit
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct ResultStack: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ColumnHead(title: Copy.t("结果", "Results")) {
                if !session.results.isEmpty {
                    Text("\(session.results.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Palette.faint)
                }
            }
            if session.results.isEmpty {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "tray.and.arrow.up")
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    Text(Copy.t("处理好的文件", "Your finished files"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(Copy.t("结果会留在这里，随时预览、复制或拖走。", "Results stay here. Preview, copy, or drag them out."))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollViewReader { proxy in
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
                                .id(record.id)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .animation(reduceMotion ? nil : Palette.motion, value: session.results.map(\.id))
                    }
                    .onChange(of: session.selectedResultID) { _, id in
                        guard let id else { return }
                        withAnimation(reduceMotion ? nil : Palette.motion) { proxy.scrollTo(id) }
                    }
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
        .background(AccessibleID(identifier: "result-stack").frame(width: 0, height: 0).allowsHitTesting(false))
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
        .onTapGesture { select() }
        .accessibilityAction(.default) { select() }
        .modifier(ResultRowExport(record: record))
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityLabel(record.title)
        .accessibilityIdentifier("result-\(record.id.rawValue)")
        .contextMenu {
            Button(Copy.t("隐藏", "Hide")) { onHide() }
            Button(Copy.t("删除", "Delete"), role: .destructive) { onDelete() }
        }
    }
    private func select() {
        NSApp.keyWindow?.makeFirstResponder(nil)
        onSelect()
    }

}

private struct ResultRowExport: ViewModifier {
    let record: ResultRecord

    @ViewBuilder
    func body(content: Content) -> some View {
        if record.output != nil {
            content.onDrag {
                PasteboardService.itemProvider(for: record.takeawayItem())
            } preview: {
                DragLiftChip(item: record.takeawayItem())
            }
        } else {
            content
        }
    }
}
