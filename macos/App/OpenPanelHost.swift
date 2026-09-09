import AppKit

enum OpenPanelHost {
    @MainActor
    static func run(_ panel: NSOpenPanel) -> [URL] {
        StatusChrome.lowerForPicker()
        defer { StatusChrome.restore() }
        NSApp.activate(ignoringOtherApps: true)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
