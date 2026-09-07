import DropAgentIngest
import SwiftUI

struct SetupCard: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(SetupCopy.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: { session.dismissSetupCard() }) {
                    Text(SetupCopy.later)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Palette.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setup-later")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                SetupChecklist(session: session)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(SetupCopy.title)
        .accessibilityIdentifier("setup-card")
        .onAppear { session.beginSetupWatch() }
        .onDisappear { session.endSetupWatch() }
    }
}

struct SetupChecklist: View {
    @ObservedObject var session: AppSession
    var includeHotKeys = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            agentRow
            if includeHotKeys {
                hotKeyRow(
                    title: SetupCopy.toggleTitle,
                    ready: session.hotKeyToggleOK,
                    fail: SetupCopy.toggleTaken
                )
                hotKeyRow(
                    title: SetupCopy.captureTitle,
                    ready: session.hotKeyCaptureOK,
                    fail: SetupCopy.captureTaken
                )
                hotKeyRow(
                    title: SetupCopy.filesTitle,
                    ready: session.hotKeyFilesOK,
                    fail: SetupCopy.filesTaken
                )
            }
            accessibilityRow
            finderRow
            ForEach(session.setup.browsers) { browser in
                browserRow(browser)
            }
        }
        .accessibilityIdentifier("setup-checklist")
    }

    private var agentRow: some View {
        let ready = session.hasAgent
        return setupRow(
            title: SetupCopy.agentTitle,
            caption: ready ? SetupCopy.agentReady(session.tuiTitle) : SetupCopy.agentMissing,
            ready: ready,
            actionTitle: ready ? nil : SetupCopy.installAgent,
            enabled: session.authorizingID == nil
        ) {
            session.openTUIInstall(nil)
        }
    }

    private var accessibilityRow: some View {
        let ready = session.setup.accessibilityTrusted
        let caption: String = {
            if ready { return SetupCopy.accessibilityReady }
            if session.setup.accessibilityForeignCopy { return SetupCopy.accessibilityForeign }
            return SetupCopy.accessibilityNeed
        }()
        return setupRow(
            title: SetupCopy.accessibilityTitle,
            caption: caption,
            ready: ready,
            actionTitle: ready ? nil : SetupCopy.authorize,
            enabled: session.authorizingID == nil,
            identifier: "setup-ax"
        ) {
            session.authorizeAccessibility()
        }
    }

    private var finderRow: some View {
        let finder = session.setup.finder
        let ready = finder.allowed
        let busy = session.authorizingID == finder.bundleIdentifier
        let cue = SetupCardPolicy.browserAction(allowed: ready, running: finder.running)
        let action: String? = {
            switch cue {
            case .ready: return nil
            case .openAndAuthorize: return SetupCopy.openAndAuthorize
            case .authorize: return SetupCopy.authorize
            }
        }()
        return setupRow(
            title: SetupCopy.finderTitle,
            caption: ready ? SetupCopy.finderReady : SetupCopy.finderNeed,
            ready: ready,
            actionTitle: action,
            enabled: session.authorizingID == nil || busy,
            identifier: "setup-finder"
        ) {
            session.authorizeBrowser(finder)
        }
        .disabled(session.authorizingID != nil)
        .opacity(session.authorizingID == nil || busy ? 1 : 0.55)
    }

    private func browserRow(_ browser: PageAdmitBrowserRow) -> some View {
        let ready = browser.allowed
        let busy = session.authorizingID == browser.bundleIdentifier
        let cue = SetupCardPolicy.browserAction(allowed: ready, running: browser.running)
        let action: String? = {
            switch cue {
            case .ready: return nil
            case .openAndAuthorize: return SetupCopy.openAndAuthorize
            case .authorize: return SetupCopy.authorize
            }
        }()
        let caption: String = {
            switch cue {
            case .ready: return SetupCopy.browserReady(browser.displayName)
            case .openAndAuthorize: return SetupCopy.browserClosed(browser.displayName)
            case .authorize: return SetupCopy.browserNeed(browser.displayName)
            }
        }()
        return setupRow(
            title: browser.displayName,
            caption: caption,
            ready: ready,
            actionTitle: action,
            enabled: session.authorizingID == nil || busy,
            identifier: "setup-browser-\(browser.bundleIdentifier)"
        ) {
            session.authorizeBrowser(browser)
        }
        .disabled(session.authorizingID != nil)
        .opacity(session.authorizingID == nil || busy ? 1 : 0.55)
    }

    private func hotKeyRow(title: String, ready: Bool, fail: String) -> some View {
        setupRow(
            title: title,
            caption: ready ? SetupCopy.toggleReady : fail,
            ready: ready,
            actionTitle: nil,
            enabled: true,
            action: {}
        )
    }

    private func setupRow(
        title: String,
        caption: String,
        ready: Bool,
        actionTitle: String?,
        enabled: Bool,
        identifier: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ready ? Palette.text : Palette.faint)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
            }
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .padding(.leading, 21)
            if let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(QuietButtonStyle())
                .frame(height: 30)
                .disabled(enabled == false)
                .padding(.leading, 21)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .accessibilityIdentifier(identifier ?? "setup-row")
    }
}
