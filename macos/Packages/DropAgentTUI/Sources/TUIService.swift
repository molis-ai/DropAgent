import DropAgentAgent
import DropAgentShelf
import Foundation

public struct PreparedTUISend: Equatable, Sendable {
    public var cwd: URL
    public var session: SessionHandle
    public var injection: String
    public var itemIDs: [ItemID]
    public var isolatedHome: URL
    public var feedOnLaunch: Bool
}

public enum TUIError: Error, Equatable, Sendable {
    case noAgent
    case empty
    case missingItem
    case launchFailed
}

public struct TUIService: Sendable {
    private let shelf: ShelfStore
    private let agent: AgentRunning
    private let inboxRoot: URL

    public init(shelf: ShelfStore, agent: AgentRunning, inboxRoot: URL) {
        self.shelf = shelf
        self.agent = agent
        self.inboxRoot = inboxRoot
    }

    public func send(
        itemIDs: [ItemID],
        text: String,
        sessionDirectory: URL? = nil,
        extraFiles: [URL] = []
    ) throws -> PreparedTUISend {
        let presence = agent.tuiPresence(settings: agent.settings)
        guard presence.executable != nil else { throw TUIError.noAgent }
        var session = try agent.ensureInteractiveSession()
        guard FileManager.default.isExecutableFile(atPath: session.executable.path) else {
            throw TUIError.launchFailed
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !itemIDs.isEmpty || !trimmed.isEmpty || !extraFiles.isEmpty else {
            throw TUIError.empty
        }

        let requested = (sessionDirectory ?? inboxRoot.appendingPathComponent("session", isDirectory: true))
        try FileManager.default.createDirectory(at: requested, withIntermediateDirectories: true)
        let cwd = requested.resolvingSymlinksInPath()

        var names: [String] = []
        var claimed = Set<String>()
        for id in itemIDs {
            guard let item = shelf.item(id: id) else { throw TUIError.missingItem }
            for part in item.parts {
                try copyNamed(part.name, from: part.url, into: cwd, names: &names, claimed: &claimed)
            }
            if let output = item.output {
                try copyNamed(output.lastPathComponent, from: output, into: cwd, names: &names, claimed: &claimed)
            }
            try shelf.patch(id: id) { live in
                if live.status == .idle || live.status == .confirm || live.status == .failed {
                    live.status = .sent
                    live.isolationShown = .tui
                    live.recipe = nil
                    live.event = ""
                } else if live.status == .done {
                    live.isolationShown = .tui
                }
            }
        }
        for file in extraFiles {
            try copyNamed(file.lastPathComponent, from: file, into: cwd, names: &names, claimed: &claimed)
        }

        var injection = "请阅读当前目录中的副本材料，不要访问目录之外的文件。\n"
        if !names.isEmpty {
            injection += names.map { "- \($0)" }.joined(separator: "\n") + "\n"
        }
        if trimmed.isEmpty {
            injection += "没有附带说明。要做什么，直接问我。\n"
        } else {
            injection += "用户说：\n\(trimmed)\n"
        }
        if !injection.hasSuffix("\n") {
            injection += "\n"
        }

        let isolatedHome = IsolatedTUIHome.directory(in: inboxRoot, presence: presence)
        try IsolatedTUIHome.prepare(presence: presence, at: isolatedHome, cwd: cwd)
        if presence.kind == .cli, let binary = presence.executable {
            let help = HeadlessCLI.readHelp(at: binary)
            session.executable = CLICommand.shellExecutable()
            session.arguments = ["-l"]
            session.environment = InteractiveLaunch.processEnvironment(executable: binary)
            return PreparedTUISend(
                cwd: cwd,
                session: session,
                injection: CLICommand.line(executable: binary, prompt: injection, help: help),
                itemIDs: itemIDs,
                isolatedHome: isolatedHome,
                feedOnLaunch: true
            )
        }
        if let engine = presence.engine {
            InteractiveLaunch.configure(
                &session,
                engine: engine,
                cwd: cwd,
                injection: injection,
                isolatedHome: isolatedHome
            )
        } else {
            session.arguments = [injection]
            session.environment = InteractiveLaunch.processEnvironment(executable: session.executable)
        }
        return PreparedTUISend(
            cwd: cwd,
            session: session,
            injection: injection,
            itemIDs: itemIDs,
            isolatedHome: isolatedHome,
            feedOnLaunch: false
        )
    }

    public func revertSend(itemIDs: [ItemID]) {
        for id in itemIDs {
            try? shelf.patch(id: id) { live in
                guard live.status == .sent else { return }
                live.status = .idle
                live.isolationShown = .none
                live.event = ""
            }
        }
    }

    private func copyNamed(_ name: String, from source: URL, into cwd: URL, names: inout [String], claimed: inout Set<String>) throws {
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        var dest = cwd.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: dest.path), !claimed.contains(name) {
            names.append(name)
            claimed.insert(name)
            return
        }
        if FileManager.default.fileExists(atPath: dest.path) {
            dest = uniqueURL(in: cwd, preferredName: name)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        try stripSymlinks(at: dest)
        names.append(dest.lastPathComponent)
        claimed.insert(dest.lastPathComponent)
    }

    private func stripSymlinks(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
            return
        }
        guard isDir.boolValue else { return }
        for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            try stripSymlinks(at: child)
        }
    }

    private func uniqueURL(in directory: URL, preferredName: String) -> URL {
        var dest = directory.appendingPathComponent(preferredName)
        var i = 2
        let base = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        while FileManager.default.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            dest = directory.appendingPathComponent(name)
            i += 1
        }
        return dest
    }
}

