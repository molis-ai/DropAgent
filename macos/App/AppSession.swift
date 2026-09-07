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

enum PaneFocus: String {
    case input
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
    var ingest: IngestService
    var job: JobService
    let tui: TUIService
    let agent: AgentService
    let spotlight = SpotlightSearch()
    private let jobRunner: (any AgentRunning)?
    var applyChrome: (() -> Void)?
    var onFinishExternalDrag: (() -> Void)?
    var onApplyHotKeys: (() -> Void)?
    @Published var recordingHotKey: HotKeySlot?
    private var cancellables = Set<AnyCancellable>()

    @Published var items: [Item] = []
    @Published var results: [ResultRecord] = []
    @Published var selectedResultID: ResultID?
    @Published var paneFocus: PaneFocus = .input
    @Published var presence: AgentPresence = .none
    @Published var recipePresence: AgentPresence = .none
    @Published var installedEngines: [AgentPresence] = []
    @Published var aiTab: AITab = .work
    @Published var shelfWidth: CGFloat = LivePanelChrome.shelfDefault
    @Published var multiSelect = false
    @Published var promptText: String = ""
    @Published var copiedID: ItemID?
    @Published var ttyLines: [TTYLine] = []
    @Published var errorText: String?
    @Published var pendingTUI: PreparedTUISend?
    @Published var tuiSessionDirectory: URL?
    @Published var settings = AgentSettings()
    @Published var prefs = AppPreferences.default
    @Published var settingsOpen = false
    @Published var offerPrivacySettings = false
    @Published var offerCaptureRetry = false
    @Published var setup = PageAdmitSetup.empty
    @Published var setupPermissionsOverride: PageAdmitSetup?
    @Published var suppressSetupCard = false
    @Published var authorizingID: String?
    @Published var tuiProcessRunning = false
    @Published var ptyLive = false
    @Published var isCapturing = false
    private var isAdmittingFiles = false
    private var retryFrontFiles = false
    private var filesPrivacy: FilesPrivacy = .none
    private var lastFrontBundle: String?
    private var lastFrontPID: pid_t = 0
    private var hasFrozenFront = false
    @Published var systemDragActive = false
    @Published var hotKeyToggleOK = true
    @Published var hotKeyCaptureOK = true
    @Published var hotKeyFilesOK = true
    @Published var tuiEpoch = UUID()
    private var lastCaptureToken: PageAdmitToken?
    private var setupLoaded = false
    private var setupWatchCount = 0
    private var setupWatchTask: Task<Void, Never>?

    static let captureFailedCopy = PageAdmitCopy.needAccessibility

