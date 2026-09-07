import AppKit
import Carbon
import DropAgentAgent
import DropAgentIngest
import SwiftTerm
import SwiftUI

final class DropAgentPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum LivePanelChrome {
    static var styleMask: NSWindow.StyleMask { .borderless }
    static let panelWidth: CGFloat = 680
    static let panelHeight: CGFloat = 620
    static let shelfDefault: CGFloat = 240
    static let shelfMin: CGFloat = 200
    static let shelfMax: CGFloat = 320
    static let splitWidth: CGFloat = 7
}

enum FirstOpen {
    static func shouldReveal(markerExists: Bool, isDiagnostic: Bool) -> Bool {
        isDiagnostic == false && markerExists == false
    }
}

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
    private var statusItem: NSStatusItem?
    private var panel: DropAgentPanel?
    private var hosting: PaperHostView<PanelRootView>?
    private var edge: NSWindow?
    private var dragMonitor: Any?
    private var localDragMonitor: Any?
    private var localMonitor: Any?
    private var edgeShown = false
    private var edgeCatcherArmed = false
    private var edgeDidAdmit = false
    private var edgeSnapshot: ClipboardPayload = .empty
    private var hideEdgeWork: DispatchWorkItem?
    private var dragWatchdog: DispatchWorkItem?
    private var appearanceObserver: NSObjectProtocol?
    private var localeObserver: NSObjectProtocol?

    func application(_ application: NSApplication, open urls: [URL]) {
        session.admit(urls: urls)
        showPanel()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        setupEdge()
        session.onApplyHotKeys = { [weak self] in self?.reregisterHotKeys() }
        reregisterHotKeys()
        session.applyChrome = { [weak self] in self?.applyPanelAppearance() }
        session.onFinishExternalDrag = { [weak self] in self?.hideEdge() }
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
                MainActor.assumeIsolated { self?.handleDrag(type: type) }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated { self?.handleDrag(type: type) }
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

    private func revealOnFirstOpenIfNeeded() {
        try? DropAgentPaths.ensure()
        let marker = DropAgentPaths.openedFile
        guard FirstOpen.shouldReveal(
            markerExists: FileManager.default.fileExists(atPath: marker.path),
            isDiagnostic: isDiagnosticLaunch
        ) else { return }
        showPanel()
        FileManager.default.createFile(atPath: marker.path, contents: Data("1".utf8))
    }

    private func reregisterHotKeys() {
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

    private func matchesDelete(_ event: NSEvent) -> Bool {
        if session.prefs.deleteHotKey == .deleteDefault {
            return event.keyCode == UInt16(kVK_Delete) || event.keyCode == UInt16(kVK_ForwardDelete)
        }
        return session.prefs.deleteHotKey.matches(event)
    }

    func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private var panelGeneration = 0

    func showPanel() {
        StatusChrome.restore()
        session.refreshPresence()
        session.refreshSetup()
        NSApp.activate(ignoringOtherApps: true)
        positionPanel()
        guard let panel else { return }
        panelGeneration += 1
        let skipMotion = shouldSkipPanelMotion || panel.isVisible
        if skipMotion {
            panel.alphaValue = 1
            panel.makeKeyAndOrderFront(nil)
            panel.invalidateShadow()
            refreshStatus()
            return
        }
        let target = panel.frame
        var from = target
        from.origin.y += 8
        panel.alphaValue = 0
        panel.setFrame(from, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.invalidateShadow()
            }
        })
        refreshStatus()
    }

    func hidePanel() {
        guard let panel, panel.isVisible else { return }
        if shouldSkipPanelMotion {
            panel.orderOut(nil)
            panel.alphaValue = 1
            refreshStatus()
            return
        }
        let generation = panelGeneration
        let start = panel.frame
        var to = start
        to.origin.y += 6
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
            panel.animator().setFrame(to, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.panelGeneration == generation else { return }
                panel.orderOut(nil)
                panel.alphaValue = 1
                panel.setFrame(start, display: false)
                self.refreshStatus()
            }
        })
    }

    private var shouldSkipPanelMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || isDiagnosticLaunch
    }

    private var isDiagnosticLaunch: Bool {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("--capture") || args.contains("--preview") || args.contains("--e2e")
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = StatusIcon.image()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "DropAgent"
            button.setAccessibilityLabel("DropAgent")
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let drop = StatusDropView(frame: button.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.session = session
            drop.panelVisible = { [weak self] in self?.panel?.isVisible == true }
            drop.onClick = { [weak self] in self?.statusClicked(nil) }
            drop.onDropAdmitted = { [weak self] in self?.showPanel() }
            button.addSubview(drop)
            button.registerForDraggedTypes(IncomingDrop.draggedTypes)
        }
        statusItem = item
    }

    @objc private func statusClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
            return
        }
        togglePanel()
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(
            withTitle: session.hasAgent
                ? Copy.t("\(session.tuiTitle) 已连接", "\(session.tuiTitle) connected")
                : Copy.t("未发现终端 Agent", "No terminal agent found"),
            action: nil,
            keyEquivalent: ""
        )
        let tuiMenu = NSMenu(title: Copy.t("终端", "Terminal"))
        let autoItem = tuiMenu.addItem(withTitle: Copy.t("自动", "Auto"), action: #selector(selectTUIAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = session.settings.tuiEngine == .auto ? .on : .off
        tuiMenu.addItem(.separator())
        for engine in AgentEngine.tuiCases + AgentEngine.cliCases {
            let found = session.installedEngines.contains { $0.engine == engine }
            let title = found
                ? engine.shortTitle
                : Copy.t("\(engine.shortTitle)（未安装）", "\(engine.shortTitle) (not installed)")
            let item = tuiMenu.addItem(withTitle: title, action: #selector(selectTUIEngine(_:)), keyEquivalent: "")
            item.representedObject = engine.rawValue
            item.target = self
            let selected = session.settings.selectedCustomID == nil
                && (session.settings.tuiEngine.engine == engine
                    || (session.settings.tuiEngine == .auto && session.presence.engine == engine))
            item.state = selected ? .on : .off
        }
        if session.settings.customRuntimes.isEmpty == false {
            tuiMenu.addItem(.separator())
            for custom in session.settings.customRuntimes {
                let found = session.installedEngines.contains { $0.runtimeKey == "custom:\(custom.id)" }
                let kind = custom.kind == .cli ? "CLI" : "TUI"
                let title = found ? "\(custom.title) · \(kind)" : Copy.t("\(custom.title)（未安装）", "\(custom.title) (not installed)")
                let item = tuiMenu.addItem(withTitle: title, action: #selector(selectCustomRuntime(_:)), keyEquivalent: "")
                item.representedObject = custom.id
                item.target = self
                item.state = session.settings.selectedCustomID == custom.id ? .on : .off
            }
        }
        let tuiItem = menu.addItem(withTitle: Copy.t("选择终端…", "Choose terminal…"), action: nil, keyEquivalent: "")
        menu.setSubmenu(tuiMenu, for: tuiItem)
        menu.addItem(withTitle: Copy.t("指定可执行文件…", "Choose executable…"), action: #selector(pickTUIExecutable), keyEquivalent: "")
        for engine in AgentEngine.tuiCases {
            let item = menu.addItem(
                withTitle: Copy.t("如何安装 \(engine.shortTitle)", "How to install \(engine.shortTitle)"),
                action: #selector(openEngineInstall(_:)),
                keyEquivalent: ""
            )
            item.representedObject = engine.rawValue
        }
        menu.addItem(withTitle: HotKeyCopy.menuCaptureTitle(captureOK: session.hotKeyCaptureOK), action: #selector(capturePage), keyEquivalent: "")
        menu.addItem(withTitle: HotKeyCopy.menuFilesTitle(filesOK: session.hotKeyFilesOK), action: #selector(admitFrontFiles), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.t("退出 DropAgent", "Quit DropAgent"), action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
            if item.submenu == nil {
                item.isEnabled = item.action != nil
            }
        }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func pickTUIExecutable() { session.pickTUIExecutable() }
    @objc private func openEngineInstall(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let engine = AgentEngine(rawValue: raw)
        else { return }
        session.openTUIInstall(engine)
    }
    @objc private func selectTUIAuto() { session.setTUIPreference(.auto) }
    @objc private func selectTUIEngine(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preference = TUIEnginePreference(rawValue: raw)
        else { return }
        session.setTUIPreference(preference)
    }
    @objc private func selectCustomRuntime(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        session.setCustomRuntime(id)
    }
    @objc private func capturePage() {
        Task { @MainActor [weak self] in
            self?.session.prepareCapture()
            self?.showPanel()
            await self?.session.captureCurrentPage()
        }
    }

    @objc private func admitFrontFiles() {
        Task { @MainActor [weak self] in
            self?.session.prepareFrontFiles()
            self?.showPanel()
            await self?.session.admitFrontSelection()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func isTyping(in responder: NSResponder?) -> Bool {
        responder is NSTextView || responder is NSTextField || responder is TerminalView
    }

    private func setupPanel() {
        let panel = DropAgentPanel(
            contentRect: NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight),
            styleMask: LivePanelChrome.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = "DropAgent"
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        let hide: () -> Void = { [weak self] in self?.hidePanel() }
        let host = PaperHostView(rootView: PanelRootView(session: session, onClose: hide, onMinimize: hide))
        host.frame = NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight)
        panel.contentView = host
        Palette.applyPaperChrome(to: panel, host: host)
        hosting = host
        self.panel = panel
        applyPanelAppearance()
    }

    private func applyPanelAppearance() {
        Palette.isDark = session.prefs.appearance.resolvedIsDark
        switch session.prefs.appearance {
        case .light:
            panel?.appearance = NSAppearance(named: .aqua)
        case .dark:
            panel?.appearance = NSAppearance(named: .darkAqua)
        case .system:
            panel?.appearance = nil
        }
        if let panel, let host = hosting {
            Palette.applyPaperChrome(to: panel, host: host)
        }
    }

    private func positionPanel() {
        guard let panel, let screen = statusItem?.button?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = min(LivePanelChrome.panelWidth, max(360, visible.width - 16))
        let height: CGFloat = min(LivePanelChrome.panelHeight, visible.height - 48)
        let buttonRect: NSRect
        if let button = statusItem?.button, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            buttonRect = rect.height > 1 ? rect : NSRect(x: visible.maxX - 28, y: visible.maxY, width: 28, height: 22)
        } else {
            buttonRect = NSRect(x: visible.maxX - 28, y: visible.maxY, width: 28, height: 22)
        }
        var x = buttonRect.maxX - width
        x = min(max(visible.minX + 8, x), max(visible.minX + 8, visible.maxX - width - 8))
        let y = max(visible.minY + 8, buttonRect.minY - height - 6)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        hosting?.frame = NSRect(origin: .zero, size: NSSize(width: width, height: height))
        panel.invalidateShadow()
    }

    private var edgeView: EdgeDropView? {
        edge?.contentView as? EdgeDropView
    }

    private func setupEdge() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: EdgePlacement.barHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.worksWhenModal = true
        window.sharingType = .readWrite
        window.level = .statusBar
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.isMovable = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.registerForDraggedTypes(IncomingDrop.draggedTypes)
        let view = EdgeDropView()
        view.onDrop = { [weak self] pasteboard in self?.admitFromEdge(pasteboard) }
        view.onFinished = { [weak self] in self?.session.finishExternalDrag() }
        window.contentView = view
        window.orderOut(nil)
        edge = window
    }

    private func handleDrag(type: NSEvent.EventType) {
        if type == .leftMouseDragged {
            hideEdgeWork?.cancel()
            hideEdgeWork = nil
            guard EdgePlacement.dragPasteboardHasPayload() else {
                session.finishExternalDrag()
                return
            }
            noteExternalDrag(at: NSEvent.mouseLocation)
            pokeDragWatchdog()
            let mouse = NSEvent.mouseLocation
            let inBand = EdgePlacement.frame(mouse: mouse, screens: NSScreen.screens) != nil
            let insidePanel = panel?.isVisible == true && (panel?.frame.contains(mouse) ?? false)
            if insidePanel, inBand == false {
                hideEdge()
                return
            }
            guard let screen = EdgePlacement.screen(for: mouse, screens: NSScreen.screens) else {
                hideEdge()
                return
            }
            armCatcher(frame: EdgePlacement.strip(on: screen), visible: inBand)
            let live = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
            if live != .empty {
                edgeSnapshot = live
            }
            return
        }
        finishDragFromMouseUp()
    }

    private func finishDragFromMouseUp() {
        dragWatchdog?.cancel()
        dragWatchdog = nil
        let inBand = edgeCatcherArmed
            && EdgePlacement.frame(mouse: NSEvent.mouseLocation, screens: NSScreen.screens) != nil
        if inBand {
            let live = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
            if live != .empty {
                admitFromEdge(live)
                return
            }
            if edgeSnapshot != .empty {
                admitFromEdge(edgeSnapshot)
                return
            }
            session.systemDragActive = false
            scheduleHideEdge()
            return
        }
        session.finishExternalDrag()
    }

    private func pokeDragWatchdog() {
        dragWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.checkDragButtonReleased()
        }
        dragWatchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func checkDragButtonReleased() {
        guard session.systemDragActive || edgeCatcherArmed else { return }
        if NSEvent.pressedMouseButtons & 1 != 0 {
            pokeDragWatchdog()
            return
        }
        finishDragFromMouseUp()
    }

    private func noteExternalDrag(at mouse: NSPoint) {
        guard session.systemDragActive == false else { return }
        let insidePanel = panel?.isVisible == true && (panel?.frame.contains(mouse) ?? false)
        if insidePanel == false {
            session.systemDragActive = true
        }
    }

    private func armCatcher(frame: NSRect, visible: Bool) {
        guard let edge else { return }
        edgeView?.setOffered(visible)
        if visible { edgeView?.setHot(true) }
        edgeShown = visible
        if edgeCatcherArmed {
            if edge.frame.equalTo(frame) == false {
                edge.setFrame(frame, display: true)
            }
            edge.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
            edge.alphaValue = visible ? 1 : 0.01
            return
        }
        edgeCatcherArmed = true
        edgeDidAdmit = false
        edge.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
        edge.alphaValue = visible ? 1 : 0.01
        if visible {
            var nudged = frame
            nudged.origin.x += 1
            edge.setFrame(nudged, display: true)
            edge.orderFrontRegardless()
            edge.setFrame(frame, display: true)
        } else {
            edge.setFrame(frame, display: true)
            edge.orderFrontRegardless()
        }
    }

    private func admitFromEdge(_ pasteboard: NSPasteboard) {
        admitFromEdge(ClipboardPayload.from(pasteboard: pasteboard))
    }

    private func admitFromEdge(_ payload: ClipboardPayload) {
        guard edgeDidAdmit == false else { return }
        guard payload != .empty else { return }
        edgeDidAdmit = true
        session.admitPayload(payload)
        session.finishExternalDrag()
    }

    private func scheduleHideEdge() {
        hideEdgeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.session.finishExternalDrag()
        }
        hideEdgeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func hideEdge() {
        hideEdgeWork?.cancel()
        hideEdgeWork = nil
        dragWatchdog?.cancel()
        dragWatchdog = nil
        edgeShown = false
        edgeCatcherArmed = false
        edgeSnapshot = .empty
        edgeView?.setOffered(false)
        edgeView?.setHot(false)
        edge?.alphaValue = 1
        edge?.level = .statusBar
        edge?.orderOut(nil)
    }

    private func refreshStatus() {
        statusItem?.button?.highlight(panel?.isVisible == true)
    }
}

@MainActor
final class StatusDropView: NSView {
    weak var session: AppSession?
    var panelVisible: () -> Bool = { false }
    var onClick: (() -> Void)?
    var onDropAdmitted: (() -> Void)?
    private var ignoreNextClick = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        applyHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        applyHover(false)
    }

    func applyHover(_ hovering: Bool) {
        (superview as? NSButton)?.highlight(hovering || panelVisible())
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        ignoreNextClick = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.18).cgColor
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        ignoreNextClick = false
        layer?.backgroundColor = .clear
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        layer?.backgroundColor = .clear
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        layer?.backgroundColor = .clear
        session?.admitPasteboard(sender.draggingPasteboard)
        onDropAdmitted?()
        return true
    }

    override func mouseUp(with event: NSEvent) {
        if ignoreNextClick {
            ignoreNextClick = false
            return
        }
        onClick?()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes(IncomingDrop.draggedTypes)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes(IncomingDrop.draggedTypes)
    }
}

@MainActor
final class EdgeDropView: NSView {
    var onDrop: ((NSPasteboard) -> Void)?
    var onFinished: (() -> Void)?
    private let paper = NSView()
    private let label = NSTextField(labelWithString: Copy.t("放到这里，加入架子", "Drop here to add to the shelf"))
    private var hot = false

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: EdgePlacement.barHeight))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        paper.wantsLayer = true
        paper.layer?.cornerRadius = 10
        paper.layer?.borderWidth = 1
        paper.layer?.shadowColor = NSColor.black.cgColor
        paper.layer?.shadowOpacity = 0.18
        paper.layer?.shadowOffset = CGSize(width: 0, height: -2)
        paper.layer?.shadowRadius = 10
        addSubview(paper)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.alignment = .center
        paper.addSubview(label)
        registerForDraggedTypes(IncomingDrop.draggedTypes)
        paper.isHidden = true
        applyChrome()
        layout()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        let height = min(EdgePlacement.barHeight, bounds.height)
        paper.frame = NSRect(x: 0, y: 0, width: bounds.width, height: height)
        label.frame = paper.bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    func setOffered(_ offered: Bool) {
        paper.isHidden = !offered
        paper.alphaValue = offered ? 1 : 0
    }

    func setHot(_ hot: Bool) {
        guard self.hot != hot else { return }
        self.hot = hot
        applyChrome()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        setHot(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onFinished?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard)
        onFinished?()
        return true
    }

    private func applyChrome() {
        paper.layer?.backgroundColor = (hot ? Palette.textNS : Palette.paperNS).cgColor
        paper.layer?.borderColor = NSColor.black.withAlphaComponent(hot ? 0.28 : 0.1).cgColor
        label.textColor = hot ? Palette.paperNS : Palette.textNS
    }
}

