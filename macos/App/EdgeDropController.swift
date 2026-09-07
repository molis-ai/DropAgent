import AppKit
import DropAgentIngest

@MainActor
final class EdgeDropController {
    private let session: AppSession
    private let panelVisible: () -> Bool
    private let panelFrame: () -> NSRect?
    private let onDragOverPanel: () -> Void
    private let onDragAwayFromPanel: () -> Void

    private var window: NSWindow?
    private var catcherArmed = false
    private var didAdmit = false
    private var snapshot: ClipboardPayload = .empty
    private var hideWork: DispatchWorkItem?
    private var dragWatchdog: DispatchWorkItem?
    private var revealWork: DispatchWorkItem?
    private var dragOrigin: NSPoint?
    private var dragStartedAt: Date?
    private var revealed = false
    private var dismissed = false
    private var center: NSPoint?
    private var lastMouse: NSPoint?
    private var consumedChangeCount = -1

    init(
        session: AppSession,
        panelVisible: @escaping () -> Bool,
        panelFrame: @escaping () -> NSRect?,
        onDragOverPanel: @escaping () -> Void,
        onDragAwayFromPanel: @escaping () -> Void
    ) {
        self.session = session
        self.panelVisible = panelVisible
        self.panelFrame = panelFrame
        self.onDragOverPanel = onDragOverPanel
        self.onDragAwayFromPanel = onDragAwayFromPanel
    }

    private var edgeView: EdgeDropView? {
        window?.contentView as? EdgeDropView
    }