    init(jobRunner: (any AgentRunning)? = nil) {
        self.jobRunner = jobRunner
        let loadedPrefs = AppPreferences.load()
        prefs = loadedPrefs
        DropAgentPaths.inboxOverride = loadedPrefs.inboxURL
        DropAgentPaths.jobsOverride = loadedPrefs.jobsURL
        Copy.language = loadedPrefs.language
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
        Palette.isDark = prefs.appearance.resolvedIsDark
        let args = ProcessInfo.processInfo.arguments
        suppressSetupCard = args.contains("--e2e") || args.contains("--preview") || args.contains("--capture")
        shelf.load()
        refreshPresence()
        refresh()
        refreshSetup()
        shelf.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        shelfWidth = Self.storedShelfWidth()
        spotlight.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var selectedItems: [Item] { shelf.selectedItems() }
    var hasAgent: Bool { presence.executable != nil }
    var canSendToTUI: Bool {
        guard hasAgent, isCapturing == false else { return false }
        if selectedItems.contains(where: { $0.status == .running || $0.status == .confirm }) {
            return false
        }
        if paneFocus == .result {
            return selectedResult?.output != nil
        }
        return true
    }
    var composerPlaceholder: String {
        if hasAgent == false { return Copy.t("未发现终端 Agent", "No terminal agent found") }
        if isCapturing { return Copy.t("正在抓当前页", "Capturing the current page") }
        if selectedItems.contains(where: { $0.status == .running }) {
            return Copy.t("等任务结束，或点取消", "Wait for the job to finish, or cancel")
        }
        if selectedItems.contains(where: { $0.status == .confirm }) {
            return Copy.t("先运行或取消这次动作", "Run or cancel this action first")
        }
        return Copy.t("写给 \(tuiTitle)，回车发送", "Write to \(tuiTitle), press Return to send")
    }
    var hasRecipe: Bool {
        let key = presence.runtimeKey
        return key.isEmpty == false && key == recipePresence.runtimeKey
    }
    var tuiTitle: String { presence.shortTitle }
    var showsSetupCard: Bool {
        SetupCardPolicy.shouldShowCard(
            dismissed: prefs.setupCardDismissed,
            captureReady: SetupCardPolicy.captureReady(setup),
            isDiagnostic: suppressSetupCard,
            panelVisible: true
        )
    }
    var gearNeedsAttention: Bool {
        SetupCardPolicy.gearNeedsAttention(hasAgent: hasAgent, setup: setup)
    }
    var recipeActorLine: String {
        HotKeyCopy.recipeActorLine(hasRecipe: hasRecipe, hasAgent: hasAgent, tuiTitle: tuiTitle)
    }
    var recipeIsolationFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        return agent.isolationCopy(for: recipePresence)
    }
    var recipeWriteFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        if recipePresence.isolation == .workspace { return Copy.t("仅任务目录", "Job folder only") }
        return Copy.t("未确认仅任务目录", "Job-folder limit unconfirmed")
    }
    var recipeNetworkFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        if recipePresence.isolation != .workspace { return Copy.t("未确认", "Unconfirmed") }
        let wants = confirmRecipeID.map { RecipeCatalog.spec($0).needsNetwork } ?? false
        return wants ? Copy.t("开", "On") : Copy.t("关", "Off")
    }
    var confirmRecipeID: RecipeID? {
        let title = selectedItems.first(where: { $0.status == .confirm })?.recipe
            ?? selectedItems.first?.recipe
        return RecipeID.allCases.first { $0.fullTitle == title }
    }
    var shortcutFooter: String {
        let keys = HotKeyCopy.hotkeyLine(hasAgent: hasAgent, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK, filesOK: hotKeyFilesOK)
        if isCapturing {
            return "正在抓当前页，完成前先不发送。\n" + keys
        }
        if selectedItems.contains(where: { $0.status == .confirm || $0.status == .running }) {
            return keys
        }
        return HotKeyCopy.footer(hasAgent: hasAgent, tuiTitle: tuiTitle, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK, filesOK: hotKeyFilesOK)
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
        if hasRecipe == false {
            return hasAgent ? HotKeyCopy.missingJobLine(tuiTitle: tuiTitle) : "未发现终端 Agent"
        }
        if recipeFitsSelection(recipe) { return Copy.recipeFull(recipe) }
        if recipeBatch.count < recipe.minimumCount {
            return Copy.t(
                "「\(Copy.recipeShort(recipe))」至少要两份材料",
                "“\(Copy.recipeShort(recipe))” needs at least two items"
            )
        }
        return Copy.t(
            "选中的材料不能用「\(Copy.recipeShort(recipe))」",
            "The selected items cannot use “\(Copy.recipeShort(recipe))”"
        )
    }

    var recipeChooserHint: String {
        if hasAgent == false {
            return "安装终端 Agent 后可发送。现在只能暂存，或点右上角选择已装的 TUI。"
        }
        if hasRecipe == false {
            return "\(tuiTitle) 没有无界面执行入口，动作不能跑。下面可以发给 \(tuiTitle)。"
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

    var selectedResult: ResultRecord? {
        guard let id = selectedResultID else { return nil }
        return results.first { $0.id == id } ?? shelf.result(id: id)
    }

    func refresh() {
        items = shelf.items()
        results = shelf.results()
        if items.isEmpty { multiSelect = false }
        if let id = selectedResultID, shelf.result(id: id) == nil {
            selectedResultID = nil
            if paneFocus == .result { paneFocus = .input }
        }
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

    func finishExternalDrag() {
        systemDragActive = false
        onFinishExternalDrag?()
    }

    func admit(urls: [URL]) {
        follow(ingest.admit(urls: urls))
        aiTab = .work
        finishExternalDrag()
    }

    func pickFilesToAdmit() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = Copy.t("加入", "Add")
        panel.message = Copy.t("选择要放到架子上的文件或文件夹。原件不动。", "Choose files or folders to put on the shelf. Originals stay put.")
        let urls = OpenPanelHost.run(panel)
        guard urls.isEmpty == false else { return }
        admit(urls: urls)
    }

    func admitSpotlight(_ hit: SpotlightHit) {
        admit(urls: [hit.url])
    }

    func admitDrop(providers: [NSItemProvider]) {
        finishExternalDrag()
        Task {
            follow(await ingest.admitProviders(providers))
            aiTab = .work
        }
    }

    func admitPasteboard(_ pasteboard: NSPasteboard) {
        admitPayload(ClipboardPayload.from(pasteboard: pasteboard))
    }

    func admitPayload(_ payload: ClipboardPayload) {
        follow(ingest.admitPayload(payload))
        aiTab = .work
        finishExternalDrag()
    }

    func admitToTUI(providers: [NSItemProvider]) {
        finishExternalDrag()
        Task {
            let result = await ingest.admitProviders(providers, capturePages: false)
            follow(result)
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
        let result = ingest.admit(urls: urls, capturePages: false)
        follow(result)
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
        let payload = clipboard.read()
        if case .empty = payload {
            errorText = human(IngestError.emptyClipboard)
            return
        }
        let result = ingest.admitPayload(payload)
        if result.admitted.isEmpty {
            errorText = human(result.failures.first?.error ?? IngestError.unsupported)
            return
        }
        follow(result)
        aiTab = .work
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
            let key = prefs.captureHotKey.label
            return Copy.t(
                "没读到当前页。把 Safari、Chrome 或 Edge 放到最前面，再按 \(key)。",
                "No current page. Bring Safari, Chrome, or Edge to the front, then press \(key)."
            )
        }
        return message
    }

    func retryCapture() {
        guard isCapturing == false, isAdmittingFiles == false else { return }
        if retryFrontFiles {
            Task { await admitFrontSelection() }
        } else {
            Task { await captureCurrentPage() }
        }
    }

    func dismissError() {
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        retryFrontFiles = false
        filesPrivacy = .none
    }

    func prepareFrontFiles() {
        let front = NSWorkspace.shared.frontmostApplication
        lastFrontBundle = front?.bundleIdentifier
        lastFrontPID = front?.processIdentifier ?? 0
        hasFrozenFront = true
    }

    func admitFrontSelection() async {
        guard isCapturing == false, isAdmittingFiles == false else { return }
        isAdmittingFiles = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        retryFrontFiles = true
        filesPrivacy = .none
        aiTab = .work
        if hasFrozenFront == false {
            prepareFrontFiles()
        }
        hasFrozenFront = false
        let bundle = lastFrontBundle
        let pid = lastFrontPID
        let kind = FrontAdmit.classify(bundleID: bundle)
        var ax = PageAdmit.isTrusted()
        var finderOK = FrontAdmit.finderAllowed()
        if case .failure(let fail) = FrontAdmit.decide(kind: kind, axTrusted: ax, finderAllowed: finderOK) {
            if fail == .needAccessibility {
                PageAdmit.requestTrustIfNeeded()
                ax = PageAdmit.isTrusted()
            }
            if fail == .needFinderAutomation {
                _ = PageAdmit.requestAutomation(bundleIdentifier: FrontAdmit.finderBundleID)
                finderOK = FrontAdmit.finderAllowed()
            }
        }
        if case .failure(let fail) = FrontAdmit.decide(kind: kind, axTrusted: ax, finderAllowed: finderOK) {
            presentFilesFailure(fail)
            isAdmittingFiles = false
            return
        }
        switch await FrontAdmit.collect(frontBundleID: bundle, frontPID: pid) {
        case .success(let read):
            let result = ingest.admit(urls: read.urls)
            follow(result)
            if result.admitted.isEmpty == false {
                shelf.setSelection(Set(result.admitted.map(\.id)))
                errorText = nil
                offerPrivacySettings = false
                offerCaptureRetry = false
                retryFrontFiles = false
                filesPrivacy = .none
            } else if errorText == nil {
                presentFilesFailure(.empty)
            }
            aiTab = .work
        case .failure(let fail):
            presentFilesFailure(fail)
        }
        isAdmittingFiles = false
    }

    private enum FilesPrivacy {
        case none
        case accessibility
        case finder
    }

    private func presentFilesFailure(_ fail: FrontAdmitError) {
        offerCaptureRetry = true
        retryFrontFiles = true
        switch fail {
        case .selfApp:
            errorText = Copy.t("到 Finder 或编辑器里选中文件再按。", "Select files in Finder or an editor, then press the shortcut.")
            offerPrivacySettings = false
            filesPrivacy = .none
        case .browser:
            let key = prefs.captureHotKey.label
            errorText = Copy.t(
                "这不是文件。网页请用 \(key)。",
                "That is not a file. Capture a page with \(key)."
            )
            offerPrivacySettings = false
            filesPrivacy = .none
        case .needAccessibility:
            errorText = Copy.t("加入选中文件需要辅助功能。", "Adding selected files needs Accessibility.")
            offerPrivacySettings = true
            filesPrivacy = .accessibility
        case .needFinderAutomation:
            errorText = Copy.t(
                "加入 Finder 里选中的文件需要允许控制 Finder。",
                "Adding Finder selection needs control of Finder."
            )
            offerPrivacySettings = true
            filesPrivacy = .finder
        case .emptyFinder:
            errorText = Copy.t("请先在 Finder 里选中文件。", "Select files in Finder first.")
            offerPrivacySettings = false
            filesPrivacy = .none
        case .empty:
            errorText = Copy.t(
                "没读到选中的文件。可在 Finder 里选，或打开一个本地文件。",
                "No selected files. Select in Finder, or open a local file."
            )
            offerPrivacySettings = PageAdmit.isTrusted() == false
            filesPrivacy = offerPrivacySettings ? .accessibility : .none
        }
    }

    func openPrivacySettings() {
        Task { await authorizeCaptureFailure() }
    }

    func refreshSetup() {
        let showing = setupLoaded && showsSetupCard
        setup = setupPermissionsOverride ?? PageAdmit.setupStatus()
        setupLoaded = true
        if showing && SetupCardPolicy.captureReady(setup) {
            dismissSetupCard()
        }
    }

    func dismissSetupCard() {
        guard prefs.setupCardDismissed == false else { return }
        prefs.setupCardDismissed = true
        prefs.save()
    }

    func beginSetupWatch() {
        setupWatchCount += 1
        guard setupWatchTask == nil else { return }
        setupWatchTask = Task { @MainActor in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if authorizingID == nil {
                    refreshSetup()
                }
            }
        }
    }

    func endSetupWatch() {
        setupWatchCount = max(0, setupWatchCount - 1)
        guard setupWatchCount == 0 else { return }
        setupWatchTask?.cancel()
        setupWatchTask = nil
    }

    func openAutomationSettings() {
        openSystemPane(Self.automationPanes)
    }

    func authorizeAccessibility() {
        Task { await authorizeAccessibilityNow() }
    }

    func authorizeBrowser(_ row: PageAdmitBrowserRow) {
        Task { await authorizeBrowserRow(row, openSettingsIfDenied: true) }
    }

    private func authorizeAccessibilityNow() async {
        authorizingID = "ax"
        StatusChrome.hideForPrompt()
        PageAdmit.requestTrustIfNeeded()
        openSystemPane(Self.accessibilityPanes)
        StatusChrome.finishPromptKeepHidden()
        authorizingID = nil
        refreshSetup()
    }

    private func authorizeCaptureFailure() async {
        if retryFrontFiles {
            switch filesPrivacy {
            case .finder:
                await authorizeBrowserRow(setup.finder, openSettingsIfDenied: true)
            case .accessibility, .none:
                await authorizeAccessibilityNow()
            }
            return
        }
        if PageAdmit.isTrusted() == false {
            await authorizeAccessibilityNow()
            return
        }
        let token = lastCaptureToken ?? .snapshot()
        if let target = PageAdmit.privacyTarget(token: token) {
            await authorizeBrowserRow(target, openSettingsIfDenied: true)
            return
        }
    }

    private func authorizeBrowserRow(_ row: PageAdmitBrowserRow, openSettingsIfDenied: Bool) async {
        authorizingID = row.bundleIdentifier
        var bundle = row.bundleIdentifier
        var running = row.running
        if running == false {
            running = await openBrowser(bundleIdentifier: bundle)
            refreshSetup()
            if row.bundleIdentifier == FrontAdmit.finderBundleID {
                bundle = setup.finder.bundleIdentifier
                running = setup.finder.running
            } else if let updated = setup.browsers.first(where: { $0.displayName == row.displayName }) {
                bundle = updated.bundleIdentifier
                running = updated.running
            }
            if running == false {
                authorizingID = nil
                return
            }
        }
        StatusChrome.hideForPrompt()
        let state = PageAdmit.requestAutomation(bundleIdentifier: bundle)
        authorizingID = nil
        refreshSetup()
        if openSettingsIfDenied && state == .denied {
            StatusChrome.finishPromptKeepHidden()
            openSystemPane(Self.automationPanes)
            return
        }
        StatusChrome.restore()
    }

    private func openBrowser(bundleIdentifier: String) async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
        } catch {
            return false
        }
        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            if isBrowserRunning(bundleIdentifier) { return true }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return isBrowserRunning(bundleIdentifier)
    }

    private func isBrowserRunning(_ bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier?.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
        }
    }

    private func openSystemPane(_ panes: [String]) {
        for pane in panes {
            if let url = URL(string: pane), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private static let accessibilityPanes = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
    ]

    private static let automationPanes = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
    ]

    func toggleSelect(id: ItemID, command: Bool) {
        paneFocus = .input
        shelf.toggleSelect(id: id, command: command)
        if command { return }
        if let item = shelf.item(id: id) {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = .tty }
            else { aiTab = .work }
        }
    }

    func selectResult(_ id: ResultID) {
        selectedResultID = id
        paneFocus = .result
        aiTab = .result
    }

    func removeResult(_ id: ResultID) {
        shelf.removeResults(ids: [id])
        if selectedResultID == id {
            selectedResultID = nil
            paneFocus = .input
        }
        refresh()
    }

    func remove(id: ItemID) {
        try? shelf.remove(ids: [id])
        refresh()
    }

    func removeSelected() {
        if paneFocus == .result, let id = selectedResultID {
            removeResult(id)
            return
        }
        let ids = selectedItems.filter { $0.status != .running }.map(\.id)
        guard !ids.isEmpty else { return }
        try? shelf.remove(ids: ids)
        refresh()
    }

    func moveSelection(offset: Int) {
        paneFocus = .input
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
        refresh()
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
                ? "\(tuiTitle) 没有无界面执行入口。终端仍可发送给 \(tuiTitle)。"
                : "未发现终端 Agent。"
            return
        }
        let batch = selectedItems.filter { $0.status == .confirm }
        guard let first = batch.first, let recipe = RecipeID.allCases.first(where: { $0.fullTitle == first.recipe }) else {
            return
        }
        do {
            _ = try await job.start(itemIDs: batch.map(\.id), recipe: recipe)
            adoptNewestResult()
            aiTab = .result
        } catch AgentError.cancelled {
            aiTab = .work
        } catch {
            errorText = human(error)
            if shelf.results().isEmpty == false {
                adoptNewestResult()
                aiTab = .result
            }
        }
    }

    func cancelRun() {
        job.cancel()
    }

    func sendToTUI(itemIDs: [ItemID]? = nil) {
        guard canSendToTUI, presence.executable != nil else {
            if hasAgent == false {
                errorText = "未发现终端 Agent。文件已留在架子上。"
            }
            return
        }
        if paneFocus == .result, let record = selectedResult, let file = record.output {
            sendResultToTUI(record, file: file)
            return
        }
        let ids = itemIDs ?? selectedItems.map(\.id)
        do {
            let prepared = try tui.send(itemIDs: ids, text: promptText, sessionDirectory: tuiSessionDirectory)
            if ttyLines.isEmpty {
                ttyLines.append(TTYLine(kind: "sys", text: "\(presence.shortTitle)  ·  本机会话"))
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

    private func sendResultToTUI(_ record: ResultRecord, file: URL) {
        do {
            let prepared = try tui.send(
                itemIDs: [],
                text: promptText,
                sessionDirectory: tuiSessionDirectory,
                extraFiles: [file]
            )
            if ttyLines.isEmpty {
                ttyLines.append(TTYLine(kind: "sys", text: "\(presence.shortTitle)  ·  本机会话"))
            }
            ttyLines.append(TTYLine(kind: "file", text: "结果  \(record.title)"))
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
        if paneFocus == .result, let record = selectedResult {
            copyItem(record.takeawayItem())
            return
        }
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
        if paneFocus == .result, let record = selectedResult {
            return record.takeawayItem()
        }
        return selectedItems.first { $0.status == .done || $0.status == .failed }
            ?? selectedItems.first { $0.status == .sent }
            ?? selectedItems.first
    }

    private func adoptNewestResult() {
        refresh()
        guard let newest = results.first else { return }
        selectedResultID = newest.id
        paneFocus = .result
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
        panel.title = Copy.t("选择终端 Agent 可执行文件", "Choose a terminal agent executable")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let url = OpenPanelHost.run(panel).first {
            adoptExecutable(url)
        }
    }

    func adoptExecutable(_ url: URL) {
        let help = HeadlessCLI.readHelp(at: url)
        if let engine = AgentEngine.identified(
            binaryName: url.lastPathComponent,
            help: help,
            path: url.path
        ) {
            if engine == .codex {
                settings.executableOverride = url.path
            }
            settings.tuiOverrides[engine.rawValue] = url.path
            settings.tuiEngine = TUIEnginePreference(rawValue: engine.rawValue) ?? .auto
            settings.selectedCustomID = nil
        } else {
            let custom = CustomRuntime(
                title: url.deletingPathExtension().lastPathComponent,
                executable: url.path,
                kind: AgentEngine.detectedKind(binaryName: url.lastPathComponent, help: help)
            )
            settings.customRuntimes.append(custom)
            settings.selectedCustomID = custom.id
        }
        resetTUISession()
        saveSettings()
    }

    func setTUIPreference(_ preference: TUIEnginePreference) {
        settings.tuiEngine = preference
        settings.selectedCustomID = nil
        resetTUISession()
        saveSettings()
    }

    func setCustomRuntime(_ id: String) {
        settings.selectedCustomID = id
        resetTUISession()
        saveSettings()
    }

    func removeCustomRuntime(_ id: String) {
        settings.customRuntimes.removeAll { $0.id == id }
        if settings.selectedCustomID == id {
            settings.selectedCustomID = nil
            settings.tuiEngine = .auto
        }
        resetTUISession()
        saveSettings()
    }

    func setCustomRuntimeKind(_ id: String, kind: RuntimeKind) {
        guard let index = settings.customRuntimes.firstIndex(where: { $0.id == id }) else { return }
        settings.customRuntimes[index].kind = kind
        resetTUISession()
        saveSettings()
    }

    enum WorkspaceFolder {
        case inbox
        case jobs
    }

    func setAppearance(_ value: AppearancePreference) {
        Palette.isDark = value.resolvedIsDark
        prefs.appearance = value
        prefs.save()
        applyChrome?()
    }

    func setLanguage(_ value: AppLanguage) {
        Copy.language = value
        prefs.language = value
        prefs.save()
    }

    func chord(for slot: HotKeySlot) -> HotKeyChord {
        switch slot {
        case .toggle: return prefs.toggleHotKey
        case .capture: return prefs.captureHotKey
        case .files: return prefs.filesHotKey
        case .hide: return prefs.hideHotKey
        case .paste: return prefs.pasteHotKey
        case .copy: return prefs.copyHotKey
        case .delete: return prefs.deleteHotKey
        }
    }

    func beginRecording(_ slot: HotKeySlot) {
        recordingHotKey = slot
    }

    func cancelRecording() {
        recordingHotKey = nil
    }

    func applyRecordedHotKey(from event: NSEvent) {
        guard let slot = recordingHotKey, let chord = HotKeyChord.from(event: event) else { return }
        if slot.isGlobal, chord.hasModifier == false { return }
        setHotKey(slot, chord)
        recordingHotKey = nil
    }

    func resetHotKey(_ slot: HotKeySlot) {
        setHotKey(slot, slot.defaultChord)
    }

    func setHotKey(_ slot: HotKeySlot, _ chord: HotKeyChord) {
        if slot.isGlobal, chord.hasModifier == false { return }
        switch slot {
        case .toggle: prefs.toggleHotKey = chord
        case .capture: prefs.captureHotKey = chord
        case .files: prefs.filesHotKey = chord
        case .hide: prefs.hideHotKey = chord
        case .paste: prefs.pasteHotKey = chord
        case .copy: prefs.copyHotKey = chord
        case .delete: prefs.deleteHotKey = chord
        }
        prefs.save()
        onApplyHotKeys?()
    }

    func pickWorkspaceFolder(_ kind: WorkspaceFolder) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = Copy.t("选择", "Choose")
        panel.message = kind == .inbox
            ? Copy.t("选择存放文件副本的文件夹。", "Choose the folder for staged file copies.")
            : Copy.t("选择存放输出结果的文件夹。", "Choose the folder for recipe results.")
        guard let url = OpenPanelHost.run(panel).first else { return }
        setWorkspaceFolder(kind, url: url)
    }

    func setWorkspaceFolder(_ kind: WorkspaceFolder, url: URL?) {
        if let url {
            do {
                try Self.prepareWorkspaceDirectory(url)
            } catch {
                errorText = Copy.t("这个文件夹不能用。", "That folder cannot be used.")
                return
            }
        }
        switch kind {
        case .inbox:
            prefs.inboxPath = url?.path
            DropAgentPaths.inboxOverride = url
        case .jobs:
            prefs.jobsPath = url?.path
            DropAgentPaths.jobsOverride = url
        }
        try? DropAgentPaths.ensure()
        ingest = IngestService(shelf: shelf, inboxRoot: DropAgentPaths.inbox)
        job = JobService(shelf: shelf, agent: jobRunner ?? agent, jobsRoot: DropAgentPaths.jobs)
        prefs.save()
    }

    private static func prepareWorkspaceDirectory(_ url: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true { throw IngestError.symlinkRejected }
            if isDir.boolValue == false { throw IngestError.unsupported }
        } else {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        if fm.isWritableFile(atPath: url.path) == false {
            throw IngestError.unsupported
        }
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
        try? DropAgentPaths.ensure()
        let payload = ["shelfWidth": Double(shelfWidth)]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            try? data.write(to: DropAgentPaths.panelFile, options: .atomic)
        }
    }

    func setShelfWidth(_ width: CGFloat) {
        shelfWidth = min(LivePanelChrome.shelfMax, max(LivePanelChrome.shelfMin, width))
    }

    func setMultiSelect(_ on: Bool) {
        multiSelect = on
    }

    private static func storedShelfWidth() -> CGFloat {
        guard let data = try? Data(contentsOf: DropAgentPaths.panelFile),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let width = object["shelfWidth"] as? Double
        else { return LivePanelChrome.shelfDefault }
        return min(LivePanelChrome.shelfMax, max(LivePanelChrome.shelfMin, width))
    }

    var tuiCaption: String {
        if let file = ttyLines.last(where: { $0.kind == "file" }) {
            let name = file.text.replacingOccurrences(of: "材料  ", with: "")
            return "\(tuiTitle) · \(name)"
        }
        return ttyLines.last(where: { $0.kind == "sys" })?.text ?? "\(tuiTitle)  ·  本机会话"
    }

    private func follow(_ result: AdmitResult) {
        note(result)
        refresh()
        followPageCaptures(result)
    }

    private func followPageCaptures(_ result: AdmitResult) {
        let ids = result.pageCaptureIDs
        guard ids.isEmpty == false else { return }
        Task {
            await ingest.captureDroppedPages(ids: ids)
            refresh()
        }
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
        case IngestError.emptyClipboard: return Copy.t("剪贴板是空的", "Clipboard is empty")
        case IngestError.missingSource: return Copy.t("找不到原文件", "Original file is missing")
        case IngestError.captureFailed: return PageAdmitCopy.needAccessibilityRetry
        case IngestError.symlinkRejected: return Copy.t("不接收符号链接", "Symbolic links are not accepted")
        case JobError.noAgent:
            return hasAgent
                ? HotKeyCopy.missingJobLine(tuiTitle: tuiTitle)
                : Copy.t("未发现终端 Agent", "No terminal agent found")
        case TUIError.noAgent, AgentError.notFound: return Copy.t("未发现终端 Agent", "No terminal agent found")
        case TUIError.launchFailed: return Copy.t("没能打开 \(tuiTitle) 终端。", "Could not open the \(tuiTitle) terminal.")
        case AgentError.cancelled: return ""
        case JobError.notStartable: return Copy.t("这项现在不能跑这个动作", "This item cannot run that action now")
        case JobError.emptySelection, TUIError.empty: return Copy.t("先选文件，或写一句话再发送", "Select a file, or write something and send")
        default: return Copy.t("没能完成这一步", "Could not finish this step")
        }
    }
}
