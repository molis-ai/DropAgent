import Combine
import DropAgentAgent
import DropAgentIngest
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import DropAgentTUI
import Foundation
import SwiftUI
import AppKit

enum AITab: String {
    case work
    case tty
    case result
}

struct TTYLine: Identifiable, Equatable {
    var id = UUID()
    var kind: String
    var text: String
}

@MainActor
final class AppSession: ObservableObject {
    let shelf: ShelfStore
    let ingest: IngestService
    let job: JobService
    let tui: TUIService
    let agent: AgentService

    @Published var items: [Item] = []
    @Published var presence: AgentPresence = .none
    @Published var recipePresence: AgentPresence = .none
    @Published var installedEngines: [AgentPresence] = []
    @Published var aiTab: AITab = .work {
        didSet {
            guard oldValue != aiTab else { return }
            if aiTab == .tty {
                giveTerminalRoom()
            } else if oldValue == .tty {
                restoreListAfterTerminal()
            }
        }
    }
    @Published var listHeight: CGFloat = 140
    private var listHeightTouched = false
    @Published var promptText: String = ""
    @Published var copiedID: ItemID?
    @Published var ttyLines: [TTYLine] = []
    @Published var errorText: String?
    @Published var pendingTUI: PreparedTUISend?
    @Published var tuiSessionDirectory: URL?
    @Published var settings = AgentSettings()
    @Published var offerPrivacySettings = false
    @Published var offerCaptureRetry = false
    @Published var tuiProcessRunning = false
    @Published var ptyLive = false
    @Published var isCapturing = false
    @Published var systemDragActive = false
    @Published var hotKeyToggleOK = true
    @Published var hotKeyCaptureOK = true
    @Published var tuiEpoch = UUID()
    private var lastCaptureToken: PageAdmitToken?
    private var listHeightBeforeTerminal: CGFloat?
    private var terminalOwnsListHeight = false

    static let captureFailedCopy = PageAdmitCopy.needAccessibility

    init(jobRunner: (any AgentRunning)? = nil) {
        try? DropAgentPaths.ensure()
        var loaded = AgentSettings()
        if let data = try? Data(contentsOf: DropAgentPaths.settingsFile),
           let decoded = try? JSONDecoder().decode(AgentSettings.self, from: data) {
            loaded = decoded
        }
        settings = loaded
        shelf = ShelfStore(fileURL: DropAgentPaths.shelfFile)
        ingest = IngestService(shelf: shelf, inboxRoot: DropAgentPaths.inbox)
        agent = AgentService(runner: CodexCLI(), settings: loaded)
        job = JobService(shelf: shelf, agent: jobRunner ?? agent, jobsRoot: DropAgentPaths.jobs)
        tui = TUIService(shelf: shelf, agent: agent, inboxRoot: DropAgentPaths.tuiInbox)
        shelf.load()
        refreshPresence()
        refresh()
        shelf.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        let chrome = Self.storedChrome()
        listHeight = chrome.height
        listHeightTouched = chrome.touched
    }

    var selectedItems: [Item] { shelf.selectedItems() }
    var hasAgent: Bool { presence.engine != nil }
    var canSendToTUI: Bool {
        hasAgent && isCapturing == false && selectedItems.contains { $0.status == .running || $0.status == .confirm } == false
    }
    var composerPlaceholder: String {
        if hasAgent == false { return "未发现终端 Agent" }
        if isCapturing { return "正在抓当前页" }
        if selectedItems.contains(where: { $0.status == .running }) { return "等任务结束，或点取消" }
        if selectedItems.contains(where: { $0.status == .confirm }) { return "先运行或取消这次动作" }
        return "写给 \(tuiTitle)，回车发送"
    }
    var hasRecipe: Bool {
        if case .codex = recipePresence { return true }
        return false
    }
    var tuiTitle: String { presence.engine?.shortTitle ?? "Agent" }
    var recipeActorLine: String {
        HotKeyCopy.recipeActorLine(hasRecipe: hasRecipe, hasAgent: hasAgent, tuiTitle: tuiTitle)
    }
    var recipeIsolationFact: String {
        guard hasRecipe else { return "无 Codex" }
        return agent.isolationCopy(for: recipePresence)
    }
    var recipeWriteFact: String {
        guard hasRecipe else { return "无 Codex" }
        if recipePresence.isolation == .workspace { return "仅任务目录" }
        return "未确认仅任务目录"
    }
    var recipeNetworkFact: String {
        guard hasRecipe else { return "无 Codex" }
        if recipePresence.isolation != .workspace { return "未确认" }
        let wants = confirmRecipeID.map { RecipeCatalog.spec($0).needsNetwork } ?? false
        return wants ? "开" : "关"
    }
    var confirmRecipeID: RecipeID? {
        let title = selectedItems.first(where: { $0.status == .confirm })?.recipe
            ?? selectedItems.first?.recipe
        return RecipeID.allCases.first { $0.fullTitle == title }
    }
    var shortcutFooter: String {
        let keys = HotKeyCopy.hotkeyLine(hasAgent: hasAgent, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK)
        if isCapturing {
            return "正在抓当前页，完成前先不发送。\n" + keys
        }
        if selectedItems.contains(where: { $0.status == .confirm || $0.status == .running }) {
            return keys
        }
        return HotKeyCopy.footer(hasAgent: hasAgent, tuiTitle: tuiTitle, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK)
    }

