import AppKit
import DropAgentAgent
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import SwiftUI

struct PanelRootView: View {
    @ObservedObject var session: AppSession
    var onClose: () -> Void
    @State private var listHot = false
    @State private var aiHot = false
    @State private var listDragStart: CGFloat?
    @State private var splitHover = false
    @State private var composerFocused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            header
            listSection
            splitbar
            aiSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Palette.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        .tint(Palette.text)
        .symbolRenderingMode(.monochrome)
    }

    private var header: some View {
        ZStack {
            Text("DropAgent")
                .font(.system(size: 15, weight: .medium, design: .serif))
                .tracking(-0.02)
                .foregroundStyle(Palette.text)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                statusChip
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Palette.faint)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .overlay(alignment: .bottom) { Divider().background(Palette.line) }
    }

    @ViewBuilder
    private var statusChip: some View {
        let missing = session.settings.tuiEngine.engine.map { "未发现 \($0.shortTitle)" } ?? "未发现终端"
        let label = session.isCapturing ? "抓取中" : session.hasAgent ? session.tuiTitle : missing
        let spoken = session.isCapturing ? "正在抓当前页"
            : session.hasAgent ? "\(session.tuiTitle) 已连接" : missing
        let symbol = session.isCapturing ? "dot.radiowaves.left.and.right"
            : session.hasAgent ? "checkmark.circle.fill" : "circle.slash"
        let chip = HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.text)
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
        .background(session.isCapturing ? Color.clear : Palette.panel2.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .help("选择终端")
            .accessibilityHint("选择终端 Agent")
        }
    }

    @ViewBuilder
    private var tuiEngineMenu: some View {
        Button("自动") { session.setTUIPreference(.auto) }
        Divider()
        ForEach(AgentEngine.allCases) { engine in
            let found = session.installedEngines.contains { $0.engine == engine }
            let selected = session.settings.tuiEngine.engine == engine
                || (session.settings.tuiEngine == .auto && session.presence.engine == engine)
            Button {
                if let preference = TUIEnginePreference(rawValue: engine.rawValue) {
                    session.setTUIPreference(preference)
                }
            } label: {
                Text(menuTitle(engine: engine, found: found, selected: selected))
            }
        }
        Divider()
        Button("指定可执行文件…") { session.pickTUIExecutable() }
        ForEach(AgentEngine.allCases) { engine in
            Button("如何安装 \(engine.shortTitle)") { session.openTUIInstall(engine) }
        }
    }

    private func menuTitle(engine: AgentEngine, found: Bool, selected: Bool) -> String {
        let mark = selected ? "✓ " : ""
        if found == false {
            return "\(mark)\(engine.shortTitle)（未安装）"
        }
        return "\(mark)\(engine.shortTitle)"
    }

    private var listSection: some View {
        ZStack {
            if session.items.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Palette.text)
                        .accessibilityHidden(true)
                    Text("拖到这里、菜单栏图标或屏幕顶边")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.muted)
                    Text(HotKeyCopy.emptyHint(hasAgent: session.hasAgent, tuiTitle: session.tuiTitle, captureOK: session.hotKeyCaptureOK))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(session.items, id: \.id) { item in
                            ItemRowView(item: item, selected: session.shelf.selection.contains(item.id)) { command in
                                session.toggleSelect(id: item.id, command: command)
                            } onRemove: {
                                session.remove(id: item.id)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(reduceMotion ? nil : Palette.motion, value: session.items.map(\.id))
                }
            }
            dropOverlay(title: "加入架子", offered: session.systemDragActive, hot: listHot)
        }
        .frame(height: session.displayListHeight)
        .animation(reduceMotion ? nil : Palette.motion, value: session.displayListHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("架子")
        .onDrop(of: IncomingDrop.contentTypes, isTargeted: $listHot) { providers in
            session.admitDrop(providers: providers)
            return true
        }
    }

    private var splitbar: some View {
        Rectangle()
            .fill(splitHover ? Palette.blue.opacity(0.22) : Palette.line)
            .frame(height: 7)
            .overlay(
                Capsule()
                    .fill(splitHover ? Palette.blue.opacity(0.55) : Palette.muted.opacity(0.28))
                    .frame(width: 32, height: 3)
            )
            .contentShape(.interaction, Rectangle().inset(by: -6))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if listDragStart == nil { listDragStart = session.displayListHeight }
                        session.setListHeight((listDragStart ?? session.displayListHeight) + value.translation.height)
                    }
                    .onEnded { _ in
                        listDragStart = nil
                        session.persistChrome()
                    }
            )
            .onHover { hovering in
                splitHover = hovering
                if hovering { NSCursor.resizeUpDown.push() } else { NSCursor.pop() }
            }
            .animation(reduceMotion ? nil : Palette.motion, value: splitHover)
            .accessibilityLabel("调整列表高度")
            .accessibilityHint("向上增大架子，向下增大动作区")
            .accessibilityValue("\(Int(session.displayListHeight.rounded())) 点")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    session.setListHeight(session.displayListHeight + 16)
                case .decrement:
                    session.setListHeight(session.displayListHeight - 16)
                @unknown default:
                    break
                }
                session.persistChrome()
            }
    }

    private var aiSection: some View {
        VStack(spacing: 0) {
            ZStack {
                Palette.ai
                VStack(spacing: 0) {
                    tabs
                    ZStack {
                        VStack(spacing: 0) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    errorBanner
                                    if session.aiTab == .result {
                                        resultContent
                                    } else {
                                        workBody
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            if session.aiTab == .result, session.currentResult() != nil {
                                resultTakeaway
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(session.aiTab == .tty ? 0 : 1)
                        .allowsHitTesting(session.aiTab != .tty)

                        VStack(alignment: .leading, spacing: 4) {
                            errorBanner
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
                                                .foregroundStyle(ttyColor(line.kind))
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
                                                Text("正在打开 \(session.tuiTitle)…")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Palette.ttyMuted)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 16)
                                                    .accessibilityLabel("正在打开 \(session.tuiTitle) 终端")
                                            } else {
                                                Text(session.ttyLines.isEmpty ? "发送后，\(session.tuiTitle) 会出现在这里" : "会话不在了。再发送会重新打开。")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Palette.ttyMuted)
                                                    .multilineTextAlignment(.center)
                                                    .padding(.horizontal, 16)
                                                    .accessibilityLabel(session.ttyLines.isEmpty ? "终端还没打开" : "终端会话已结束")
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
                    }
                    composer
                    Text(session.shortcutFooter)
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.faint)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 7)
                }
                dropOverlay(title: session.hasAgent ? "发给 \(session.tuiTitle)" : "加入架子", offered: session.systemDragActive, hot: aiHot)
            }
        }
        .frame(minHeight: 168)
        .frame(maxHeight: .infinity)
        .onDrop(of: IncomingDrop.contentTypes, isTargeted: $aiHot) { providers in
            session.admitToTUI(providers: providers)
            return true
        }
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            tabButton("动作", .work, symbol: "square.grid.2x2", disabled: false)
            tabButton("终端", .tty, symbol: "apple.terminal", disabled: session.canOpenTerminalTab == false && session.aiTab != .tty)
            tabButton("结果", .result, symbol: "doc.plaintext", disabled: session.currentResult() == nil)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .animation(reduceMotion ? nil : Palette.motion, value: session.aiTab)
    }

    private func tabButton(_ title: String, _ tab: AITab, symbol: String, disabled: Bool) -> some View {
        Button {
            if !disabled { session.aiTab = tab }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
            }
        }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: session.aiTab == tab ? .semibold : .regular))
            .foregroundStyle(session.aiTab == tab ? Palette.text : Palette.faint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(session.aiTab == tab ? Palette.panel2 : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(disabled)
            .opacity(disabled ? 0.35 : 1)
            .accessibilityLabel(title)
            .accessibilityAddTraits(session.aiTab == tab ? .isSelected : [])
            .accessibilityHint(disabled ? "现在不可用" : "")
    }

    @ViewBuilder
    private var errorBanner: some View {
        if session.isCapturing == false, let error = session.errorText {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .accessibilityHidden(true)
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) {
                    if session.offerPrivacySettings {
                        Button {
                            session.openPrivacySettings()
                        } label: {
                            Label("去授权", systemImage: "lock.shield")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(width: 88)
                            .accessibilityLabel("打开辅助功能授权")
                    }
                    if session.offerCaptureRetry || session.offerPrivacySettings {
                        Button {
                            session.retryCapture()
                        } label: {
                            Label("再试", systemImage: "arrow.clockwise")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(width: 68)
                            .disabled(session.isCapturing)
                            .accessibilityLabel("再抓一次当前页")
                    }
                    Spacer(minLength: 0)
                    Button("好") { session.dismissError() }
                        .buttonStyle(QuietButtonStyle())
                        .frame(width: 44)
                        .accessibilityLabel("关闭这条提示")
                }
            }
            .padding(8)
            .background(Palette.panel2)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private var workBody: some View {
        if session.isCapturing {
            capturingBody
        } else if session.offerPrivacySettings || session.offerCaptureRetry {
            EmptyView()
        } else {
            let batch = session.selectedItems
            if batch.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(HotKeyCopy.workIdleHint(
                        hasAgent: session.hasAgent,
                        hasRecipe: session.hasRecipe,
                        tuiTitle: session.tuiTitle,
                        captureOK: session.hotKeyCaptureOK,
                        hasItems: session.items.isEmpty == false
                    ))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    if session.hasAgent == false {
                        Button {
                            session.openTUIInstall(nil)
                        } label: {
                            Label("如何安装终端 Agent", systemImage: "arrow.down.app")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .accessibilityLabel("打开终端 Agent 安装说明")
                    }
                }
            } else if batch.contains(where: { $0.status == .confirm }) {
                let idle = batch.filter { $0.status == .confirm }
                VStack(alignment: .leading, spacing: 8) {
                    Text("对 \(idle.count) 项 · \(idle.first?.recipe ?? "")")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    facts(count: idle.count)
                    Text(session.recipeActorLine)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        Task { await session.confirmRun() }
                    } label: {
                        Label("在副本中运行", systemImage: "play.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(!session.hasRecipe)
                    .accessibilityIdentifier("confirm-run")
                    Button {
                        session.cancelConfirm()
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                        .buttonStyle(QuietButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            } else if let running = batch.first(where: { $0.status == .running }) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("运行中")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Text(running.event.isEmpty ? "正在准备副本" : running.event)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(runningEventColor(running.event))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(session.recipeActorLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if running.event.contains("等待授权") {
                        Text(HotKeyCopy.recipeApprovalWaitLine)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.faint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Button {
                        session.cancelRun()
                    } label: {
                        Label("取消", systemImage: "xmark")
                    }
                        .buttonStyle(QuietButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("取消这次副本任务")
                }
            } else if session.isResultTakeaway {
                VStack(alignment: .leading, spacing: 8) {
                    if let reason = session.selectedFailureReason {
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("可拖出")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Text(session.doneActionHint)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        session.aiTab = .result
                    } label: {
                        Label("打开结果", systemImage: "doc.plaintext")
                    }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("打开结果")
                    if let recipe = session.failedOutputRetryRecipe {
                        Button {
                            session.chooseRecipe(recipe)
                        } label: {
                            Label("再跑一次", systemImage: "arrow.clockwise")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("再跑一次：\(recipe.fullTitle)")
                    }
                }
            } else if batch.allSatisfy({ $0.status == .sent }) {
                VStack(alignment: .leading, spacing: 8) {
                    if batch.count == 1, let item = batch.first {
                        stagedPeek(item)
                    }
                    Text("已进终端")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    Text("在「终端」里继续说。这条还在架子上，可以拖走。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                    Button {
                        session.aiTab = .tty
                    } label: {
                        Label("打开终端", systemImage: "apple.terminal")
                    }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("打开终端")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let reason = session.selectedFailureReason {
                        Text(reason)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.warning)
                            .fixedSize(horizontal: false, vertical: true)
                        if let retry = session.failedRetryLine {
                            Text(retry)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.faint)
                        }
                    }
                    if batch.count == 1, let item = batch.first {
                        stagedPeek(item)
                    }
                    Text(session.recipeBatch.count > 1 ? "对 \(session.recipeBatch.count) 项" : "动作")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(RecipeID.allCases, id: \.self) { recipe in
                            Button {
                                session.chooseRecipe(recipe)
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: recipeSymbol(recipe))
                                        .font(.system(size: 14, weight: .regular))
                                    Text(recipe.shortTitle)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                                .buttonStyle(RecipeButtonStyle())
                                .disabled(!session.hasRecipe || !session.recipeFitsSelection(recipe))
                                .help(session.recipeHelp(recipe))
                                .accessibilityIdentifier("recipe-\(recipe.rawValue)")
                                .accessibilityLabel(recipe.fullTitle)
                                .accessibilityHint(session.recipeFitsSelection(recipe) ? "" : session.recipeHelp(recipe))
                        }
                    }
                    Text(session.recipeChooserHint)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    if session.items.count > 1 {
                        Text("Command 点可选多项。")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.faint)
                    }
                    if session.copiedID != nil, batch.contains(where: { $0.id == session.copiedID }) {
                        Text("已复制到剪贴板")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.mint)
                    }
                    if session.hasRecipe == false {
                        Button {
                            session.openTUIInstall(session.hasAgent ? .codex : nil)
                        } label: {
                            Label(
                                session.hasAgent ? "如何安装 Codex" : "如何安装终端 Agent",
                                systemImage: "arrow.down.app"
                            )
                        }
                        .buttonStyle(QuietButtonStyle())
                        .accessibilityLabel(session.hasAgent ? "打开 Codex 安装说明" : "打开终端 Agent 安装说明")
                    }
                }
            }
        }
    }

    private var capturingBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("正在抓当前页")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
            Text("读前台浏览器的地址、正文和截图。缺的会标明，不会造假文件。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
            capturingMeter
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("正在抓当前页")
    }

    @ViewBuilder
    private var capturingMeter: some View {
        let freeze = reduceMotion || ProcessInfo.processInfo.arguments.contains("--preview")
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Palette.panel2)
                .frame(width: 88, height: 3)
            if freeze {
                Capsule()
                    .fill(Palette.text)
                    .frame(width: 36, height: 3)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = t.truncatingRemainder(dividingBy: 1.15) / 1.15
                    let x = 52 * (0.5 - 0.5 * cos(phase * .pi * 2))
                    Capsule()
                        .fill(Palette.text)
                        .frame(width: 36, height: 3)
                        .offset(x: x)
                }
                .frame(width: 88, height: 3)
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var resultContent: some View {
        if let item = session.currentResult() {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.output?.lastPathComponent ?? item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                if let reason = item.failureReason {
                    Text(reason)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.warning)
                }
                if let isolation = session.resultIsolationLine {
                    Text(isolation)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if item.kind == .web {
                    webMaterials(item)
                }
                if item.kind == .image {
                    imagePreview(item)
                }
                if item.kind == .url {
                    urlMaterials(item)
                }
                if item.kind == .clip {
                    stagedTextView(item)
                }
                if item.kind == .markdown && item.output == nil, let body = stagedText(item) {
                    switch StagedPreview.mode(title: item.title, body: body) {
                    case .json:
                        jsonBlock(ResultJSON.pretty(body) ?? body)
                    case .markdown:
                        resultMarkdown(body)
                    case .code:
                        codeBlock(body)
                    }
                }
                if item.kind == .folder {
                    folderListing(item)
                }
                if (item.kind == .pdf || item.kind == .file) && item.output == nil && item.status != .done {
                    Text(item.kind == .pdf ? "这是 PDF，拖出到其他应用打开。" : "这是文件，拖出到其他应用打开。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
                if let output = item.output, let body = try? String(contentsOf: output, encoding: .utf8) {
                    resultDocument(body, output: output)
                } else if item.status == .sent {
                    Text("材料已送进终端。在「终端」里继续说。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
            }
        } else {
            Text("点一条已完成的文件，或点架子上的材料查看。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
    }

    @ViewBuilder
    private var resultTakeaway: some View {
        if let item = session.currentResult() {
            VStack(alignment: .leading, spacing: 6) {
                if session.copiedID == item.id {
                    Text("已复制到剪贴板")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.mint)
                }
                HStack(spacing: 6) {
                    DragOutButton(item: item)
                    Button {
                        session.copyItem(item)
                    } label: {
                        Label("复制", systemImage: "doc.on.doc")
                    }
                        .buttonStyle(QuietButtonStyle())
                        .frame(width: 80)
                    if session.canOpenTerminalTab {
                        Button {
                            session.aiTab = .tty
                        } label: {
                            Label("终端", systemImage: "apple.terminal")
                        }
                            .buttonStyle(QuietButtonStyle())
                            .frame(width: 80)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Divider().background(Palette.line) }
        }
    }

    @ViewBuilder
    private func resultDocument(_ body: String, output: URL) -> some View {
        let ext = output.pathExtension.lowercased()
        if ext == "json" {
            jsonBlock(ResultJSON.pretty(body) ?? body)
        } else {
            resultMarkdown(body)
        }
    }

    private func jsonBlock(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func codeBlock(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(Palette.tty)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
            .accessibilityLabel("代码")
    }

    private func resultMarkdown(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(ResultMarkdown.blocks(body).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(inlineMarkdown(text))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.text)
                case .item(let text):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("·")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Palette.faint)
                        Text(inlineMarkdown(text))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                case .paragraph(let text):
                    Text(inlineMarkdown(text))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                case .code(let text):
                    codeBlock(text)
                case .quote(let text):
                    Text(inlineMarkdown(text))
                        .font(.system(size: 12).italic())
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 12)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Palette.line)
                                .frame(width: 1)
                        }
                        .accessibilityLabel("引用")
                case .image(let alt, let url):
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alt.isEmpty ? "图片" : alt)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                        if let parsed = URL(string: url), SourceLink.isOpenable(parsed) {
                            sourceLink(parsed, size: 11)
                        } else {
                            Text(url)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.faint)
                                .textSelection(.enabled)
                        }
                    }
                    .accessibilityLabel(alt.isEmpty ? "图片" : "图片 \(alt)")
                }
            }
        }
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            if SourceLink.isOpenable(url) {
                SourceLink.open(url)
                return .handled
            }
            return .discarded
        })
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let parsed = try? AttributedString(markdown: text, options: options) {
            return parsed
        }
        return AttributedString(text)
    }

    @ViewBuilder
    private func sourceLink(_ url: URL, size: CGFloat) -> some View {
        let text = url.absoluteString
        if SourceLink.isOpenable(url) {
            Button(text) { SourceLink.open(url) }
                .buttonStyle(.plain)
                .font(.system(size: size))
                .foregroundStyle(Palette.ice)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .accessibilityLabel("打开 \(text)")
        } else {
            Text(text)
                .font(.system(size: size))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func stagedPeek(_ item: Item) -> some View {
        switch item.kind {
        case .web:
            webPeek(item)
        case .image:
            imagePeek(item)
        case .clip:
            peekLine("点「结果」看这段字。")
        case .url:
            VStack(alignment: .leading, spacing: 4) {
                sourceLink(item.sourceURL, size: 11)
                peekLine("点「结果」看链接。")
            }
        case .markdown:
            if item.output == nil {
                peekLine("点「结果」看正文。")
            }
        case .folder:
            peekLine("点「结果」看里面有什么。")
        case .pdf, .file:
            if item.output == nil {
                peekLine("点「结果」看怎么打开。")
            }
        }
    }

    private func peekLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func imagePeek(_ item: Item) -> some View {
        Text("点「结果」看这张图。")
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            .accessibilityLabel("图片 \(item.title)，点结果看图")
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private func imagePreview(_ item: Item) -> some View {
        if let url = imageURL(item), let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
                .accessibilityLabel("图片 \(item.title)")
                .padding(.bottom, 4)
        } else {
            Text("这张图打不开。可以拖出到其他应用查看。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.warning)
                .padding(.bottom, 4)
        }
    }

    private func imageURL(_ item: Item) -> URL? {
        let imagePart = item.parts.first { part in
            let ext = part.name.lowercased()
            return ext.hasSuffix(".png") || ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg")
                || ext.hasSuffix(".gif") || ext.hasSuffix(".webp") || ext.hasSuffix(".tif")
                || ext.hasSuffix(".tiff") || ext.hasSuffix(".heic")
        }
        if let imagePart { return imagePart.url }
        if item.sourceURL.isFileURL { return item.sourceURL }
        return nil
    }

    @ViewBuilder
    private func urlMaterials(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceLink(item.sourceURL, size: 12)
            Text("这是链接，不会自动抓正文。要网页材料请用 ⌃⌥W。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func stagedTextView(_ item: Item) -> some View {
        if let body = stagedText(item) {
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
        }
    }

    private func stagedText(_ item: Item) -> String? {
        let part = item.parts.first { part in
            let lower = part.name.lowercased()
            return lower.hasSuffix(".txt") || lower.hasSuffix(".md") || lower.hasSuffix(".markdown")
                || lower.hasSuffix(".json") || lower.hasSuffix(".swift") || lower.hasSuffix(".py")
                || lower.hasSuffix(".yaml") || lower.hasSuffix(".yml") || lower.hasSuffix(".xml")
                || lower.hasSuffix(".css")
        } ?? item.parts.first
        guard let part, let body = try? String(contentsOf: part.url, encoding: .utf8) else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private func folderListing(_ item: Item) -> some View {
        let names = folderNames(item)
        if names.isEmpty {
            Text("这个文件夹是空的，或打不开。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .padding(.bottom, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                if folderCount(item) > names.count {
                    Text("还有 \(folderCount(item) - names.count) 项未列出。")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.faint)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func folderURL(_ item: Item) -> URL {
        item.parts.first?.url ?? item.sourceURL
    }

    private func folderCount(_ item: Item) -> Int {
        let url = folderURL(item)
        let kids = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return kids.filter { $0.lastPathComponent.hasPrefix(".") == false }.count
    }

    private func folderNames(_ item: Item) -> [String] {
        let url = folderURL(item)
        let kids = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        return kids
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix(".") == false }
            .sorted()
            .prefix(12)
            .map { $0 }
    }

    @ViewBuilder
    private func webPeek(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sourceLink(item.sourceURL, size: 11)
            if item.event.isEmpty == false {
                Text(item.event)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.warning)
                    .lineLimit(2)
            }
            Text("点「结果」看正文和截图。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .accessibilityLabel("网站 \(item.title)，点结果看正文和截图")
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func webMaterials(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceLink(item.sourceURL, size: 12)
            if item.event.isEmpty == false {
                Text(item.event)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.warning)
            }
            if let png = item.parts.first(where: { $0.name.hasSuffix(".png") }),
               let image = NSImage(contentsOf: png.url)
            {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 140)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line))
                    .accessibilityLabel("页面截图")
            }
            if let display = webBodyText(item) {
                resultMarkdown(display)
            }
        }
        .padding(.bottom, 4)
    }

    private func webBodyText(_ item: Item) -> String? {
        guard let md = item.parts.first(where: { $0.name.hasSuffix(".md") }),
              let body = try? String(contentsOf: md.url, encoding: .utf8)
        else { return nil }
        var display = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if display.hasPrefix(item.title) {
            let rest = display.dropFirst(item.title.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if rest.isEmpty == false { display = rest }
        }
        return display.isEmpty ? nil : display
    }

    private func facts(count: Int) -> some View {
        return VStack(spacing: 0) {
            factRow("读", count > 1 ? "\(count) 份材料的副本" : "这份材料的副本")
            Divider().background(Palette.line)
            factRow("写", session.recipeWriteFact)
            Divider().background(Palette.line)
            factRow("网络", session.recipeNetworkFact)
            Divider().background(Palette.line)
            factRow("隔离", session.recipeIsolationFact)
        }
        .background(Palette.panel2)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.bottom, 8)
    }

    private func factRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key)
                .foregroundStyle(Palette.muted)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .foregroundStyle(Palette.text)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 26)
    }

    private var composer: some View {
        HStack(spacing: 6) {
            if session.selectedItems.isEmpty == false {
                Text("\(session.selectedItems.count) 项")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.muted)
                    .frame(minWidth: 32, alignment: .leading)
                    .accessibilityLabel("已选 \(session.selectedItems.count) 项")
            }
            ComposerField(
                text: $session.promptText,
                focused: $composerFocused,
                placeholder: session.composerPlaceholder,
                enabled: session.canSendToTUI,
                onSubmit: { session.sendToTUI() }
            )
                .frame(height: 30)
                .padding(.horizontal, 8)
                .background(Palette.field)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(composerFocused ? Palette.text : Palette.line)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!session.canSendToTUI)
                .opacity(session.canSendToTUI ? 1 : 0.72)
                .layoutPriority(1)
            Button {
                session.pasteFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
            }
                .buttonStyle(QuietButtonStyle())
                .frame(width: 36)
                .accessibilityLabel("从剪贴板加入架子")
            Button {
                session.sendToTUI()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 36)
                .disabled(!session.canSendToTUI)
                .accessibilityIdentifier("send")
                .accessibilityLabel("发送到 \(session.tuiTitle) 终端")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .top) { Divider().background(Palette.line) }
    }

    private func recipeSymbol(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return "text.alignleft"
        case .extract: return "curlybraces"
        case .translate: return "globe"
        case .redact: return "eye.slash"
        case .toMarkdown: return "doc.richtext"
        case .brief: return "square.stack"
        }
    }

    private func runningEventColor(_ event: String) -> Color {
        if event.contains("失败") { return Palette.danger }
        if event.contains("授权") { return Palette.warning }
        return Palette.text
    }

    private func ttyColor(_ kind: String) -> Color {
        switch kind {
        case "sys": return Palette.faint
        case "in": return Palette.ice
        case "file": return Palette.warning
        default: return Palette.tty
        }
    }

    private func dropOverlay(title: String, offered: Bool, hot: Bool) -> some View {
        let visible = hot || offered
        return VStack(spacing: 8) {
            Image(systemName: title.hasPrefix("发给") ? "paperplane" : "tray.and.arrow.down")
                .font(.system(size: 18, weight: .light))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Palette.panel
                    Color.black.opacity(hot ? 0.08 : 0.04)
                }
            }
            .overlay(Rectangle().stroke(Palette.text.opacity(hot ? 0.35 : 0.16), lineWidth: 1))
            .opacity(visible ? 1 : 0)
            .animation(reduceMotion ? nil : Palette.overlay, value: visible)
            .animation(reduceMotion ? nil : Palette.overlay, value: hot)
            .allowsHitTesting(false)
            .accessibilityHidden(!visible)
            .accessibilityLabel(title)
    }
}

