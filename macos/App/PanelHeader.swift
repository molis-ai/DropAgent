import DropAgentAgent
import SwiftUI

struct PanelHeader: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    var onMinimize: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                Text("D").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.panel2).frame(width: 20, height: 20)
                    .background(Palette.accent, in: RoundedRectangle(cornerRadius: 5))
            Text("DropAgent")
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.3)
                .fixedSize()
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
                WindowDragHandle().frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityHidden(true)
            }
            .padding(.leading, 19).frame(width: 213)
            HStack(spacing: 12) {
                Text(location).foregroundStyle(Palette.muted).fixedSize()
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(Palette.muted)
                Text(selectionTitle).foregroundStyle(Palette.text).lineLimit(1).truncationMode(.middle)
            }.font(.system(size: 12)).padding(.leading, 20)
            WindowDragHandle()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(0)
                .accessibilityHidden(true)
            statusChip.padding(.trailing, 8)
            Button {
                session.onPanelInteraction?()
                session.settingsOpen.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: session.settingsOpen ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 11, weight: .medium))
                    if session.gearNeedsAttention && session.settingsOpen == false {
                        Circle()
                            .fill(Palette.warning)
                            .frame(width: 5, height: 5)
                            .offset(x: -4, y: 4)
                            .accessibilityHidden(true)
                    }
                }
            }
            .buttonStyle(IconButtonStyle(selected: session.settingsOpen))
            .accessibilityLabel(Copy.t("设置", "Settings"))
            .accessibilityHint(Copy.t("管理权限、动作、Agent 和外观", "Manage permissions, actions, agents, and appearance"))
            .accessibilityIdentifier("settings")
            Button(action: onMinimize) {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(Copy.t("最小化", "Minimize"))
            .accessibilityHint(Copy.t("把面板收起来，和点菜单栏图标一样", "Hide the panel, same as clicking the menu bar icon"))
            .accessibilityIdentifier("minimize")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel(Copy.t("关闭", "Close"))
        }
        .padding(.trailing, 10)
        .frame(height: 48)
        .background(Palette.panel2)
    }

    private var location: String {
        if session.settingsOpen { return Copy.t("设置", "Settings") }
        switch session.paneFocus {
        case .input: return Copy.t("材料", "Materials")
        case .result: return Copy.t("生成结果", "Results")
        case .clipboard: return Copy.t("剪贴板", "Clipboard")
        }
    }

    private var selectionTitle: String {
        if session.settingsOpen { return "DropAgent" }
        if session.paneFocus == .clipboard { return session.selectedClipboard?.title ?? Copy.t("历史记录", "History") }
        return session.stagedItem?.title ?? Copy.t("工作区", "Workspace")
    }

    @ViewBuilder
    private var statusChip: some View {
        let missing: String = {
            if let id = session.settings.selectedCustomID,
               let custom = session.settings.customRuntimes.first(where: { $0.id == id }) {
                return Copy.t("未发现 \(custom.title)", "\(custom.title) not found")
            }
            if let engine = session.settings.tuiEngine.engine {
                return Copy.t("未发现 \(engine.shortTitle)", "\(engine.shortTitle) not found")
            }
            return Copy.t("选择 Agent", "Choose agent")
        }()
        let label = session.isCapturing
            ? Copy.t("抓取中", "Capturing")
            : session.hasAgent ? session.tuiTitle : missing
        let spoken = session.isCapturing
            ? Copy.t("正在抓当前页", "Capturing the current page")
            : session.hasAgent
                ? Copy.t("\(session.tuiTitle) 可用", "\(session.tuiTitle) available")
                : missing
        let symbol = session.isCapturing ? "dot.radiowaves.left.and.right"
            : session.hasAgent ? "terminal" : "plus.circle"
        let chip = HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.tty)
                .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            if session.isCapturing == false {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Palette.faint)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spoken)

        if session.isCapturing {
            chip
        } else {
            Menu {
                tuiEngineMenu
            } label: {
                chip
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .help(Copy.t("选择终端", "Choose terminal"))
            .accessibilityHint(Copy.t("选择终端 Agent", "Choose a terminal agent"))
        }
    }

    @ViewBuilder
    private var tuiEngineMenu: some View {
        Button(Copy.t("自动", "Auto")) { session.setTUIPreference(.auto) }
        Divider()
        ForEach(AgentEngine.tuiCases) { engine in
            engineMenuButton(engine)
        }
        if AgentEngine.cliCases.isEmpty == false {
            Divider()
            ForEach(AgentEngine.cliCases) { engine in
                engineMenuButton(engine)
            }
        }
        if session.settings.customRuntimes.isEmpty == false {
            Divider()
            ForEach(session.settings.customRuntimes) { custom in
                let found = session.installedEngines.contains { $0.runtimeKey == "custom:\(custom.id)" }
                let selected = session.settings.selectedCustomID == custom.id
                Button {
                    session.setCustomRuntime(custom.id)
                } label: {
                    Text(customMenuTitle(custom, found: found, selected: selected))
                }
            }
        }
        Divider()
        Button(Copy.t("管理 Agent…", "Manage agents…")) {
            session.settingsSection = .machine
            session.settingsOpen = true
        }
        Button(Copy.t("指定可执行文件…", "Choose executable…")) { session.pickTUIExecutable() }
        ForEach(AgentEngine.tuiCases) { engine in
            Button(Copy.t("如何安装 \(engine.shortTitle)", "How to install \(engine.shortTitle)")) {
                session.openTUIInstall(engine)
            }
        }
    }

    private func engineMenuButton(_ engine: AgentEngine) -> some View {
        let found = session.installedEngines.contains { $0.engine == engine }
        let selected = session.settings.selectedCustomID == nil
            && (session.settings.tuiEngine.engine == engine
                || (session.settings.tuiEngine == .auto && session.presence.engine == engine))
        return Button {
            if let preference = TUIEnginePreference(rawValue: engine.rawValue) {
                session.setTUIPreference(preference)
            }
        } label: {
            Text(menuTitle(engine: engine, found: found, selected: selected))
        }
    }

    private func menuTitle(engine: AgentEngine, found: Bool, selected: Bool) -> String {
        let mark = selected ? "✓ " : ""
        if found == false {
            return Copy.t("\(mark)\(engine.shortTitle)（未安装）", "\(mark)\(engine.shortTitle) (not installed)")
        }
        return "\(mark)\(engine.shortTitle)"
    }

    private func customMenuTitle(_ custom: CustomRuntime, found: Bool, selected: Bool) -> String {
        let mark = selected ? "✓ " : ""
        let kind = custom.kind == .cli ? Copy.t("CLI", "CLI") : "TUI"
        if found == false {
            return Copy.t("\(mark)\(custom.title)（未安装 · \(kind)）", "\(mark)\(custom.title) (not installed · \(kind))")
        }
        return "\(mark)\(custom.title) · \(kind)"
    }
}
