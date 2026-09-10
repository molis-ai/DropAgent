import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case setup
    case actions
    case shortcuts
    case guide
    case machine
    case appearance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .setup: return Copy.t("使用准备", "Setup")
        case .actions: return Copy.t("动作", "Actions")
        case .shortcuts: return Copy.t("快捷键", "Shortcuts")
        case .guide: return Copy.t("能做什么", "How It Works")
        case .machine: return Copy.t("本机", "This Mac")
        case .appearance: return Copy.t("外观", "Appearance")
        }
    }
}

struct SettingsPane: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Copy.t("设置", "Settings"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: { session.settingsOpen = false }) {
                    Text(Copy.t("完成", "Done"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(Palette.panel2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings-done")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 0) {
                sectionList
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1)
                    .padding(.vertical, 8)
                ScrollView {
                    sectionBody
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("设置", "Settings"))
        .accessibilityIdentifier("settings-pane")
        .onAppear { session.beginSetupWatch() }
        .onDisappear { session.endSetupWatch() }
    }

    private var sectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    session.settingsSection = section
                } label: {
                    Text(section.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(TagButtonStyle(selected: session.settingsSection == section))
                .accessibilityIdentifier("settings-nav-\(section.rawValue)")
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(session.settingsSection == section ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(width: 168)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("settings-nav")
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch session.settingsSection {
        case .setup:
            VStack(alignment: .leading, spacing: 12) {
                SettingsForm.sectionTitle(SetupCopy.title)
                SetupChecklist(session: session, includeHotKeys: false)
            }
            .accessibilityIdentifier("settings-setup")
        case .actions:
            SettingsActions(session: session)
        case .shortcuts:
            SettingsShortcuts(session: session)
        case .guide:
            SettingsGuide(session: session)
        case .machine:
            VStack(alignment: .leading, spacing: 22) {
                SettingsWorkspace(session: session)
                SettingsRuntime(session: session)
            }
        case .appearance:
            SettingsLook(session: session)
        }
    }
}