struct ItemRowView: View {
    let item: Item
    let selected: Bool
    var onSelect: (Bool) -> Void
    var onRemove: () -> Void
    @State private var runningPulse: Double = 1
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.displayTag)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(Palette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.015)
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                    Spacer()
                    Text(item.timeLabel)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Palette.faint)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 6) {
                    if item.status == .running {
                        pill("运行中", Palette.warning.opacity(0.16), Palette.warning)
                    } else if item.status == .done {
                        pill("可拖出", Palette.mint.opacity(0.16), Palette.mint)
                    } else if item.status == .sent {
                        pill("已进终端", Palette.blue.opacity(0.18), Palette.ice)
                    } else if item.status == .failed {
                        pill("失败", Palette.danger.opacity(0.16), Palette.danger)
                        if item.output != nil {
                            pill("可拖出", Palette.mint.opacity(0.16), Palette.mint)
                        }
                    }
                    Text(item.metaLine)
                        .font(.system(size: 11))
                        .foregroundStyle(item.status == .failed ? Palette.warning : Palette.faint)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityLabel("\(item.displayTag) \(item.title)")
            .accessibilityValue(selected ? "已选，\(rowStatusSpoken(item))" : rowStatusSpoken(item))
            .accessibilityAction(.default) { onSelect(false) }
            if item.status != .running {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(hovering ? Palette.text : Palette.faint)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(hovering ? Palette.panel2 : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .opacity(hovering || selected ? 1 : 0)
                .accessibilityLabel("从架子移除")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(height: 56)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if selected {
                Palette.blue.frame(width: 2)
            }
        }
        .overlay(alignment: .bottom) { Divider().background(Palette.line) }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture { onSelect(ClickModifiers.command) }
        .modifier(RowDrag(item: item))
        .opacity(shouldPulse ? runningPulse : 1)
        .onAppear {
            if shouldPulse { runningPulse = 0.62 }
        }
        .onChange(of: item.status) { _, status in
            runningPulse = status == .running && shouldPulse ? 0.62 : 1
        }
        .animation(
            shouldPulse
                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                : Palette.motion,
            value: runningPulse
        )
    }

    private var shouldPulse: Bool {
        item.status == .running
            && !reduceMotion
            && !ProcessInfo.processInfo.arguments.contains("--preview")
    }

    private var rowBackground: Color {
        if selected { return Palette.blue.opacity(0.1) }
        if hovering { return Palette.panel2.opacity(0.7) }
        return .clear
    }

    private func rowStatusSpoken(_ item: Item) -> String {
        var parts: [String] = []
        switch item.status {
        case .running: parts.append("运行中")
        case .done: parts.append("可拖出")
        case .sent: parts.append("已进终端")
        case .failed:
            parts.append("失败")
            if item.output != nil { parts.append("可拖出") }
        default:
            break
        }
        parts.append(item.metaLine)
        return parts.joined(separator: "，")
    }

    private func pill(_ text: String, _ bg: Color, _ fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(bg)
            .clipShape(Capsule())
    }
}

