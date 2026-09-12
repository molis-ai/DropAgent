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
        case .setup: return Copy.t("权限与连接", "Permissions")
        case .actions: return Copy.t("快捷动作", "Actions")
        case .shortcuts: return Copy.t("快捷键", "Shortcuts")
        case .guide: return Copy.t("使用指南", "Guide")
        case .machine: return Copy.t("Agent 与存储", "Agent & storage")
        case .appearance: return Copy.t("外观", "Appearance")
        }
    }

    var symbol: String {
        switch self {
        case .setup: return "lock.shield"
        case .actions: return "bolt"
        case .shortcuts: return "keyboard"
        case .guide: return "book"
        case .machine: return "terminal"
        case .appearance: return "circle.lefthalf.filled"
        }
    }

    var iconTone: Palette.IconTone {
        switch self {
        case .setup, .guide: return .slate
        case .actions, .shortcuts: return .ochre
        case .machine: return .blue
        case .appearance: return .plum
        }
    }

    var detail: String {
        switch self {
        case .setup: return Copy.t("按需要开启功能。暂存文件和本机文字提取无需这些权限。", "Enable features when you need them. Staging and on-device extraction work without these permissions.")
        case .actions: return Copy.t("管理动作，设置动作栏的内容与顺序。", "Manage actions and arrange the action bar.")
        case .shortcuts: return Copy.t("设置打开面板、添加文件和抓取网页的快捷键。", "Set shortcuts for the panel, selected files, and page capture.")
        case .guide: return Copy.t("了解材料导入、文件处理和结果导出。", "Learn how to add files, run actions, and export results.")
        case .machine: return Copy.t("选择本机 Agent，以及材料副本和结果的存放位置。", "Choose your local agent and where copies and results are stored.")
        case .appearance: return Copy.t("设置主题、语言和拖放显示。", "Set the theme, language, and drop wheel visibility.")
        }
    }
}

struct SettingsPane: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Copy.t("设置", "Settings"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer()
                Button(action: { session.settingsOpen = false }) {
                    Text(Copy.t("完成", "Done"))
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("settings-done")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            HStack(alignment: .top, spacing: 0) {
                sectionList
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1)
                    .padding(.vertical, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.settingsSection.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Palette.text)
                                .accessibilityAddTraits(.isHeader)
                            Text(session.settingsSection.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.muted)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        sectionBody
                    }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id(session.settingsSection)
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
        VStack(alignment: .leading, spacing: 4) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    session.settingsSection = section
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.symbol)
                            .foregroundStyle(section.iconTone.ink)
                            .frame(width: 16)
                        Text(section.title)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12, weight: session.settingsSection == section ? .semibold : .medium))
                    .foregroundStyle(session.settingsSection == section ? Palette.accent : Palette.text)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(RowButtonStyle())
                .background {
                    if session.settingsSection == section {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Palette.panelPress)
                            .matchedGeometryEffect(id: "settings-selection", in: selection)
                    }
                }
                .accessibilityIdentifier("settings-nav-\(section.rawValue)")
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(session.settingsSection == section ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(width: 188)
        .frame(maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? nil : Palette.selectionMotion, value: session.settingsSection)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-nav")
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch session.settingsSection {
        case .setup:
            VStack(alignment: .leading, spacing: 12) {
                SetupChecklist(session: session, includeHotKeys: false, showIdentity: true)
            }
            .accessibilityIdentifier("settings-setup")
        case .actions:
            SettingsActions(session: session)
        case .shortcuts:
            SettingsShortcuts(session: session)
        case .guide:
            VStack(alignment: .leading, spacing: 20) {
                Button { session.tryOnboardingSample() } label: {
                    Label(Onboarding.tryTitle, systemImage: "play")
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityIdentifier("settings-try-sample")
                SettingsGuide(session: session)
            }
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