    var recipeBatch: [Item] {
        selectedItems.filter { $0.status == .idle || $0.status == .confirm || $0.status == .failed }
    }

    func recipeFitsSelection(_ recipe: RecipeID) -> Bool {
        let spec = RecipeCatalog.spec(recipe)
        let batch = recipeBatch
        guard batch.count >= recipe.minimumCount else { return false }
        return batch.allSatisfy { spec.acceptedKinds.contains($0.kind) }
    }

    func recipeHelp(_ recipe: RecipeID) -> String {
        if hasRecipe == false { return "动作需要 Codex" }
        if recipeFitsSelection(recipe) { return recipe.fullTitle }
        if recipeBatch.count < recipe.minimumCount {
            return "「\(recipe.shortTitle)」至少要两份材料"
        }
        return "选中的材料不能用「\(recipe.shortTitle)」"
    }

    var recipeChooserHint: String {
        if hasAgent == false {
            return "安装终端 Agent 后可发送。现在只能暂存，或点右上角选择已装的 TUI。"
        }
        if hasRecipe == false {
            return "动作需要 Codex。下面可以发给 \(tuiTitle)。"
        }
        if RecipeID.allCases.contains(where: recipeFitsSelection) {
            return "或在下面写一句话，发送到 \(tuiTitle) 终端。"
        }
        if recipeBatch.contains(where: { $0.kind == .file }) && recipeBatch.count < RecipeID.brief.minimumCount {
            return "这类文件不能总结或翻译。发给 \(tuiTitle)，或再选一份做「新交付」。"
        }
        return "选中的材料不能跑这些动作。发给 \(tuiTitle)。"
    }

    var selectedFailureReason: String? {
        selectedItems.first(where: { $0.status == .failed })?.failureReason
    }

    var failedRetryLine: String? {
        guard selectedFailureReason != nil, hasRecipe else { return nil }
        return "再点一个动作可以重试。"
    }

    var isDoneTakeaway: Bool {
        let batch = selectedItems
        return batch.isEmpty == false && batch.allSatisfy { $0.status == .done }
    }

    var isFailedOutputTakeaway: Bool {
        let batch = selectedItems
        return batch.isEmpty == false && batch.allSatisfy { $0.status == .failed && $0.output != nil }
    }

    var isResultTakeaway: Bool {
        isDoneTakeaway || isFailedOutputTakeaway
    }

    var failedOutputRetryRecipe: RecipeID? {
        guard isFailedOutputTakeaway, hasRecipe else { return nil }
        guard let title = selectedItems.first?.recipe else { return nil }
        return RecipeID.allCases.first { $0.fullTitle == title }
    }

    var doneActionHint: String {
        if hasAgent {
            return "点「结果」拿走，或发给 \(tuiTitle)。"
        }
        return "点「结果」拿走。没有终端也能拖出或复制。"
    }

    var canOpenTerminalTab: Bool {
        tuiSessionDirectory != nil || ttyLines.isEmpty == false
    }

    var resultIsolationLine: String? {
        currentResult()?.isolationShown.spokenFact
    }

    func refresh() {
        items = shelf.items()
    }

