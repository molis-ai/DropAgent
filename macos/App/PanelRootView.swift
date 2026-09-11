import DropAgentShelf
import SwiftUI

struct PanelRootView: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    var onMinimize: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: session.showsFloat ? LivePanelChrome.dockGap : 0) {
                filePanel
                    .frame(height: coversBody ? LivePanelChrome.panelHeight : nil, alignment: .top)
                    .animation(nil, value: session.showsFloat)
                    .transaction { $0.animation = nil }
                if session.showsFloat || session.canOpenTerminalTab {
                    AIPane(session: session)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(height: session.showsFloat ? nil : 0, alignment: .top)
                        .clipped()
                        .opacity(session.showsFloat ? 1 : 0)
                        .allowsHitTesting(session.showsFloat)
                        .accessibilityHidden(session.showsFloat == false)
                        .animation(reduceMotion ? nil : Palette.floatExpand, value: session.showsFloat)
                }
            }
            .padding(LivePanelChrome.dockShadowPad)
            .fixedSize(horizontal: false, vertical: coversBody == false)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DockHeightKey.self, value: geo.size.height)
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.clear)
        .ignoresSafeArea()
        .preferredColorScheme(session.prefs.appearance.colorScheme)
        .tint(Palette.accent)
        .symbolRenderingMode(.monochrome)
        .onAppear { session.refreshSetup() }
        .onPreferenceChange(DockHeightKey.self) { session.setDockHeight($0) }
        .onChange(of: session.settingsOpen) { _, open in
            if open {
                session.closeClipHistory()
            }
            session.refreshSetup()
            session.applyLayout?()
        }
        .onChange(of: session.spotlight.isActive) { _, on in
            if on { session.closeClipHistory() }
        }
        .onChange(of: session.showsSetupCard) { _, _ in
            session.applyLayout?()
        }
    }

    private var filePanel: some View {
        VStack(spacing: 0) {
            PanelHeader(session: session, onClose: onClose, onMinimize: onMinimize)
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    ShelfColumn(session: session)
                    if coversBody == false {
                        WorkPane(session: session)
                    }
                    if session.showsResultStrip {
                        ResultStack(session: session)
                    }
                }
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
                AccessibleID(identifier: "ai-pane")
                    .frame(width: 0, height: 0)
                    .allowsHitTesting(false)
            }
            .frame(minHeight: coversBody ? LivePanelChrome.panelHeight - 48 : nil, alignment: .top)
        }
        .background(Palette.panel)
        .dropAgentPaper()
    }

    private var coversBody: Bool {
        session.settingsOpen || session.showsSetupCard
    }
}
