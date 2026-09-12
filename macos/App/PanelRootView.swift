import SwiftUI

struct PanelRootView: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    var onMinimize: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(session: session, onClose: onClose, onMinimize: onMinimize)
            ZStack(alignment: .topLeading) {
                GeometryReader { _ in
                    HStack(spacing: 0) {
                        WorkbenchSidebar(session: session)
                            .frame(width: 213)
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
                    Color.clear.contentShape(Rectangle()).onTapGesture { session.spotlight.setText("") }.padding(.leading, 213)
                    HeaderSearchMenu(session: session).padding(.leading, 213).padding(.top, 6)
                }
                if session.settingsOpen { SettingsPane(session: session) }
                else if session.showsSetupCard { SetupCard(session: session) }
            }
        }
        .background(Palette.panel2)
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