    func refreshPresence() {
        recipePresence = agent.recipePresence(settings: settings)
        installedEngines = agent.installedEngines(settings: settings)
        presence = agent.tuiPresence(settings: settings)
    }

    func saveSettings() {
        try? DropAgentPaths.ensure()
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: DropAgentPaths.settingsFile, options: .atomic)
        }
        agent.settings = settings
        refreshPresence()
    }

    func admit(urls: [URL]) {
        note(ingest.admit(urls: urls))
        refresh()
        aiTab = .work
    }

    func admitDrop(providers: [NSItemProvider]) {
        Task {
            let result = await ingest.admitProviders(providers)
            note(result)
            refresh()
            aiTab = .work
        }
    }

    func admitPasteboard(_ pasteboard: NSPasteboard) {
        note(ingest.admitPasteboard(pasteboard))
        refresh()
        aiTab = .work
    }

    func admitToTUI(providers: [NSItemProvider]) {
        Task {
            let result = await ingest.admitProviders(providers)
            note(result)
            refresh()
            let ids = result.admitted.map(\.id)
            shelf.setSelection(Set(ids))
            if hasAgent {
                sendToTUI(itemIDs: ids)
            } else {
                errorText = "未发现终端 Agent。文件已留在架子上。"
                aiTab = .work
            }
        }
    }

    func admitToTUI(urls: [URL]) {
        let result = ingest.admit(urls: urls)
        note(result)
        refresh()
        let ids = result.admitted.map(\.id)
        shelf.setSelection(Set(ids))
        if hasAgent {
            sendToTUI(itemIDs: ids)
        } else {
            errorText = "未发现终端 Agent。文件已留在架子上。"
            aiTab = .work
        }
    }

    func pasteFromClipboard(_ clipboard: any ClipboardReading = SystemClipboard()) {
        do {
            _ = try ingest.admitClipboard(clipboard)
            refresh()
            aiTab = .work
        } catch {
            errorText = human(error)
        }
    }

    func prepareCapture() {
        lastCaptureToken = PageAdmitToken.snapshot()
        isCapturing = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        aiTab = .work
    }

    func captureCurrentPage(token: PageAdmitToken) async {
        lastCaptureToken = token
        isCapturing = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        aiTab = .work
        await captureCurrentPage()
    }

    func captureCurrentPage() async {
        if isCapturing == false {
            prepareCapture()
        }
        let token = lastCaptureToken ?? .snapshot()
        let isCLI = ProcessInfo.processInfo.arguments.contains("--capture")
        if isCLI == false {
            let decision = PageAdmit.decide(token: token)
            if decision.proceed == false {
                if decision.promptAccessibility {
                    PageAdmit.requestTrustIfNeeded()
                }
                errorText = captureCopy(decision.message)
                offerPrivacySettings = decision.offerPrivacySettings
                offerCaptureRetry = true
                aiTab = .work
                isCapturing = false
                return
            }
        }
        do {
            let item = try await ingest.admitCurrentPage(token: token)
            shelf.setSelection([item.id])
            errorText = nil
            offerPrivacySettings = false
            offerCaptureRetry = false
            aiTab = .work
        } catch {
            let failed = PageAdmit.failure(token: token)
            errorText = captureCopy(failed.message)
            offerPrivacySettings = failed.offerPrivacySettings
            offerCaptureRetry = true
            aiTab = .work
        }
        isCapturing = false
    }

    private func captureCopy(_ message: String) -> String {
        if message == PageAdmitCopy.noBrowser, hotKeyCaptureOK {
            return PageAdmitCopy.noBrowserHotKey
        }
        return message
    }

    func retryCapture() {
        guard isCapturing == false else { return }
        Task { await captureCurrentPage() }
    }

    func dismissError() {
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
    }

    func openPrivacySettings() {
        let wantAccessibility = PageAdmit.isTrusted() == false
        if wantAccessibility {
            PageAdmit.requestTrustIfNeeded()
        }
        let panes = wantAccessibility
            ? [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            ]
            : [
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            ]
        for pane in panes {
            if let url = URL(string: pane), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    func toggleSelect(id: ItemID, command: Bool) {
        shelf.toggleSelect(id: id, command: command)
        if command { return }
        if let item = shelf.item(id: id) {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = .tty }
            else { aiTab = .work }
        }
    }

    func remove(id: ItemID) {
        try? shelf.remove(ids: [id])
        refresh()
    }

    func removeSelected() {
        let ids = selectedItems.filter { $0.status != .running }.map(\.id)
        guard !ids.isEmpty else { return }
        try? shelf.remove(ids: ids)
        refresh()
    }

    func moveSelection(offset: Int) {
        shelf.moveSelection(offset: offset)
        if let item = selectedItems.first {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = .tty }
            else { aiTab = .work }
        }
    }

    func chooseRecipe(_ recipe: RecipeID) {
        let spec = RecipeCatalog.spec(recipe)
        var skipped = 0
        for item in selectedItems where item.status == .idle || item.status == .confirm || item.status == .failed {
            guard spec.acceptedKinds.contains(item.kind) else {
                skipped += 1
                continue
            }
            try? shelf.patch(id: item.id) { live in
                live.recipe = recipe.fullTitle
                live.status = .confirm
            }
        }
        if skipped > 0 {
            errorText = "有 \(skipped) 项不能用「\(recipe.shortTitle)」"
        }
        aiTab = .work
    }

    func cancelConfirm() {
        for item in selectedItems where item.status == .confirm {
            try? shelf.patch(id: item.id) { live in
                live.status = .idle
                live.recipe = nil
            }
        }
    }

    func confirmRun() async {
        guard hasRecipe else {
            errorText = hasAgent
                ? "动作需要 Codex。终端仍可发送给 \(tuiTitle)。"
                : "未发现 Codex。安装后再运行。"
            return
        }
        let batch = selectedItems.filter { $0.status == .confirm }
        guard let first = batch.first, let recipe = RecipeID.allCases.first(where: { $0.fullTitle == first.recipe }) else {
            return
        }
        do {
            _ = try await job.start(itemIDs: batch.map(\.id), recipe: recipe)
            aiTab = .result
        } catch AgentError.cancelled {
            aiTab = .work
        } catch {
            errorText = human(error)
            if selectedItems.contains(where: { $0.status == .failed }) {
                aiTab = .result
            }
        }
    }

    func cancelRun() {
        job.cancel()
    }

    func sendToTUI(itemIDs: [ItemID]? = nil) {
        guard canSendToTUI, let engine = presence.engine else {
            if hasAgent == false {
                errorText = "未发现终端 Agent。文件已留在架子上。"
            }
            return
        }
        let ids = itemIDs ?? selectedItems.map(\.id)
        do {
            let prepared = try tui.send(itemIDs: ids, text: promptText, sessionDirectory: tuiSessionDirectory)
            if ttyLines.isEmpty {
                ttyLines.append(TTYLine(kind: "sys", text: "\(engine.shortTitle)  ·  本机会话"))
            }
            for id in ids {
                if let item = shelf.item(id: id) {
                    ttyLines.append(TTYLine(kind: "file", text: "材料  \(item.title)"))
                }
            }
            let shown = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            ttyLines.append(TTYLine(kind: "in", text: shown.isEmpty ? "›  （没有附带说明）" : "›  \(shown)"))
            promptText = ""
            pendingTUI = prepared
            tuiSessionDirectory = prepared.cwd
            aiTab = .tty
        } catch {
            errorText = human(error)
        }
    }

    func copySelected() {
        guard let item = selectedItems.first, item.status != .running else { return }
        copyItem(item)
    }

    func copyItem(_ item: Item, to pasteboard: NSPasteboard = .general) {
        PasteboardService.copy(item, to: pasteboard)
        copiedID = item.id
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedID == item.id { copiedID = nil }
        }
    }

    func currentResult() -> Item? {
        selectedItems.first { $0.status == .done || $0.status == .failed }
            ?? selectedItems.first { $0.status == .sent }
            ?? selectedItems.first
    }

    func tuiProcessExited() {
        tuiProcessRunning = false
        ptyLive = false
        tuiSessionDirectory = nil
    }

    func failTUILaunch(itemIDs: [ItemID]) {
        tui.revertSend(itemIDs: itemIDs)
        errorText = "没能打开 \(tuiTitle) 终端。"
        pendingTUI = nil
        tuiProcessExited()
    }

    func pickTUIExecutable() {
        let panel = NSOpenPanel()
        panel.title = "选择终端 Agent 可执行文件"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent.lowercased()
            let engine: AgentEngine
            if name == "grok" || name == "agent" {
                engine = .grok
            } else if name == "claude" {
                engine = .claude
            } else if name == "gemini" {
                engine = .gemini
            } else {
                engine = .codex
            }
            if engine == .codex {
                settings.executableOverride = url.path
            }
            settings.tuiOverrides[engine.rawValue] = url.path
            settings.tuiEngine = TUIEnginePreference(rawValue: engine.rawValue) ?? .codex
            resetTUISession()
            saveSettings()
        }
    }

    func setTUIPreference(_ preference: TUIEnginePreference) {
        settings.tuiEngine = preference
        resetTUISession()
        saveSettings()
    }

    func resetTUISession() {
        tuiSessionDirectory = nil
        pendingTUI = nil
        tuiProcessRunning = false
        ptyLive = false
        ttyLines = []
        tuiEpoch = UUID()
        refreshPresence()
    }

    func openTUIInstall(_ engine: AgentEngine?) {
        let target = engine ?? presence.engine ?? installedEngines.first?.engine ?? .grok
        NSWorkspace.shared.open(target.installURL)
    }

    func persistChrome() {
        terminalOwnsListHeight = false
        listHeightBeforeTerminal = nil
        try? DropAgentPaths.ensure()
        let payload = ["listHeight": Double(listHeight)]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            try? data.write(to: DropAgentPaths.panelFile, options: .atomic)
        }
    }

    var displayListHeight: CGFloat {
        if terminalOwnsListHeight { return listHeight }
        if listHeightTouched { return listHeight }
        return fittedListHeight()
    }

    func fittedListHeight(cap: CGFloat = 320) -> CGFloat {
        if items.isEmpty { return min(cap, 140) }
        return min(cap, max(56, CGFloat(items.count) * 56))
    }

    func setListHeight(_ height: CGFloat) {
        listHeight = min(320, max(56, height))
        listHeightTouched = true
    }

    private static func storedChrome() -> (height: CGFloat, touched: Bool) {
        guard let data = try? Data(contentsOf: DropAgentPaths.panelFile),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let height = object["listHeight"] as? Double
        else { return (140, false) }
        return (min(320, max(56, height)), true)
    }

    var tuiCaption: String {
        if let file = ttyLines.last(where: { $0.kind == "file" }) {
            let name = file.text.replacingOccurrences(of: "材料  ", with: "")
            return "\(tuiTitle) · \(name)"
        }
        return ttyLines.last(where: { $0.kind == "sys" })?.text ?? "\(tuiTitle)  ·  本机会话"
    }

    private func giveTerminalRoom() {
        let target = fittedListHeight(cap: 108)
        guard displayListHeight > target + 0.5 else { return }
        if listHeightBeforeTerminal == nil {
            listHeightBeforeTerminal = listHeight
        }
        listHeight = target
        terminalOwnsListHeight = true
    }

    private func restoreListAfterTerminal() {
        guard terminalOwnsListHeight, let saved = listHeightBeforeTerminal else {
            listHeightBeforeTerminal = nil
            terminalOwnsListHeight = false
            return
        }
        listHeight = saved
        listHeightBeforeTerminal = nil
        terminalOwnsListHeight = false
    }

    private func note(_ result: AdmitResult) {
        if let failure = result.failures.first, result.admitted.isEmpty {
            errorText = human(failure.error)
        } else if !result.failures.isEmpty {
            errorText = "有 \(result.failures.count) 项没能加入"
        }
    }

    private func human(_ error: Error) -> String {
        switch error {
        case IngestError.emptyClipboard: return "剪贴板是空的"
        case IngestError.missingSource: return "找不到原文件"
        case IngestError.captureFailed: return PageAdmitCopy.needAccessibilityRetry
        case IngestError.symlinkRejected: return "不接收符号链接"
        case JobError.noAgent: return "动作需要 Codex"
        case TUIError.noAgent, AgentError.notFound: return "未发现终端 Agent"
        case TUIError.launchFailed: return "没能打开 \(tuiTitle) 终端。"
        case AgentError.cancelled: return ""
        case JobError.notStartable: return "这项现在不能跑这个动作"
        case JobError.emptySelection, TUIError.empty: return "先选文件，或写一句话再发送"
        default: return "没能完成这一步"
        }
    }
}
