import AppKit
import DropAgentAgent
import DropAgentCapture
import SwiftTerm
import SwiftUI

final class DropAgentPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum LivePanelChrome {
    static var styleMask: NSWindow.StyleMask { .borderless }
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
    private var localMonitor: Any?
    private var edgeShown = false
    private var hideEdgeWork: DispatchWorkItem?

    func application(_ application: NSApplication, open urls: [URL]) {
        session.admit(urls: urls)
        showPanel()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPanel()
        setupEdge()
        let keys = HotKeyCenter.shared.register(
            toggle: { [weak self] in self?.togglePanel() },
            capture: { [weak self] in
                Task { @MainActor in
                    self?.session.prepareCapture()
                    self?.showPanel()
                    await self?.session.captureCurrentPage()
                }
            }
        )
        session.hotKeyToggleOK = keys.toggle
        session.hotKeyCaptureOK = keys.capture
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            let type = event.type
            if Thread.isMainThread {
                MainActor.assumeIsolated { self?.handleDrag(type: type) }
            } else {
                DispatchQueue.main.sync {
                    MainActor.assumeIsolated { self?.handleDrag(type: type) }
                }
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let first = NSApp.keyWindow?.firstResponder
            let typing = self.isTyping(in: first)
            if event.keyCode == 53 {
                if typing { return event }
                self.hidePanel()
                return nil
            }
            if typing { return event }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "v" {
                self.session.pasteFromClipboard()
                return nil
            }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "c" {
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
                if event.keyCode == 51 || event.keyCode == 117 {
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
                let ax = AccessibilityPage.isTrusted()
                let front = BrowserFront.current()
                let auto: Bool
                if let front {
                    let bundle = NSRunningApplication(processIdentifier: front.pid)?.bundleIdentifier
                        ?? front.kind.primaryBundleIdentifier
                    auto = AutomationAccess.isAllowed(bundleIdentifier: bundle)
                } else {
                    auto = false
                }
                let line: String
                if let item = self.session.items.first {
                    line = "capture: WEB \(item.kind.tag) \(item.title) \(item.sourceURL.absoluteString) ax=\(ax) auto=\(auto)\n"
                } else {
                    line = "capture: \(self.session.errorText ?? "empty") ax=\(ax) auto=\(auto) front=\(front?.kind.rawValue ?? "none")\n"
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

    func togglePanel() {
        guard let panel else { return }
        if panel.isVisible { hidePanel() } else { showPanel() }
    }

    private var panelGeneration = 0

    func showPanel() {
        session.refreshPresence()
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
        menu.addItem(withTitle: session.hasAgent ? "\(session.tuiTitle) 已连接" : "未发现终端 Agent", action: nil, keyEquivalent: "")
        let tuiMenu = NSMenu(title: "终端")
        let autoItem = tuiMenu.addItem(withTitle: "自动", action: #selector(selectTUIAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = session.settings.tuiEngine == .auto ? .on : .off
        tuiMenu.addItem(.separator())
        for engine in AgentEngine.allCases {
            let found = session.installedEngines.contains { $0.engine == engine }
            let title = found ? engine.shortTitle : "\(engine.shortTitle)（未安装）"
            let item = tuiMenu.addItem(withTitle: title, action: #selector(selectTUIEngine(_:)), keyEquivalent: "")
            item.representedObject = engine.rawValue
            item.target = self
            let selected = session.settings.tuiEngine.engine == engine
                || (session.settings.tuiEngine == .auto && session.presence.engine == engine)
            item.state = selected ? .on : .off
        }
        let tuiItem = menu.addItem(withTitle: "选择终端…", action: nil, keyEquivalent: "")
        menu.setSubmenu(tuiMenu, for: tuiItem)
        menu.addItem(withTitle: "指定可执行文件…", action: #selector(pickCodex), keyEquivalent: "")
        for engine in AgentEngine.allCases {
            let item = menu.addItem(withTitle: "如何安装 \(engine.shortTitle)", action: #selector(openEngineInstall(_:)), keyEquivalent: "")
            item.representedObject = engine.rawValue
        }
        menu.addItem(withTitle: HotKeyCopy.menuCaptureTitle(captureOK: session.hotKeyCaptureOK), action: #selector(capturePage), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 DropAgent", action: #selector(quit), keyEquivalent: "q")
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

    @objc private func pickCodex() { session.pickTUIExecutable() }
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
    @objc private func capturePage() {
        Task { @MainActor [weak self] in
            self?.session.prepareCapture()
            self?.showPanel()
            await self?.session.captureCurrentPage()
        }
    }
    @objc private func quit() { NSApp.terminate(nil) }

    private func isTyping(in responder: NSResponder?) -> Bool {
        responder is NSTextView || responder is NSTextField || responder is TerminalView
    }

    private func setupPanel() {
        let panel = DropAgentPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 620),
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
        let host = PaperHostView(rootView: PanelRootView(session: session, onClose: { [weak self] in self?.hidePanel() }))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 620)
        panel.contentView = host
        Palette.applyPaperChrome(to: panel, host: host)
        hosting = host
        self.panel = panel
    }

    private func positionPanel() {
        guard let panel, let screen = statusItem?.button?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = 400
        let height: CGFloat = min(620, visible.height - 48)
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

    private func setupEdge() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 36),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = EdgeDropView(session: session)
        view.onAdmitted = { [weak self] in self?.showPanel() }
        view.onFinished = { [weak self] in self?.hideEdge() }
        window.contentView = view
        window.orderOut(nil)
        edge = window
    }

    private func handleDrag(type: NSEvent.EventType) {
        if type == .leftMouseDragged {
            hideEdgeWork?.cancel()
            hideEdgeWork = nil
            guard EdgePlacement.dragPasteboardHasPayload() else {
                session.systemDragActive = false
                hideEdge()
                return
            }
            noteExternalDrag(at: NSEvent.mouseLocation)
            if let frame = EdgePlacement.frame(mouse: NSEvent.mouseLocation, screens: NSScreen.screens) {
                showEdge(frame: frame)
            } else {
                hideEdge()
            }
            return
        }
        session.systemDragActive = false
        if edgeShown, let edge, edge.frame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation) {
            scheduleHideEdge()
            return
        }
        hideEdge()
    }

    private func noteExternalDrag(at mouse: NSPoint) {
        guard session.systemDragActive == false else { return }
        let insidePanel = panel?.isVisible == true && (panel?.frame.contains(mouse) ?? false)
        if insidePanel == false {
            session.systemDragActive = true
        }
    }

    private func showEdge(frame: NSRect) {
        guard let edge else { return }
        if edgeShown {
            if edge.frame.equalTo(frame) == false {
                edge.setFrame(frame, display: true)
            }
            return
        }
        edgeShown = true
        if shouldSkipPanelMotion {
            edge.alphaValue = 1
            edge.setFrame(frame, display: true)
            edge.orderFrontRegardless()
            return
        }
        var from = frame
        from.origin.y += 8
        edge.alphaValue = 0
        edge.setFrame(from, display: true)
        edge.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            edge.animator().alphaValue = 1
            edge.animator().setFrame(frame, display: true)
        }
    }

    private func scheduleHideEdge() {
        hideEdgeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hideEdge()
        }
        hideEdgeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func hideEdge() {
        hideEdgeWork?.cancel()
        hideEdgeWork = nil
        edgeShown = false
        edge?.alphaValue = 1
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
    let session: AppSession
    var onAdmitted: (() -> Void)?
    var onFinished: (() -> Void)?
    private let label = NSTextField(labelWithString: "放到这里，加入架子")

    init(session: AppSession) {
        self.session = session
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 36))
        wantsLayer = true
        layer?.backgroundColor = Palette.paperNS.cgColor
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 10
        registerForDraggedTypes(IncomingDrop.draggedTypes)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        label.alignment = .center
        label.frame = bounds
        label.autoresizingMask = [.width, .height]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        layer?.backgroundColor = NSColor.black.cgColor
        label.textColor = Palette.paperNS
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        resetChrome()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        resetChrome()
        onFinished?()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        resetChrome()
        session.admitPasteboard(sender.draggingPasteboard)
        onFinished?()
        onAdmitted?()
        return true
    }

    private func resetChrome() {
        layer?.backgroundColor = Palette.paperNS.cgColor
        label.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
    }
}

enum EdgePlacement {
    static func frame(mouse: NSPoint, screens: [NSScreen]) -> NSRect? {
        let hit = screens.first { screen in
            mouse.x >= screen.frame.minX && mouse.x < screen.frame.maxX
                && mouse.y >= screen.visibleFrame.maxY - 28
                && mouse.y <= screen.frame.maxY
        }
        guard let screen = hit else { return nil }
        let visible = screen.visibleFrame
        let width = max(160, visible.width - 16)
        return NSRect(
            x: visible.minX + 8,
            y: visible.maxY - 36,
            width: width,
            height: 36
        )
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
            rep.size = point
            NSGraphicsContext.saveGraphicsState()
            if let ctx = NSGraphicsContext(bitmapImageRep: rep) {
                NSGraphicsContext.current = ctx
                ctx.shouldAntialias = true
                ctx.cgContext.translateBy(x: 0, y: CGFloat(pixels))
                ctx.cgContext.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
                draw()
            }
            NSGraphicsContext.restoreGraphicsState()
            image.addRepresentation(rep)
        }
        image.isTemplate = true
        return image
    }

    private static func draw() {
        NSColor.black.setStroke()
        let chevron = NSBezierPath()
        chevron.move(to: NSPoint(x: 3, y: 11.5))
        chevron.line(to: NSPoint(x: 15, y: 11.5))
        chevron.line(to: NSPoint(x: 9, y: 4.8))
        chevron.close()
        chevron.lineJoinStyle = .round
        chevron.lineCapStyle = .round
        chevron.lineWidth = 1.5
        chevron.stroke()

        let shelf = NSBezierPath()
        shelf.move(to: NSPoint(x: 5.5, y: 3.2))
        shelf.line(to: NSPoint(x: 12.5, y: 3.2))
        shelf.lineCapStyle = .round
        shelf.lineWidth = 1.5
        shelf.stroke()
    }
}
