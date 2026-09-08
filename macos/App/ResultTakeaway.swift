import SwiftUI

struct ResultTakeaway: View {
    @ObservedObject var session: AppSession

    @ViewBuilder
    var body: some View {
        if session.selectedResult?.output != nil, let item = session.currentResult() {
            VStack(alignment: .leading, spacing: 6) {
                if session.copiedID == item.id {
                    Text(Copy.t("已复制到剪贴板", "Copied to the clipboard"))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.accent)
                }
                VStack(spacing: 4) {
                    DragOutButton(item: item)
                        .frame(maxWidth: .infinity)
                    HStack(spacing: 8) {
                        Button {
                            session.copyItem(item)
                        } label: {
                            Text(Copy.t("复制", "Copy"))
                        }
                        .buttonStyle(QuietButtonStyle())
                        if session.canOpenTerminalTab {
                            Button {
                                session.aiTab = .tty
                            } label: {
                                Text(Copy.t("终端", "Terminal"))
                            }
                            .buttonStyle(QuietButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Divider().background(Palette.line) }
        }
    }
}
