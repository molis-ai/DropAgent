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