private struct RowDrag: ViewModifier {
    let item: Item

    func body(content: Content) -> some View {
        if item.status == .running {
            content
        } else {
            content.onDrag {
                PasteboardService.itemProvider(for: item)
            } preview: {
                DragLiftChip(item: item)
            }
        }
    }
}

struct RecipeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RecipeChrome(configuration: configuration)
    }
}

private struct RecipeChrome: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        configuration.label
            .foregroundStyle(isEnabled ? Palette.text : Palette.faint)
            .frame(maxWidth: .infinity)
            .background(Palette.controlFill(enabled: isEnabled, hovering: hovering, pressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Palette.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
            .offset(y: configuration.isPressed && isEnabled ? 1 : 0)
            .animation(reduceMotion ? nil : Palette.motion, value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietChrome(configuration: configuration)
    }
}

private struct QuietChrome: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12))
            .foregroundStyle(isEnabled ? Palette.text : Palette.faint)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Palette.controlFill(enabled: isEnabled, hovering: hovering, pressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Palette.line)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.45)
            .offset(y: configuration.isPressed && isEnabled ? 1 : 0)
            .animation(reduceMotion ? nil : Palette.motion, value: configuration.isPressed)
            .onHover { hovering = $0 }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryChrome(configuration: configuration)
    }
}

