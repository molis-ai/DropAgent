import DropAgentIngest
import SwiftUI

struct SetupCard: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(SetupCopy.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                    Text(SetupCopy.overlayLead)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button(action: { session.dismissSetupCard() }) {
                    Text(SetupCopy.later)
                }
                .buttonStyle(QuietButtonStyle())
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
    var compact = false
    var showIdentity = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            if compact == false {
                agentBlock
            }
            waitCopy
            if includeHotKeys {
                takenHotKeys
            }
            captureBlock
            if compact == false {
                finderBlock
            }
        }
        .accessibilityIdentifier("setup-checklist")
    }

    @ViewBuilder
    private var waitCopy: some View {
        if session.authorizingID != nil {
            Text(session.authorizationSlow
                ? Copy.t("系统授权还没返回。可继续用这个窗口；请看系统提示，或打开自动化设置。", "System permission is still pending. You can keep using this window; check the system prompt or open Automation settings.")
                : Copy.t("正在等待系统授权…", "Waiting for system permission…"))
                .font(.system(size: compact ? 9.5 : 12))
                .foregroundStyle(Palette.muted)
            if compact {
                JourneyLink(title: SetupCopy.openAutomationSettings, kind: .skip) {
                    session.openAutomationSettings()
                }
            } else {
                Button(SetupCopy.openAutomationSettings) { session.openAutomationSettings() }
                    .buttonStyle(QuietButtonStyle())
            }
        } else if session.setupRefreshing && !session.setupLoaded {
            Text(Copy.t("正在检测权限…", "Checking permissions…"))
                .font(.system(size: 12))
                .foregroundStyle(Palette.faint)
        }
    }

    private var agentBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if compact == false {
                SettingsForm.sectionTitle(SetupCopy.agentSection)
            }
            agentRow
        }
    }

    private var captureBlock: some View {
        VStack(alignment: .leading, spacing: compact ? 1 : 10) {
            if compact == false {
                SettingsForm.sectionTitle(SetupCopy.captureGroupTitle)
                Text(SetupCopy.captureGroupLead)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            accessibilityRow
            ForEach(session.setup.browsers) { browser in
                browserRow(browser)
            }
        }
    }

    private var finderBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsForm.sectionTitle(SetupCopy.finderSection)
            finderRow
        }
    }

    @ViewBuilder
    private var takenHotKeys: some View {
        if session.hotKeyToggleOK == false {
            hotKeyRow(title: SetupCopy.toggleTitle, fail: SetupCopy.toggleTaken)
        }
        if session.hotKeyCaptureOK == false {
            hotKeyRow(title: SetupCopy.captureTitle, fail: SetupCopy.captureTaken)
        }
        if session.hotKeyFilesOK == false {
            hotKeyRow(title: SetupCopy.filesTitle, fail: SetupCopy.filesTaken)
        }
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
            let base: String
            if session.setup.accessibilityForeignCopy {
                base = SetupCopy.accessibilityForeign
            } else {
                base = compact ? SetupCopy.accessibilityNeedShort : SetupCopy.accessibilityNeed
            }
            if showIdentity {
                return base + "\n" + Copy.t("当前应用：", "Current app: ") + Bundle.main.bundleURL.path
            }
            return base
        }()
        let compactHint: String? = {
            guard compact, ready == false, session.setup.accessibilityForeignCopy else { return nil }
            return caption
        }()
        return VStack(alignment: .leading, spacing: compact ? 2 : 8) {
            setupRow(
                title: SetupCopy.accessibilityTitle,
                caption: caption,
                ready: ready,
                actionTitle: ready ? nil : SetupCopy.authorize,
                enabled: session.authorizingID == nil,
                identifier: "setup-ax",
                hint: compactHint
            ) {
                session.authorizeAccessibility()
            }
            if ready == false && session.askedAccessibility {
                if compact {
                    JourneyLink(title: SetupCopy.openAccessibilitySettings, kind: .skip) {
                        session.openAccessibilitySettings()
                    }
                    .padding(.leading, 8)
                    .accessibilityIdentifier("setup-ax-settings")
                } else {
                    Button(SetupCopy.openAccessibilitySettings) {
                        session.openAccessibilitySettings()
                    }
                    .buttonStyle(QuietButtonStyle())
                    .padding(.leading, 21)
                    .accessibilityIdentifier("setup-ax-settings")
                }
            }
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
            caption: SetupCopy.automationStatus(finder),
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
        let caption = SetupCopy.automationStatus(browser, compact: compact)
        let compactHint: String? = {
            guard compact, ready == false else { return nil }
            switch browser.state {
            case .notDetermined: return nil
            default: return caption
            }
        }()
        return setupRow(
            title: browser.displayName,
            caption: caption,
            ready: ready,
            actionTitle: action,
            enabled: session.authorizingID == nil || busy,
            identifier: "setup-browser-\(browser.bundleIdentifier)",
            hint: compactHint
        ) {
            session.authorizeBrowser(browser)
        }
        .disabled(session.authorizingID != nil)
        .opacity(session.authorizingID == nil || busy ? 1 : 0.55)
    }

    private func hotKeyRow(title: String, fail: String) -> some View {
        setupRow(
            title: title,
            caption: fail,
            ready: false,
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
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Group {
            if compact {
                JourneyPermissionRow(
                    title: title,
                    hint: hint,
                    ready: ready,
                    actionTitle: actionTitle,
                    enabled: enabled,
                    identifier: identifier ?? "setup-row",
                    action: action
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: ready ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ready ? Palette.text : Palette.faint)
                        Text(title)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.text)
                        Spacer(minLength: 0)
                        if let actionTitle {
                            Button(action: { if ready == false { action() } }) {
                                Text(actionTitle)
                            }
                            .buttonStyle(QuietButtonStyle())
                            .disabled(enabled == false)
                        }
                    }
                    Text(caption)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.leading, 21)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier(identifier ?? "setup-row")
            }
        }
    }
}

private struct JourneyPermissionRow: View {
    var title: String
    var hint: String?
    var ready: Bool
    var actionTitle: String?
    var enabled: Bool
    var identifier: String
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let actionTitle, ready == false {
                        Text(actionTitle)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(hovering ? Palette.accent : Palette.muted)
                    }
                    Circle()
                        .fill(ready ? Palette.accent : Color.clear)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                }
                if let hint, ready == false {
                    Text(hint)
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(ready ? Palette.panel2 : (hovering ? Palette.panelHover : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .disabled(enabled == false)
        .onHover { hovering = $0 }
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(title)
        .accessibilityValue(ready ? Copy.t("已允许", "Allowed") : (actionTitle ?? ""))
    }
}

struct CaptureReadyBanner: View {
    @ObservedObject var session: AppSession

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            JourneyEcho(strong: SetupCopy.bannerTitle + " " + SetupCopy.bannerDetail)
            Spacer(minLength: 8)
            JourneyLink(title: SetupCopy.later, kind: .skip) {
                session.dismissSetupCard()
            }
            .accessibilityIdentifier("capture-banner-later")
            JourneyLink(title: SetupCopy.prepare, kind: .nav) {
                session.requestSetupCard()
            }
            .accessibilityIdentifier("capture-banner-prepare")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .accessibilityIdentifier("capture-banner")
        .onAppear { session.beginSetupWatch() }
        .onDisappear { session.endSetupWatch() }
    }
}