    func setup() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: EdgePlacement.windowSize, height: EdgePlacement.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true
        panel.sharingType = .readWrite
        panel.level = .statusBar
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovable = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = EdgeDropView()
        view.onPick = { [weak self] action, pasteboard in
            self?.admit(ClipboardPayload.from(pasteboard: pasteboard), action: action)
        }
        view.onFinished = { [weak self] in self?.session.finishExternalDrag() }
        panel.contentView = view
        panel.orderOut(nil)
        window = panel
        consumedChangeCount = EdgePlacement.consumeDragPasteboard(clearCargo: true)
    }

    func handleDrag(type: NSEvent.EventType) {
        if type == .leftMouseDragged {
            hideWork?.cancel()
            hideWork = nil
            guard EdgePlacement.dragPasteboardHasPayload(consumedChangeCount: consumedChangeCount) else {
                if session.systemDragActive || catcherArmed {
                    session.finishExternalDrag()
                }
                return
            }
            let mouse = NSEvent.mouseLocation
            if panelVisible(), let frame = panelFrame(), PanelIdle.dragHitsPanel(mouse: mouse, frame: frame) {
                onDragOverPanel()
            } else {
                onDragAwayFromPanel()
            }
            noteExternalDrag(at: mouse)
            pokeDragWatchdog()
            if dragOrigin == nil {
                dragOrigin = mouse
                dragStartedAt = Date()
            }
            let live = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
            if live != .empty {
                snapshot = live
            }
            armRevealTimer()
            updateWheel(at: mouse)
            return
        }
        finishFromMouseUp()
    }

    func hide() {
        hideWork?.cancel()
        hideWork = nil
        dragWatchdog?.cancel()
        dragWatchdog = nil
        revealWork?.cancel()
        revealWork = nil
        let hadCargo = dragOrigin != nil || snapshot != .empty || revealed
        snapshot = .empty
        dragOrigin = nil
        dragStartedAt = nil
        revealed = false
        dismissed = false
        center = nil
        lastMouse = nil
        consumedChangeCount = EdgePlacement.consumeDragPasteboard(clearCargo: hadCargo)
        concealWheel()
        window?.alphaValue = 1
        window?.level = .statusBar
    }

    private func updateWheel(at mouse: NSPoint) {
        guard session.prefs.showDropWheel else {
            if catcherArmed { concealWheel() }
            lastMouse = mouse
            return
        }
        let insidePanel = panelVisible() && (panelFrame()?.contains(mouse) ?? false)
        if insidePanel {
            if catcherArmed { concealWheel() }
            lastMouse = mouse
            return
        }
        guard let screen = EdgePlacement.screen(for: mouse, screens: NSScreen.screens) else {
            if catcherArmed { concealWheel() }
            lastMouse = mouse
            return
        }
        if dismissed {
            lastMouse = mouse
            return
        }
        if revealed == false {
            let started = dragStartedAt ?? Date()
            let due = Date().timeIntervalSince(started) >= EdgePlacement.revealDelay
            if due == false || EdgePlacement.inTabSafeZone(mouse: mouse, screen: screen) {
                lastMouse = mouse
                return
            }
            revealed = true
            center = mouse
        }
        guard let center else {
            lastMouse = mouse
            return
        }
        if EdgePlacement.leftRange(mouse: mouse, center: center) {
            dismissed = true
            concealWheel()
            lastMouse = mouse
            return
        }
        lastMouse = mouse
        let hot: Int?
        if case .slice(let index) = EdgePlacement.band(mouse: mouse, center: center) {
            hot = index
        } else {
            hot = nil
        }
        showWheel(center: center, hot: hot)
    }

    private func finishFromMouseUp() {
        dragWatchdog?.cancel()
        dragWatchdog = nil
        revealWork?.cancel()
        revealWork = nil
        let mouse = NSEvent.mouseLocation
        if catcherArmed, let center, case .slice(let index) = EdgePlacement.band(mouse: mouse, center: center) {
            let slices = WheelLayout.slices(hasAgent: session.hasAgent, hasRecipe: session.hasRecipe)
            if slices.indices.contains(index), slices[index].enabled {
                let live = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
                if live != .empty {
                    admit(live, action: slices[index].action)
                    return
                }
                if snapshot != .empty {
                    admit(snapshot, action: slices[index].action)
                    return
                }
                session.systemDragActive = false
                scheduleHide()
                return
            }
        }
        session.finishExternalDrag()
    }

    private func armRevealTimer() {
        guard session.prefs.showDropWheel else { return }
        guard revealed == false, dismissed == false, revealWork == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.revealWork = nil
            guard self.revealed == false, self.dismissed == false else { return }
            guard self.session.systemDragActive || EdgePlacement.dragPasteboardHasPayload(consumedChangeCount: self.consumedChangeCount) else { return }
            self.updateWheel(at: NSEvent.mouseLocation)
        }
        revealWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + EdgePlacement.revealDelay, execute: work)
    }

    private func pokeDragWatchdog() {
        dragWatchdog?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.checkButtonReleased()
        }
        dragWatchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func checkButtonReleased() {
        guard session.systemDragActive || catcherArmed else { return }
        if NSEvent.pressedMouseButtons & 1 != 0 {
            pokeDragWatchdog()
            return
        }
        finishFromMouseUp()
    }

    private func noteExternalDrag(at mouse: NSPoint) {
        guard session.systemDragActive == false else { return }
        let insidePanel = panelVisible() && (panelFrame()?.contains(mouse) ?? false)
        if insidePanel == false {
            session.systemDragActive = true
        }
    }

    private func showWheel(center: NSPoint, hot: Int?) {
        guard session.prefs.showDropWheel else { return }
        guard let window else { return }
        if catcherArmed == false {
            didAdmit = false
        }
        catcherArmed = true
        let slices = WheelLayout.slices(hasAgent: session.hasAgent, hasRecipe: session.hasRecipe)
        edgeView?.apply(slices: slices, hot: hot)
        window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 8)
        let frame = EdgePlacement.windowFrame(center: center)
        if window.frame.equalTo(frame) == false {
            window.setFrame(frame, display: true)
        }
        if window.isVisible == false {
            let reduce = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            window.alphaValue = reduce ? 1 : 0
            window.orderFrontRegardless()
            if reduce == false {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
                    window.animator().alphaValue = 1
                }
            }
        } else {
            window.alphaValue = 1
        }
    }

    private func concealWheel() {
        catcherArmed = false
        edgeView?.setHot(nil)
        window?.orderOut(nil)
    }

    private func admit(_ payload: ClipboardPayload, action: WheelAction) {
        guard didAdmit == false else { return }
        guard payload != .empty else { return }
        didAdmit = true
        session.admitFromWheel(payload, action: action)
    }

    private func scheduleHide() {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.session.finishExternalDrag()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}
