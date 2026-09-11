import AppKit
import DropAgentIngest
import SwiftUI

extension AppDelegate {
    func togglePanel() {
        guard let panel else { return }
        switch PanelIdle.toggle(
            visible: panel.isVisible,
            recessed: panelRecessed,
            onActiveSpace: panel.isOnActiveSpace
        ) {
        case .show, .wake:
            showPanel()
        case .hide:
            hidePanel()
        }
    }

    func showPanel() {
        cancelRecess()
        panelRecessed = false
        StatusChrome.restore()
        session.refreshPresence()
        session.refreshSetup()
        NSApp.activate(ignoringOtherApps: true)
        positionPanel()
        guard let panel else { return }
        panel.level = PanelIdle.activeLevel
        PanelIdle.attachToActiveSpace(panel)
        panelGeneration += 1
        let skipMotion = shouldSkipPanelMotion || panel.isVisible
        if skipMotion {
            PanelIdle.applyActive(to: panel)
            panel.makeKeyAndOrderFront(nil)
            panel.invalidateShadow()
            refreshStatus()
            return
        }
        let target = panel.frame
        var from = target
        from.origin.y += 8
        panel.alphaValue = 0
        applyingPanelFrame = true
        panel.setFrame(from, display: true)
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.applyingPanelFrame = false
                self?.panel?.invalidateShadow()
            }
        })
        refreshStatus()
    }

    func hidePanel() {
        session.stopStageEdit()
        session.closeClipHistory()
        cancelRecess()
        guard let panel, panel.isVisible else { return }
        let skip = shouldSkipPanelMotion || panelRecessed
        panelRecessed = false
        if skip {
            panel.orderOut(nil)
            PanelIdle.applyActive(to: panel)
            refreshStatus()
            return
        }
        let generation = panelGeneration
        let start = panel.frame
        var to = start
        to.origin.y += 6
        panel.level = PanelIdle.activeLevel
        applyingPanelFrame = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
            panel.animator().setFrame(to, display: true)
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.panelGeneration == generation else { return }
                panel.orderOut(nil)
                PanelIdle.applyActive(to: panel)
                panel.setFrame(start, display: false)
                self.applyingPanelFrame = false
                self.refreshStatus()
            }
        })
    }

    func wakePanel(makeKey: Bool) {
        cancelRecess()
        guard let panel, panel.isVisible else { return }
        if panel.isOnActiveSpace == false {
            showPanel()
            return
        }
        panelRecessed = false
        panel.level = PanelIdle.activeLevel
        if makeKey {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        if shouldSkipPanelMotion || panel.alphaValue > 0.99 {
            panel.alphaValue = 1
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = PanelIdle.fadeDuration
                panel.animator().alphaValue = 1
            }
        }
        panel.invalidateShadow()
        refreshStatus()
    }

    func scheduleRecess() {
        recessWork?.cancel()
        guard StatusChrome.restoresOnActivate else { return }
        guard isDiagnosticLaunch == false, let panel, panel.isVisible, panelRecessed == false else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.recessPanelIfNeeded()
            }
        }
        recessWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PanelIdle.delay, execute: work)
    }

    func cancelRecess() {
        recessWork?.cancel()
        recessWork = nil
    }

    func recessPanelIfNeeded() {
        recessWork = nil
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        let mouseInside = PanelIdle.dragHitsPanel(mouse: mouse, frame: panel.frame)
            || session.clipMenu.containsPointer(mouse)
        guard PanelIdle.shouldRecess(
            visible: panel.isVisible,
            isKey: panel.isKeyWindow,
            mouseInside: mouseInside,
            exporting: exportingFromPanel,
            diagnostic: isDiagnosticLaunch,
            dragging: session.systemDragActive,
            prompting: StatusChrome.restoresOnActivate == false
        ) else { return }
        panelRecessed = true
        panel.level = PanelIdle.recessedLevel
        if shouldSkipPanelMotion {
            panel.alphaValue = PanelIdle.alpha
        } else {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = PanelIdle.fadeDuration
                panel.animator().alphaValue = PanelIdle.alpha
            }
        }
    }

    func notePanelExportDrag(_ type: NSEvent.EventType) {
        if type == .leftMouseDragged {
            guard let panel, panel.isVisible else { return }
            if exportingFromPanel || panel.frame.contains(NSEvent.mouseLocation) {
                if ClipboardPayload.hasDragCargo(NSPasteboard(name: .drag)) {
                    exportingFromPanel = true
                }
            }
            return
        }
        if type == .leftMouseUp {
            session.endShelfDrag()
            session.endClipDrag()
            session.endActionDrag()
            if exportingFromPanel {
                exportingFromPanel = false
                scheduleRecess()
            }
        }
    }

    func recessAfterDragLeft() {
        guard session.systemDragActive == false else { return }
        guard panelRecessed == false, panel?.isKeyWindow == false, exportingFromPanel == false else { return }
        cancelRecess()
        recessPanelIfNeeded()
    }

    var shouldSkipPanelMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            || isDiagnosticLaunch
    }

    func setupPanel() {
        let panel = DropAgentPanel(
            contentRect: NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight),
            styleMask: LivePanelChrome.styleMask,
            backing: .buffered,
            defer: false
        )
        panel.title = "DropAgent"
        panel.isFloatingPanel = true
        panel.level = PanelIdle.activeLevel
        panel.collectionBehavior = PanelIdle.spaceBehavior
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hasShadow = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.delegate = self
        panel.onUserMoved = { [weak self] in self?.rememberPanelOrigin() }
        panel.onMouseInsideChange = { [weak self] inside in
            guard let self else { return }
            let overClip = self.session.clipMenu.containsPointer(NSEvent.mouseLocation)
            if inside || overClip {
                if self.panelRecessed == false {
                    self.cancelRecess()
                }
            } else if self.panel?.isKeyWindow == false {
                self.scheduleRecess()
            }
        }
        let hide: () -> Void = { [weak self] in self?.hidePanel() }
        let host = PaperHostView(rootView: PanelRootView(session: session, onClose: hide, onMinimize: hide))
        // This panel owns its frame. Hosting constraints can otherwise enlarge
        // the window beyond the screen as the SwiftUI content changes.
        host.sizingOptions = []
        host.frame = NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight)
        panel.contentView = host
        Palette.applyPaperChrome(to: panel, host: host)
        hosting = host
        self.panel = panel
        panel.installMouseTracking()
        applyPanelAppearance()
    }

    func applyPanelAppearance() {
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

    func positionPanel() {
        guard let panel, panel.userMoving == false else { return }
        let button = statusItem?.button
        let buttonScreen = button?.window?.screen
        let saved = session.prefs.savedPanelOrigin
        let screen: NSScreen?
        if let saved {
            screen = PanelPlacement.screen(forSavedX: saved.x, top: saved.top, fallback: buttonScreen)
        } else {
            screen = buttonScreen ?? NSScreen.main
        }
        guard let screen else { return }
        let visible = screen.visibleFrame
        let size = NSSize(width: session.panelWidth, height: session.panelHeight)
        let frame: NSRect
        if let saved {
            frame = PanelPlacement.placed(savedX: saved.x, savedTop: saved.top, size: size, visible: visible)
        } else {
            let buttonRect: NSRect
            if let button, let window = button.window {
                let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
                buttonRect = rect.height > 1 ? rect : NSRect(x: visible.maxX - 28, y: visible.maxY, width: 28, height: 22)
            } else {
                buttonRect = NSRect(x: visible.maxX - 28, y: visible.maxY, width: 28, height: 22)
            }
            frame = PanelPlacement.underStatusItem(button: buttonRect, visible: visible, size: size)
        }
        applyingPanelFrame = true
        panel.setFrame(frame, display: true)
        hosting?.frame = NSRect(origin: .zero, size: frame.size)
        applyingPanelFrame = false
        panel.invalidateShadow()
    }

    func rememberPanelOrigin() {
        guard applyingPanelFrame == false, let panel, panel.isVisible else { return }
        var prefs = session.prefs
        prefs.savedPanelOrigin = (panel.frame.minX, panel.frame.maxY)
        prefs.save()
        session.prefs = prefs
    }

    func refreshStatus() {
        statusItem?.button?.highlight(panel?.isVisible == true)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        scheduleRecess()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard notification.object as? NSWindow === panel else { return }
        wakePanel(makeKey: false)
    }
}
