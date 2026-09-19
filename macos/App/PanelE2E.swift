import AppKit
import Foundation

@MainActor
enum PanelE2E {
    static func run() async {
        checkResizeMath()
        var prefs = AppPreferences.default
        prefs.savedPanelOrigin = nil
        prefs.save()
        let delegate = AppDelegate()
        delegate.setupStatusItem()
        delegate.setupPanel()
        defer {
            delegate.panel?.orderOut(nil)
            if let item = delegate.statusItem { NSStatusBar.system.removeStatusItem(item) }
        }
        await settle()
        delegate.showPanel()
        await settle()
        checkVisible(delegate, stage: "first open", atMenu: true)
        delegate.session.tryOnboardingSample()
        await settle()
        checkVisible(delegate, stage: "open PDF", atMenu: true)
        delegate.session.settingsOpen = true
        await settle()
        checkVisible(delegate, stage: "settings", atMenu: true)
        delegate.session.settingsOpen = false
        await settle()

        guard let panel = delegate.panel, let screen = panel.screen else { fail("no live panel") }
        let visible = screen.visibleFrame
        var dragged = panel.frame
        dragged.origin = NSPoint(x: visible.minX + 24, y: visible.minY + 24)
        panel.beginUserMove(at: NSPoint(x: panel.frame.minX + 500, y: panel.frame.maxY - 60))
        panel.continueUserMove(at: NSPoint(x: dragged.minX + 500, y: dragged.maxY - 60))
        delegate.positionPanel()
        guard panel.frame == dragged, AppPreferences.load().savedPanelOrigin == nil else {
            fail("layout interrupted drag or drag saved before release")
        }
        panel.endUserMove()
        await settle()
        let saved = AppPreferences.load().savedPanelOrigin
        guard let saved, abs(saved.x - dragged.minX) < 1, abs(saved.top - dragged.maxY) < 1 else {
            fail("user move did not persist: \(String(describing: saved)); expected \(dragged)")
        }
        delegate.hidePanel()
        await settle()
        delegate.showPanel()
        await settle()
        guard abs(panel.frame.minX - dragged.minX) < 1, abs(panel.frame.maxY - dragged.maxY) < 1 else {
            fail("reopen lost position: \(panel.frame); expected \(dragged)")
        }
        checkVisible(delegate, stage: "reopen saved position", atMenu: false)

        delegate.session.prefs = AppPreferences.load()
        delegate.positionPanel()
        await settle()
        guard abs(panel.frame.minX - saved.x) < 1, abs(panel.frame.maxY - saved.top) < 1 else {
            fail("reloaded preferences lost position")
        }

        let beforeResize = panel.frame
        let sizeBeforeResize = AppPreferences.load().savedPanelSize
        let grip = NSPoint(x: beforeResize.maxX - 8, y: beforeResize.minY + 8)
        panel.beginUserResize(edge: .southEast, at: grip)
        panel.continueUserResize(at: NSPoint(x: grip.x + 80, y: grip.y - 48))
        delegate.positionPanel()
        let midResize = AppPreferences.load().savedPanelSize
        guard panel.frame.width > beforeResize.width + 20, panel.frame.height > beforeResize.height + 20 else {
            fail("user resize did not change frame: \(panel.frame); from \(beforeResize)")
        }
        guard sizeUnchanged(midResize, sizeBeforeResize) else {
            fail("layout saved size before resize release")
        }
        panel.endUserResize()
        await settle()
        let savedSize = AppPreferences.load().savedPanelSize
        guard let savedSize,
              abs(savedSize.width - panel.frame.width) < 1,
              abs(savedSize.height - panel.frame.height) < 1
        else {
            fail("user resize did not persist size: \(String(describing: savedSize)); frame \(panel.frame)")
        }
        let resized = panel.frame
        delegate.hidePanel()
        await settle()
        delegate.showPanel()
        await settle()
        guard abs(panel.frame.width - resized.width) < 1, abs(panel.frame.height - resized.height) < 1 else {
            fail("reopen lost size: \(panel.frame); expected \(resized)")
        }
        guard abs(panel.frame.minX - resized.minX) < 1, abs(panel.frame.maxY - resized.maxY) < 1 else {
            fail("reopen after resize lost position: \(panel.frame); expected \(resized)")
        }

        guard !panel.styleMask.contains(.titled), !panel.styleMask.contains(.resizable) else {
            fail("panel gained title bar or system resize controls")
        }
        fputs("e2e: panel ok — menu placement, PDF, settings, move, resize, reopen, persisted frame\n", stdout)
    }

