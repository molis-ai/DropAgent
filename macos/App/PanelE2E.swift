import AppKit
import Foundation

@MainActor
enum PanelE2E {
    static func run() async {
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
        guard !panel.styleMask.contains(.titled), !panel.styleMask.contains(.resizable) else {
            fail("panel gained title bar or resize controls")
        }
        fputs("e2e: panel ok — menu placement, PDF, settings, move, reopen, persisted position\n", stdout)
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

    private static func fail(_ message: String) -> Never {
        fputs("e2e: panel FAIL — \(message)\n", stderr)
        exit(1)
    }
}
