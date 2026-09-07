import Combine
import DropAgentAgent
import DropAgentIngest
import DropAgentJob
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
    @Published var resultWidth: CGFloat = LivePanelChrome.resultDefault
    @Published var otherOpen = false
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
    var lastInternalDropAt: Date?
    @Published var hotKeyToggleOK = true
    @Published var hotKeyCaptureOK = true
    @Published var hotKeyFilesOK = true
    @Published var tuiEpoch = UUID()
    var lastCaptureToken: PageAdmitToken?
    var setupLoaded = false
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
        let chrome = Self.storedChrome()
        shelfWidth = chrome.shelf
        resultWidth = chrome.result
        spotlight.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
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

    func persistChrome() {
        try? DropAgentPaths.ensure()
        let payload = [
            "shelfWidth": Double(shelfWidth),
            "resultWidth": Double(resultWidth)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) {
            try? data.write(to: DropAgentPaths.panelFile, options: .atomic)
        }
    }

    func setShelfWidth(_ width: CGFloat) {
        shelfWidth = min(LivePanelChrome.shelfMax, max(LivePanelChrome.shelfMin, width))
        if prefs.showWork == false || prefs.showResult == false {
            applyLayout?()
        }
    }

    func setResultWidth(_ width: CGFloat) {
        resultWidth = min(LivePanelChrome.resultMax, max(LivePanelChrome.resultMin, width))
        if prefs.showWork == false || prefs.showResult == false {
            applyLayout?()
        }
    }

    var fillsShelf: Bool {
        settingsOpen == false && showsSetupCard == false && prefs.showWork == false && prefs.showResult == false
    }

    var panelWidth: CGFloat {
        if settingsOpen || showsSetupCard {
            return LivePanelChrome.panelWidth
        }
        return LivePanelChrome.fittedWidth(
            showWork: prefs.showWork,
            showResult: prefs.showResult,
            shelfWidth: shelfWidth,
            resultWidth: resultWidth
        )
    }

    var showsComposer: Bool {
        if settingsOpen || showsSetupCard { return false }
        return aiTab == .work && otherOpen
    }

    func choiceID(for recipe: RecipeID) -> String {
        RecipeCatalog.resolvedChoiceID(recipe, optionID: recipeOptions[recipe])
    }

    func setChoice(_ id: String, for recipe: RecipeID) {
        recipeOptions[recipe] = id
    }

    func toggleOther() {
        otherOpen.toggle()
        if otherOpen { aiTab = .work }
    }

    func setMultiSelect(_ on: Bool) {
        multiSelect = on
    }

    private static func storedChrome() -> (shelf: CGFloat, result: CGFloat) {
        guard let data = try? Data(contentsOf: DropAgentPaths.panelFile),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return (LivePanelChrome.shelfDefault, LivePanelChrome.resultDefault)
        }
        let shelf = (object["shelfWidth"] as? Double).map { CGFloat($0) } ?? LivePanelChrome.shelfDefault
        let result = (object["resultWidth"] as? Double).map { CGFloat($0) } ?? LivePanelChrome.resultDefault
        return (
            min(LivePanelChrome.shelfMax, max(LivePanelChrome.shelfMin, shelf)),
            min(LivePanelChrome.resultMax, max(LivePanelChrome.resultMin, result))
        )
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
        default: return Copy.t("没能完成这一步", "Could not finish this step")
        }
    }
}
