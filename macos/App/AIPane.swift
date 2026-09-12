import SwiftUI

struct AIPane: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            ColumnHead(title: Copy.t("对话", "Chat")) {
                HStack {
                    Spacer(minLength: 0)
                    if session.canOpenTerminalTab {
                        Text(session.tuiCaption)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                            .lineLimit(1)
                    }
                    Button { session.toggleOther() } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel(Copy.t("收起对话", "Collapse chat"))
                    .accessibilityIdentifier("collapse-chat")
                }
            }
            if showsLog {
                logBody
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                    .frame(minHeight: 80, maxHeight: .infinity)
                    .background(Palette.panel)
            }
            if session.showsComposer {
                ComposerBar(session: session)
                Text(Copy.t("发给 \(session.tuiTitle) 是终端会话，不是副本沙箱。", "Sending to \(session.tuiTitle) is a terminal session, not the copy sandbox."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .background(Palette.panel)
        .accessibilityElement(children: .contain)
    }

    private var showsLog: Bool {
        session.aiTab == .tty || session.canOpenTerminalTab || session.aiTab == .result
    }

    @ViewBuilder
    private var logBody: some View {
        if session.aiTab == .result, session.currentResult() != nil {
            ScrollView {
                ResultPane(session: session)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Palette.panel)
            .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
        } else {
            ZStack {
                TerminalHostView(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.ttyWell)
                    .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
                if session.ptyLive == false {
                    RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                        .fill(Palette.ttyWell)
                        .overlay {
                            Text(overlayCopy)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.ttyMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .allowsHitTesting(false)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
        }
    }

    private var overlayCopy: String {
        if session.pendingTUI != nil || session.tuiProcessRunning {
            return Copy.t("正在打开 \(session.tuiTitle)…", "Opening \(session.tuiTitle)…")
        }
        if session.ttyLines.isEmpty {
            return Copy.t("发送后，\(session.tuiTitle) 会出现在这里", "After you send, \(session.tuiTitle) appears here")
        }
        return Copy.t("会话不在了。再发送会重新打开。", "The session is gone. Send again to reopen.")
    }
}
