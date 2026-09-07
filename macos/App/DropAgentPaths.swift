import Foundation

enum DropAgentPaths {
    nonisolated(unsafe) static var inboxOverride: URL?
    nonisolated(unsafe) static var jobsOverride: URL?

    static var root: URL {
        if let override = ProcessInfo.processInfo.environment["DROPAGENT_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("DropAgent", isDirectory: true)
    }

    static var inbox: URL { inboxOverride ?? root.appendingPathComponent("Inbox", isDirectory: true) }
    static var jobs: URL { jobsOverride ?? root.appendingPathComponent("Jobs", isDirectory: true) }
    static var tuiInbox: URL { root.appendingPathComponent("TUIInbox", isDirectory: true) }
    static var shelfFile: URL { root.appendingPathComponent("shelf.json") }
    static var settingsFile: URL { root.appendingPathComponent("settings.json") }
    static var prefsFile: URL { root.appendingPathComponent("prefs.json") }
    static var panelFile: URL { root.appendingPathComponent("panel.json") }
    static var openedFile: URL { root.appendingPathComponent("opened") }

    static func ensure() throws {
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: jobs, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tuiInbox, withIntermediateDirectories: true)
    }
}