    private static func checkVisible(_ delegate: AppDelegate, stage: String, atMenu: Bool) {
        guard let panel = delegate.panel, let host = delegate.hosting, let screen = panel.screen else {
            fail("\(stage): no panel, host or screen")
        }
        let visible = screen.visibleFrame
        let frame = panel.frame
        fputs("panel: \(stage) frame=\(frame) host=\(host.frame) bounds=\(host.bounds) visible=\(visible) desired=\(delegate.session.panelHeight)\n", stdout)
        guard visible.insetBy(dx: -1, dy: -1).contains(frame) else {
            fail("\(stage): window outside visible screen")
        }
        guard abs(host.frame.height - frame.height) < 1, abs(host.frame.width - frame.width) < 1 else {
            fail("\(stage): hosting view exceeds window")
        }
        if atMenu {
            guard abs(frame.maxY - visible.maxY) < 40 else {
                fail("\(stage): panel did not open below menu bar")
            }
            guard delegate.session.prefs.savedPanelOrigin == nil else {
                fail("\(stage): layout incorrectly saved a user position")
            }
        }
    }

    private static func settle() async {
        try? await Task.sleep(for: .milliseconds(600))
    }

    private static func checkResizeMath() {
        let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let southEast = PanelResize.frame(
            start: NSRect(x: 80, y: 200, width: 1160, height: 640),
            from: NSPoint(x: 1240, y: 200),
            to: NSPoint(x: 1320, y: 120),
            edge: .southEast,
            visible: visible
        )
        guard abs(southEast.width - 1240) < 0.5, abs(southEast.height - 720) < 0.5 else {
            fail("southeast resize \(southEast)")
        }
        guard abs(southEast.minX - 80) < 0.5, abs(southEast.maxY - 840) < 0.5 else {
            fail("southeast anchor \(southEast)")
        }
        let west = PanelResize.frame(
            start: NSRect(x: 200, y: 100, width: 1000, height: 500),
            from: NSPoint(x: 200, y: 300),
            to: NSPoint(x: 120, y: 300),
            edge: .west,
            visible: visible
        )
        guard abs(west.maxX - 1200) < 0.5, abs(west.width - 1080) < 0.5 else {
            fail("west resize \(west)")
        }
        let minEast = PanelResize.frame(
            start: NSRect(x: 80, y: 200, width: 1160, height: 640),
            from: NSPoint(x: 1240, y: 200),
            to: NSPoint(x: 200, y: 200),
            edge: .east,
            visible: visible
        )
        guard abs(minEast.width - LivePanelChrome.panelMinWidth) < 0.5 else {
            fail("min width \(minEast.width)")
        }
        var sizePrefs = AppPreferences.default
        sizePrefs.savedPanelSize = NSSize(width: 980, height: 520)
        sizePrefs.save()
        guard let stored = AppPreferences.load().savedPanelSize,
              abs(stored.width - 980) < 0.5,
              abs(stored.height - 520) < 0.5
        else {
            fail("panel size did not persist")
        }
    }

    private static func sizeUnchanged(_ lhs: NSSize?, _ rhs: NSSize?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (a?, b?):
            return abs(a.width - b.width) < 1 && abs(a.height - b.height) < 1
        default:
            return false
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("e2e: panel FAIL — \(message)\n", stderr)
        exit(1)
    }
}
