import SwiftUI

struct AIPane: View {
    @ObservedObject var session: AppSession
    @Namespace private var tabSelection
    @State private var aiHot = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Palette.ai
                VStack(spacing: 0) {
                    tabs
                    ZStack {
                        HStack(spacing: 0) {
                            GeometryReader { geo in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        ErrorBanner(session: session)
                                        Group {
                                            if session.aiTab == .result {
                                                ResultPane(session: session)
                                            } else {
                                                WorkPane(session: session)
                                            }
                                        }
                                        .id(contentID)
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 5)))
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .animation(reduceMotion ? nil : Palette.motion, value: contentID)
                                    .frame(width: geo.size.width)
                                    .frame(minHeight: geo.size.height, alignment: .top)
                                }
                            }
                            Color.clear
                                .frame(width: LivePanelChrome.scrollGutter)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(session.aiTab == .tty ? 0 : 1)
                        .allowsHitTesting(session.aiTab != .tty)
                        .accessibilityHidden(session.aiTab == .tty)

                        VStack(alignment: .leading, spacing: 4) {
                            ErrorBanner(session: session)
                            if session.tuiProcessRunning {
                                Text(session.tuiCaption)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.muted)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityLabel(session.tuiCaption)
                            } else if session.ttyLines.isEmpty == false {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(session.ttyLines) { line in
                                            Text(line.text)
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundStyle(TTYPalette.color(line.kind))
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                                .frame(maxHeight: 72)
                            }
                            TerminalHostView(session: session)
                                .frame(minHeight: 120)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Palette.ttyWell)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
                                .overlay {
                                    if session.ptyLive == false {
                                        ZStack {
                                            Palette.ttyWell
                                            if session.pendingTUI != nil || session.tuiProcessRunning {
                                                Text(Copy.t("正在打开 \(session.tuiTitle)…", "Opening \(session.tuiTitle)…"))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Palette.ttyMuted)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 16)
                                                    .accessibilityLabel(Copy.t("正在打开 \(session.tuiTitle) 终端", "Opening the \(session.tuiTitle) terminal"))
                                            } else {
                                                Text(session.ttyLines.isEmpty
                                                    ? Copy.t("发送后，\(session.tuiTitle) 会出现在这里", "After you send, \(session.tuiTitle) appears here")
                                                    : Copy.t("会话不在了。再发送会重新打开。", "The session is gone. Send again to reopen."))
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Palette.ttyMuted)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 16)
                                                    .accessibilityLabel(session.ttyLines.isEmpty
                                                        ? Copy.t("终端还没打开", "Terminal is not open yet")
                                                        : Copy.t("终端会话已结束", "Terminal session ended"))
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .allowsHitTesting(false)
                                    }
                                }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .opacity(session.aiTab == .tty ? 1 : 0)
                        .allowsHitTesting(session.aiTab == .tty)
                        .accessibilityHidden(session.aiTab != .tty)
                    }
                    if session.showsComposer {
                        ComposerBar(session: session)
                            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        Text(Copy.t("回车发送到终端，不是副本沙箱。", "Return sends to the terminal, not the copy sandbox."))
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.faint)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                }
                DropZoneOverlay(
                    title: session.hasAgent
                        ? Copy.t("发给 \(session.tuiTitle)", "Send to \(session.tuiTitle)")
                        : Copy.t("加入架子", "Add to shelf"),
                    offered: session.systemDragActive,
                    hot: aiHot,
                    reduceMotion: reduceMotion
                )
            }
        }
        .animation(reduceMotion ? nil : Palette.motion, value: session.showsComposer)
        .frame(minHeight: 168)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AccessibleID(identifier: "ai-pane").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai-pane")
        .onDrop(of: IncomingDrop.contentTypes, delegate: AdmitDropDelegate(targeted: $aiHot) { providers in
            session.admitToTUI(providers: providers)
        })
    }

    private var contentID: String {
        if session.aiTab == .result { return "preview-" + (session.currentResult()?.id.rawValue ?? "empty") }
        if session.selectedItems.contains(where: { $0.status == .running }) { return "running" }
        if let recipe = session.confirmRecipeID, session.selectedItems.contains(where: { $0.status == .confirm }) {
            return "confirm-" + recipe.rawValue
        }
        return "actions"
    }

    private var tabs: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                tabButton(Copy.t("动作", "Actions"), .work, disabled: false)
                tabButton(Copy.t("终端", "Terminal"), .tty, disabled: session.canOpenTerminalTab == false && session.aiTab != .tty)
                tabButton(Copy.t("预览", "Preview"), .result, disabled: session.currentResult() == nil && session.results.isEmpty)
            }
            .padding(3)
            .background(Palette.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            Spacer(minLength: 0)
            if !session.runningItems.isEmpty {
                Button { session.showRunningJob() } label: {
                    Label(Copy.t("运行中", "Running"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("show-running-job")
                .help(Copy.t("返回任务，可查看进展或取消", "Return to the job to check progress or cancel"))
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 44)
        .animation(reduceMotion ? nil : Palette.selectionMotion, value: session.aiTab)
    }

    private func tabButton(_ title: String, _ tab: AITab, disabled: Bool) -> some View {
        Button { if !disabled { session.openTab(tab) } } label: {
            Text(title)
                .font(.system(size: 11.5, weight: session.aiTab == tab ? .semibold : .medium))
                .foregroundStyle(session.aiTab == tab ? Palette.text : Palette.muted)
                .padding(.horizontal, 11)
                .frame(height: 26)
                .background {
                    if session.aiTab == tab {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Palette.panel)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "tab-selection", in: tabSelection)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .accessibilityLabel(title)
        .accessibilityAddTraits(session.aiTab == tab ? .isSelected : [])
        .accessibilityHint(disabled ? Copy.t("现在不可用", "Unavailable right now") : "")
    }

}

enum TTYPalette {
    static func color(_ kind: String) -> Color {
        switch kind {
        case "sys": return Palette.faint
        case "in": return Palette.ice
        case "file": return Palette.warning
        default: return Palette.tty
        }
    }
}