enum EdgePlacement {
    static let barHeight: CGFloat = 48

    static func screen(for mouse: NSPoint, screens: [NSScreen]) -> NSScreen? {
        screens.first { screen in
            mouse.x >= screen.frame.minX && mouse.x < screen.frame.maxX
                && mouse.y >= screen.frame.minY && mouse.y <= screen.frame.maxY
        }
    }

    static func strip(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = max(160, visible.width - 16)
        let menu = max(0, screen.frame.maxY - visible.maxY)
        return NSRect(
            x: visible.minX + 8,
            y: visible.maxY - barHeight,
            width: width,
            height: barHeight + menu
        )
    }

    static func frame(mouse: NSPoint, screens: [NSScreen]) -> NSRect? {
        let hit = screens.first { screen in
            mouse.x >= screen.frame.minX && mouse.x < screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY - barHeight
                && mouse.y <= screen.frame.maxY
        }
        guard let screen = hit else { return nil }
        return strip(on: screen)
    }

    static func dragPasteboardHasPayload() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        if let items = pasteboard.pasteboardItems, items.isEmpty == false {
            return true
        }
        return pasteboard.availableType(from: IncomingDrop.draggedTypes) != nil
    }
}

enum StatusIcon {
    static func image() -> NSImage {
        let point = NSSize(width: 18, height: 18)
        let image = NSImage(size: point)
        for scale in [1, 2] {
            let pixels = 18 * scale
            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixels,
                pixelsHigh: pixels,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) else { continue }
            NSGraphicsContext.saveGraphicsState()
            if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.current = ctx
                ctx.shouldAntialias = true
                ctx.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                draw()
            }
            NSGraphicsContext.restoreGraphicsState()
            rep.size = point
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        return image
    }

    private static func draw() {
        NSColor.black.setFill()
        NSColor.black.setStroke()

        let hopper = NSBezierPath()
        hopper.move(to: NSPoint(x: 3.55, y: 12.45))
        hopper.line(to: NSPoint(x: 14.45, y: 12.45))
        hopper.line(to: NSPoint(x: 9, y: 5.45))
        hopper.close()
        hopper.lineJoinStyle = .round
        hopper.lineCapStyle = .round
        hopper.lineWidth = 1.45
        hopper.fill()
        hopper.stroke()

        NSBezierPath(
            roundedRect: NSRect(x: 4.9, y: 1.95, width: 8.2, height: 1.65),
            xRadius: 0.825,
            yRadius: 0.825
        ).fill()
    }
}
