import DropAgentShelf
import SwiftUI

struct ResultStack: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            if session.guidedSample != nil, session.selectedResult?.status != .failed {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Copy.t("新文件已生成", "Your new file is ready"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.text)
                        Text(Copy.t("第 3 步，共 3 步 · 复制文件，或拖到 Finder、桌面、上传框。", "Step 3 of 3 · Copy the file or drag it to Finder, your desktop, or an upload field."))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button(Copy.t("完成引导", "Finish guide")) { session.dismissFirstActionHint() }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityIdentifier("onboard-result-dismiss")
                }
                .padding(16)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("onboard-result")
            }
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
                            Label(Copy.t("用作材料", "Use as input"), systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel(Copy.t("用作材料", "Use as input"))
                        .background(AccessibleID(identifier: "import-result").frame(width: 0, height: 0).allowsHitTesting(false))
                        .accessibilityIdentifier("import-result")
                        if session.selectedResult?.output != nil {
                            Button { session.copySelected() } label: {
                                Text(Copy.t("复制文件", "Copy file"))
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("take-copy")
                            if session.hasAgent {
                                Button {
                                    session.otherOpen = true
                                    session.aiTab = .tty
                                } label: {
                                    Text(Copy.t("终端", "Terminal"))
                                }
                                .buttonStyle(QuietButtonStyle())
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
