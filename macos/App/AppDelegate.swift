import AppKit
import Carbon
import SwiftTerm
import SwiftUI

private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func take() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if done { return false }
        done = true
        return true
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = AppSession()
    var statusItem: NSStatusItem?
    var panel: DropAgentPanel?
    var hosting: PaperHostView<PanelRootView>?
    private var edgeDrop: EdgeDropController?
    private var dragMonitor: Any?
    private var localDragMonitor: Any?
    private var localMonitor: Any?
    private var appearanceObserver: NSObjectProtocol?
    private var localeObserver: NSObjectProtocol?

    func application(_ application: NSApplication, open urls: [URL]) {
        session.admit(urls: urls)
        showPanel()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        let edge = EdgeDropController(
            session: session,
            panelVisible: { [weak self] in self?.panel?.isVisible == true },
            panelFrame: { [weak self] in self?.panel?.frame },
            onDragOverPanel: { [weak self] in self?.wakePanel(makeKey: false) },
            onDragAwayFromPanel: { [weak self] in self?.recessAfterDragLeft() }
        )
        edge.setup()
        edgeDrop = edge
        session.onApplyHotKeys = { [weak self] in self?.reregisterHotKeys() }
        reregisterHotKeys()
        session.applyChrome = { [weak self] in self?.applyPanelAppearance() }
        session.applyLayout = { [weak self] in self?.positionPanel() }
        session.onPanelInteraction = { [weak self] in
            self?.session.flushStageEdit()
            self?.wakePanel(makeKey: true)
        }
        session.onFinishExternalDrag = { [weak self] in
            self?.edgeDrop?.hide()
            self?.scheduleRecess()
        }
        applyPanelAppearance()
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.session.prefs.appearance == .system else { return }
                Palette.isDark = AppearancePreference.system.resolvedIsDark
                self.session.objectWillChange.send()
                self.applyPanelAppearance()
            }
        }
        localeObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleLanguagePreferencesChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.session.prefs.language == .system else { return }
                Copy.language = .system
                self.session.objectWillChange.send()
            }
        }
        let onDrag: (NSEvent) -> Void = { [weak self] event in
            let type = event.type
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.notePanelExportDrag(type)
                    self?.edgeDrop?.handleDrag(type: type)
                }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated {
                        self?.notePanelExportDrag(type)
                        self?.edgeDrop?.handleDrag(type: type)
                    }
                }
            }
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp], handler: onDrag)
        localDragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { event in
            onDrag(event)
            return event
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if self.session.recordingHotKey != nil {
                self.session.applyRecordedHotKey(from: event)
                return nil
            }
            let first = NSApp.keyWindow?.firstResponder
            let typing = self.isTyping(in: first)
            if self.session.prefs.hideHotKey.matches(event) {
                if typing { return event }
                if self.session.spotlight.isActive {
                    self.session.spotlight.setText("")
                    return nil
                }
                self.hidePanel()
                return nil
            }
            if typing { return event }
            if self.session.prefs.pasteHotKey.matches(event) {
                self.session.pasteFromClipboard()
                return nil
            }
            if self.session.prefs.copyHotKey.matches(event) {
                if self.panel?.isVisible == true {
                    self.session.copySelected()
                    return nil
                }
            }
            if self.panel?.isVisible == true {
                if event.keyCode == 125 {
                    self.session.moveSelection(offset: 1)
                    return nil
                }
                if event.keyCode == 126 {
                    self.session.moveSelection(offset: -1)
                    return nil
                }
                if self.matchesDelete(event) {
                    self.session.removeSelected()
                    return nil
                }
            }
            return event
        }
        if CommandLine.arguments.contains("--capture") {
            let finished = OnceFlag()
            DispatchQueue.global().asyncAfter(deadline: .now() + 25) {
                guard finished.take() else { return }
                let line = "capture: timeout\n"
                fputs(line, stdout)
                fflush(stdout)
                try? DropAgentPaths.ensure()
                try? Data(line.utf8).write(to: DropAgentPaths.root.appendingPathComponent("capture-result.txt"))
                kill(getpid(), SIGTERM)
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    kill(getpid(), SIGKILL)
                }
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.session.captureCurrentPage()
                guard finished.take() else { return }
                let line: String
                if let item = self.session.items.first {
                    line = "capture: WEB \(item.kind.tag) \(item.title) \(item.sourceURL.absoluteString)\n"
                } else {
                    line = "capture: \(self.session.errorText ?? "empty")\n"
                }
                fputs(line, stdout)
                fflush(stdout)
                try? DropAgentPaths.ensure()
                try? Data(line.utf8).write(to: DropAgentPaths.root.appendingPathComponent("capture-result.txt"))
                NSApp.terminate(nil)
            }
        } else if isDiagnosticLaunch == false {
            DispatchQueue.main.async { [weak self] in
                self?.revealOnFirstOpenIfNeeded()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard isDiagnosticLaunch == false else { return false }
        showPanel()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if StatusChrome.restoresOnActivate {
            StatusChrome.restore()
        }
        session.refreshSetup()
    }

    func revealOnFirstOpenIfNeeded() {
        try? DropAgentPaths.ensure()
        let marker = DropAgentPaths.openedFile
        guard FirstOpen.shouldReveal(
            markerExists: FileManager.default.fileExists(atPath: marker.path),
            isDiagnostic: isDiagnosticLaunch
        ) else { return }
        showPanel()
        FileManager.default.createFile(atPath: marker.path, contents: Data("1".utf8))
    }

    func reregisterHotKeys() {
        let keys = HotKeyCenter.shared.register(
            toggle: { [weak self] in
                guard self?.session.recordingHotKey == nil else { return }
                self?.togglePanel()
            },
            capture: { [weak self] in
                guard self?.session.recordingHotKey == nil else { return }
                Task { @MainActor in
                    self?.session.prepareCapture()
                    self?.showPanel()
                    await self?.session.captureCurrentPage()
                }
            },
            files: { [weak self] in
                guard self?.session.recordingHotKey == nil else { return }
                Task { @MainActor in
                    self?.session.prepareFrontFiles()
                    self?.showPanel()
                    await self?.session.admitFrontSelection()
                }
            },
            toggleChord: session.prefs.toggleHotKey,
            captureChord: session.prefs.captureHotKey,
            filesChord: session.prefs.filesHotKey,
            hideChord: session.prefs.hideHotKey,
            pasteChord: session.prefs.pasteHotKey,
            copyChord: session.prefs.copyHotKey,
            deleteChord: session.prefs.deleteHotKey
        )
        session.hotKeyToggleOK = keys.toggle
        session.hotKeyCaptureOK = keys.capture
        session.hotKeyFilesOK = keys.files
    }

    func matchesDelete(_ event: NSEvent) -> Bool {
        if session.prefs.deleteHotKey == .deleteDefault {
            return event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)
        }
        return session.prefs.deleteHotKey.matches(event)
    }

    var panelGeneration = 0
    var panelRecessed = false
    var exportingFromPanel = false
    var applyingPanelFrame = false
    var recessWork: DispatchWorkItem?

    var isDiagnosticLaunch: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--capture") || args.contains("--preview") || args.contains("--e2e")
    }

    func isTyping(in responder: NSResponder?) -> Bool {
        if Self.isTextInput(responder) { return true }
        if Self.isTextInput(panel?.firstResponder) { return true }
        return false
    }

    private static func isTextInput(_ responder: NSResponder?) -> Bool {
        responder is NSTextView || responder is NSTextField || responder is TerminalView
    }
}
