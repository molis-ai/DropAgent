import AppKit
import DropAgentAgent
import DropAgentIngest
import DropAgentJob
import Foundation

extension AppSession {
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
        objectWillChange.send()
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
}