private struct PrimaryChrome: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false

    var body: some View {
        configuration.label
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isEnabled ? Palette.onAccent : Palette.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.55)
            .offset(y: configuration.isPressed && isEnabled ? 1 : 0)
            .animation(reduceMotion ? nil : Palette.motion, value: configuration.isPressed)
            .onHover { hovering = $0 }
    }

    private var background: Color {
        guard isEnabled else { return Palette.panel2 }
        if configuration.isPressed { return Palette.bluePress }
        if hovering { return Palette.bluePress }
        return Palette.blue
    }
}

private struct DragLiftChip: View {
    let item: Item

    var body: some View {
        HStack(spacing: 6) {
            Text(item.displayTag)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(Palette.muted)
                .padding(.horizontal, 5)
                .frame(height: 18)
                .background(Palette.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
                .tracking(-0.015)
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: 220, alignment: .leading)
        .background(Palette.panel)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

struct DragOutButton: View {
    let item: Item
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Label("拖出", systemImage: "square.and.arrow.up")
            .labelStyle(.titleAndIcon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(hovering ? Palette.bluePress : Palette.blue)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .animation(reduceMotion ? nil : Palette.motion, value: hovering)
            .onHover { hovering = $0 }
            .onDrag {
                PasteboardService.itemProvider(for: item)
            } preview: {
                DragLiftChip(item: item)
            }
            .accessibilityLabel("拖出结果文件")
    }
}
