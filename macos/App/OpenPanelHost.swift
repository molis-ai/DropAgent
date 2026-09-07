import AppKit

enum OpenPanelHost {
    @MainActor
    static func run(_ panel: NSOpenPanel) -> [URL] {
        StatusChrome.hideForPrompt()
        defer { StatusChrome.restore() }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}

@MainActor
enum StatusChrome {
    private struct Snapshot {
        var window: NSWindow
        var level: NSWindow.Level
        var alpha: CGFloat
        var ignoresMouseEvents: Bool
        var wasVisible: Bool
    }

    private static var stored: [Snapshot] = []
    private static var blockActivateRestore = false

    static var restoresOnActivate: Bool { blockActivateRestore == false }

    static func hideForPrompt() {
        NSApp.activate(ignoringOtherApps: true)
        blockActivateRestore = true
        if stored.isEmpty == false { return }
        stored = NSApp.windows.filter { $0.level >= .statusBar }.map { window in
            Snapshot(
                window: window,
                level: window.level,
                alpha: window.alphaValue,
                ignoresMouseEvents: window.ignoresMouseEvents,
                wasVisible: window.isVisible
            )
        }
        for item in stored {
            item.window.ignoresMouseEvents = true
            item.window.alphaValue = 0
            item.window.level = .normal
            item.window.orderOut(nil)
        }
    }

    static func restore() {
        blockActivateRestore = false
        for item in stored {
            item.window.level = item.level
            item.window.alphaValue = item.alpha
            item.window.ignoresMouseEvents = item.ignoresMouseEvents
            if item.wasVisible {
                item.window.orderFront(nil)
            }
        }
        stored = []
    }

    static func finishPromptKeepHidden() {
        blockActivateRestore = false
    }
}
