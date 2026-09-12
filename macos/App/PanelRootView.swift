import SwiftUI

struct PanelRootView: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    var onMinimize: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(session: session, onClose: onClose, onMinimize: onMinimize)
            ZStack(alignment: .topLeading) {
                GeometryReader { _ in
                    HStack(spacing: 0) {
                        WorkbenchSidebar(session: session)
                            .frame(width: LivePanelChrome.sidebarWidth)
                        WorkbenchDetail(session: session)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Palette.panel)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.line))
                            .padding(.trailing, 7).padding(.bottom, 7)
                    }
                }
                .opacity(coversBody ? 0 : 1)
                .allowsHitTesting(!coversBody)
                .accessibilityHidden(coversBody)
                if session.spotlight.isActive && !coversBody {
                    Color.clear.contentShape(Rectangle()).onTapGesture { session.spotlight.setText("") }.padding(.leading, LivePanelChrome.sidebarWidth)
                    HeaderSearchMenu(session: session).padding(.leading, LivePanelChrome.sidebarWidth).padding(.top, 6)
                }
                if session.settingsOpen { SettingsPane(session: session) }
                else if session.showsSetupCard { SetupCard(session: session) }
            }
        }
        .background(Palette.panel2)
        .overlay {
            DropZoneOverlay(
                title: Copy.t("加入材料", "Add to materials"),
                subtitle: Copy.t("发给终端请拖到轮盘", "Send to the terminal from the wheel"),
                offered: session.panelDropOffered,
                hot: session.panelDropOffered,
                reduceMotion: reduceMotion
            )
            .accessibilityIdentifier("panel-drop-zone")
            .accessibilityHidden(!session.panelDropOffered)
        }
        .overlay(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius).strokeBorder(Palette.line))
        .dropAgentPaper()
        .padding(LivePanelChrome.dockShadowPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
        .preferredColorScheme(session.prefs.appearance.colorScheme)
        .tint(Palette.accent)
        .symbolRenderingMode(.monochrome)
        .onAppear { session.refreshSetup() }
        .onChange(of: session.settingsOpen) { _, open in
            if open { session.closeClipHistory() }
            session.refreshSetup()
        }
    }

    private var coversBody: Bool { session.settingsOpen || session.showsSetupCard }
}
