import AppKit
import DropAgentIngest
import SwiftUI

extension AppDelegate {
    func togglePanel() {
        guard let panel else { return }
        switch PanelIdle.toggle(visible: panel.isVisible, recessed: panelRecessed) {
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
                self.refreshStatus()
            }
        })
    }

    func wakePanel(makeKey: Bool) {
        cancelRecess()
        guard let panel, panel.isVisible else { return }
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
        let mouseInside = PanelIdle.dragHitsPanel(mouse: NSEvent.mouseLocation, frame: panel.frame)
        guard PanelIdle.shouldRecess(
            visible: panel.isVisible,
            isKey: panel.isKeyWindow,
            mouseInside: mouseInside,
            exporting: exportingFromPanel,
            diagnostic: isDiagnosticLaunch,
            dragging: session.systemDragActive
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
        if type == .leftMouseUp, exportingFromPanel {
            exportingFromPanel = false
            scheduleRecess()
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
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.hasShadow = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.delegate = self
        panel.onMouseInsideChange = { [weak self] inside in
            guard let self else { return }
            if inside {
                if self.panelRecessed == false {
                    self.cancelRecess()
                }
            } else if self.panel?.isKeyWindow == false {
                self.scheduleRecess()
            }
        }
        let hide: () -> Void = { [weak self] in self?.hidePanel() }
        let host = PaperHostView(rootView: PanelRootView(session: session, onClose: hide, onMinimize: hide))
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
        guard let panel, let screen = statusItem?.button?.window?.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let target = session.panelWidth
        let width: CGFloat = min(target, max(LivePanelChrome.shelfOnlyMin, visible.width - 16))
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
