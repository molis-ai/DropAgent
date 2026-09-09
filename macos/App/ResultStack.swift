import DropAgentShelf
import SwiftUI

struct ResultStack: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            ColumnHead(title: Copy.t("结果区", "Results")) {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    if session.selectedResultID != nil {
                        Text(Copy.t("已选 1", "1 selected"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                        Button {
                            session.importSelectedResults()
                        } label: {
                            Label(Copy.t("放到上面当材料", "Use as material"), systemImage: "square.and.arrow.down")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Copy.t("放到上面当材料", "Use as material"))
                        .background(AccessibleID(identifier: "import-result").frame(width: 0, height: 0).allowsHitTesting(false))
                        .accessibilityIdentifier("import-result")
                        if session.selectedResult?.output != nil {
                            Button { session.copySelected() } label: {
                                Text(Copy.t("复制", "Copy"))
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("take-copy")
                            if session.hasAgent {
                                Button {
                                    session.otherOpen = true
                                    session.aiTab = .tty
                                } label: {
                                    Text(Copy.t("终端", "Terminal"))
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("take-tty")
                            }
                        }
                    }
                }
                .foregroundStyle(Palette.text)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.results) { record in
                        FileCard(
                            item: record.takeawayItem(),
                            selected: session.paneFocus == .result && session.selectedResultID == record.id,
                            isResult: true,
                            dragGroup: session.paneFocus == .result && session.selectedResultID == record.id
                                ? [record.takeawayItem()] : [],
                            onSelect: { _ in session.toggleResult(record.id) },
                            onOpen: { session.openItem(record.takeawayItem()) },
                            onHide: { session.hideResult(record.id) },
                            onDelete: { session.deleteResult(record.id) },
                        )
                        .id(record.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
            }
        }
        .background(Palette.panel2)
        .background(AccessibleID(identifier: "result-stack").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("结果区", "Results"))
        .accessibilityIdentifier("result-stack")
    }
}
