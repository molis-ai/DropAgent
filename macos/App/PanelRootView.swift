import SwiftUI

struct PanelRootView: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    var onMinimize: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(session: session, onClose: onClose, onMinimize: onMinimize)
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    ShelfColumn(session: session)
                    PanelSplitBar(session: session, edge: .shelf)
                    AIPane(session: session)
                    PanelSplitBar(session: session, edge: .result)
                    ResultStack(session: session)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(coversBody ? 0 : 1)
                .allowsHitTesting(coversBody == false)
                .accessibilityHidden(coversBody)
                if session.spotlight.isActive, coversBody == false {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { session.spotlight.setText("") }
                    HeaderSearchMenu(session: session)
                        .padding(.top, 6)
                }
                if session.settingsOpen {
                    SettingsPane(session: session)
                } else if session.showsSetupCard {
                    SetupCard(session: session)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .ignoresSafeArea()
        .preferredColorScheme(session.prefs.appearance.colorScheme)
        .tint(Palette.text)
        .symbolRenderingMode(.monochrome)
        .onAppear { session.refreshSetup() }
        .onChange(of: session.settingsOpen) { _, _ in
            session.refreshSetup()
        }
    }

    private var coversBody: Bool {
        session.settingsOpen || session.showsSetupCard
    }
}
