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
    let jobRunner: (any AgentRunning)?
    var applyChrome: (() -> Void)?
    var applyLayout: (() -> Void)?
    var onPanelInteraction: (() -> Void)?
    var onFinishExternalDrag: (() -> Void)?
    var onApplyHotKeys: (() -> Void)?
    let clipMenu = ClipHistoryWindow()
    let clipHistory: ClipHistoryStore
    @Published var clipHistoryOpen = false
    @Published var clipRecords: [ClipRecord] = []
    @Published var clipSelection: Set<ClipID> = []
    @Published var clipMultiSelect = false
    @Published var currentClipFingerprint: String?
    var clipDragging = false
    var clipWatchTask: Task<Void, Never>?
    var lastPasteboardChange = Int.min
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
    @Published var dockHeight: CGFloat = LivePanelChrome.dockMinHeight
    @Published var otherOpen = false
    @Published var actionBarEditing = false
    @Published var draggingActionID: String?
    @Published var shortcutDraft: ShortcutDraft?
    @Published var stageEditing = false
    @Published var recipeOptions: [RecipeID: String] = [:]
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
    @Published var settingsSection: SettingsSection = .setup
    @Published var offerPrivacySettings = false
    @Published var offerCaptureRetry = false
    @Published var setup = PageAdmitSetup.empty
    @Published var setupPermissionsOverride: PageAdmitSetup?
    @Published var suppressSetupCard = false
    @Published var authorizingID: String?
    @Published var tuiProcessRunning = false
    @Published var ptyLive = false
    @Published var isCapturing = false
    var isAdmittingFiles = false
    var retryFrontFiles = false
    var filesPrivacy: FilesPrivacy = .none
    var lastFrontBundle: String?
    var lastFrontPID: pid_t = 0
    var hasFrozenFront = false
    @Published var systemDragActive = false
    var shelfDragIDs: [ItemID] = []
    @Published var hotKeyToggleOK = true
    @Published var hotKeyCaptureOK = true
    @Published var hotKeyFilesOK = true
    @Published var tuiEpoch = UUID()
    @Published private var onboarded = false
    var lastCaptureToken: PageAdmitToken?
    var setupRefreshing = false
    @Published var authorizationSlow = false
    @Published var setupLoaded = false
    var setupWatchCount = 0
    var setupWatchTask: Task<Void, Never>?

    enum FilesPrivacy {
        case none
        case accessibility
        case finder
    }

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
        clipHistory = ClipHistoryStore(directory: DropAgentPaths.clipboard)
        ingest = IngestService(shelf: shelf, inboxRoot: DropAgentPaths.inbox)
        agent = AgentService(runner: CodexCLI(), settings: loaded)
        job = JobService(shelf: shelf, agent: jobRunner ?? agent, jobsRoot: DropAgentPaths.jobs)
        tui = TUIService(shelf: shelf, agent: agent, inboxRoot: DropAgentPaths.tuiInbox)
        Palette.isDark = prefs.appearance.resolvedIsDark
        let args = ProcessInfo.processInfo.arguments
        suppressSetupCard = args.contains("--e2e") || args.contains("--preview") || args.contains("--capture")
        onboarded = FileManager.default.fileExists(atPath: DropAgentPaths.onboardedFile.path)
        shelf.load()
        refreshPresence()
        refresh()
        refreshSetup()
        shelf.onChange = { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        clipHistory.onChange = { [weak self] in
            Task { @MainActor in
                self?.refreshClips()
            }
        }
        refreshClips()
        if suppressSetupCard == false {
            startClipWatch()
        }
        spotlight.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func refresh() {
        refreshClips()
        items = shelf.items()
        if items.isEmpty == false { markOnboarded() }
        results = shelf.results()
        if items.isEmpty { multiSelect = false }
        if let id = selectedResultID, shelf.result(id: id) == nil {
            selectedResultID = nil
            if paneFocus == .result { paneFocus = .input }
        }
    }

    var showsOnboarding: Bool {
        Onboarding.shouldShow(markerExists: onboarded, isEmpty: items.isEmpty && results.isEmpty)
    }

    func dismissOnboarding() { markOnboarded() }

    func tryOnboardingSample() {
        do {
            let folder = DropAgentPaths.root.appendingPathComponent("Samples/\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(Onboarding.sampleFileName)
            try Data(Onboarding.sampleMarkdown.utf8).write(to: url, options: .atomic)
            let result = ingest.admit(urls: [url])
            follow(result)
            if let item = result.admitted.first {
                shelf.setSelection([item.id])
                aiTab = .work
                paneFocus = .input
            }
        } catch {
            errorText = Copy.t("没能加入示例文稿，请重试或添加自己的文件。", "Could not add the sample. Try again or add your own file.")
        }
    }

    private func markOnboarded() {
        guard onboarded == false else { return }
        onboarded = true
        try? DropAgentPaths.ensure()
        try? Data("1".utf8).write(to: DropAgentPaths.onboardedFile, options: .atomic)
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

    var panelWidth: CGFloat {
        LivePanelChrome.panelWidth
    }

    var panelHeight: CGFloat {
        if settingsOpen || showsSetupCard {
            return LivePanelChrome.panelHeight + LivePanelChrome.dockShadowPad * 2
        }
        return min(
            max(dockHeight, LivePanelChrome.dockMinHeight + LivePanelChrome.dockShadowPad * 2),
            LivePanelChrome.panelHeight + LivePanelChrome.floatMaxHeight + LivePanelChrome.dockGap + LivePanelChrome.dockShadowPad * 2
        )
    }

    var showsComposer: Bool {
        showsFloat
    }

    var showsFloat: Bool {
        if settingsOpen || showsSetupCard { return false }
        return otherOpen
    }

    var showsResultStrip: Bool {
        results.isEmpty == false && settingsOpen == false && showsSetupCard == false
    }

    var showsActionBar: Bool {
        selectedItems.isEmpty == false && settingsOpen == false && showsSetupCard == false
    }

    var stagedItem: Item? {
        if paneFocus == .result, let record = selectedResult {
            return record.takeawayItem()
        }
        return selectedItems.first
    }

    func choiceID(for recipe: RecipeID) -> String {
        RecipeCatalog.resolvedChoiceID(recipe, optionID: recipeOptions[recipe])
    }

    func setChoice(_ id: String, for recipe: RecipeID) {
        onPanelInteraction?()
        recipeOptions[recipe] = id
    }

    func toggleOther() {
        onPanelInteraction?()
        withAnimation(Palette.floatExpand) {
            otherOpen.toggle()
            if otherOpen { aiTab = canOpenTerminalTab ? .tty : .work }
        }
    }

    func flushStageEdit() {
        StageEdit.flush()
    }

    func beginStageEdit() {
        guard let item = stagedItem else { return }
        guard StageEdit.editableURL(item, inboxRoot: DropAgentPaths.inbox, jobsRoot: DropAgentPaths.jobs) != nil else { return }
        stageEditing = true
    }

    func stopStageEdit() {
        StageEdit.flush()
        if stageEditing { stageEditing = false }
    }

    func setDockHeight(_ height: CGFloat) {
        if settingsOpen || showsSetupCard { return }
        let rounded = height.rounded()
        guard rounded >= LivePanelChrome.dockMinHeight else { return }
        guard abs(dockHeight - rounded) > 1 else { return }
        dockHeight = rounded
        applyLayout?()
    }

    func setMultiSelect(_ on: Bool) {
        multiSelect = on
    }

    func human(_ error: Error) -> String {
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
        case PDFTextError.unreadable: return Copy.t("打不开这份 PDF", "This PDF cannot be opened")
        case PDFTextError.locked: return Copy.t("这份 PDF 有密码，抽不出文字", "This PDF is password-protected")
        default: return Copy.t("没能完成这一步", "Could not finish this step")
        }
    }
}
