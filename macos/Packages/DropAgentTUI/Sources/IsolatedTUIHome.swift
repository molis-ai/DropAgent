import DropAgentAgent
import Foundation

public enum IsolatedTUIHome {
    public static func directory(in inboxRoot: URL, presence: AgentPresence) -> URL {
        inboxRoot.appendingPathComponent("\(presence.homeKey)-home", isDirectory: true)
    }

    public static func directory(in inboxRoot: URL, engine: AgentEngine) -> URL {
        inboxRoot.appendingPathComponent("\(engine.rawValue)-home", isDirectory: true)
    }

    public static func prepare(presence: AgentPresence, at home: URL, cwd: URL) throws {
        if let engine = presence.engine {
            try prepare(engine: engine, at: home, cwd: cwd)
            return
        }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    public static func prepare(engine: AgentEngine, at home: URL, cwd: URL) throws {
        switch engine {
        case .codex:
            try IsolatedCodexHome.prepare(at: home, trusting: cwd)
            try IsolatedCodexHome.copyLogin(into: home)
        case .grok:
            try IsolatedGrokHome.prepare(at: home)
            try IsolatedGrokHome.copyLogin(into: home)
        case .claude:
            try IsolatedClaudeHome.prepare(at: home)
        case .gemini:
            try IsolatedGeminiHome.prepare(at: home)
        case .opencode:
            try IsolatedOpenCodeHome.prepare(at: home)
        case .cursor, .llm, .aichat, .sgpt:
            try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        }
    }

    public static func copyLogin(engine: AgentEngine, into home: URL) throws {
        switch engine {
        case .codex:
            try IsolatedCodexHome.copyLogin(into: home)
        case .grok:
            try IsolatedGrokHome.copyLogin(into: home)
        case .claude, .gemini, .opencode, .cursor, .llm, .aichat, .sgpt:
            break
        }
    }
}

public enum IsolatedGrokHome {
    static func prepare(at home: URL) throws {
        try prepare(at: home, userHome: userHome())
    }

    public static func prepare(at home: URL, userHome: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let configURL = home.appendingPathComponent("config.toml")
        if FileManager.default.fileExists(atPath: configURL.path) {
            return
        }
        var seed = """
        # DropAgent TUI home. Do not load ~/.grok MCP, hooks, or plugins.

        """
        if let ack = privacyAckLine(from: userHome) {
            seed += "\n[privacy]\n\(ack)\n"
        }
        try Data(seed.utf8).write(to: configURL, options: .atomic)
    }

    static func privacyAckLine(from userHome: URL) -> String? {
        let config = userHome.appendingPathComponent("config.toml")
        guard let text = try? String(contentsOf: config, encoding: .utf8) else { return nil }
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("privacy_banner_acked") else { continue }
            if line.contains("mcp_servers") || line.lowercased().contains("always-approve") {
                return nil
            }
            return line
        }
        return nil
    }

    public static func copyLogin(into home: URL) throws {
        try copyLogin(from: userHome(), into: home)
    }

    public static func copyLogin(from userHome: URL, into home: URL) throws {
        let source = userHome.appendingPathComponent("auth.json")
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let dest = home.appendingPathComponent("auth.json")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: dest.path)
    }

    public static func userHome() -> URL {
        if let override = ProcessInfo.processInfo.environment["GROK_HOME"], override.isEmpty == false {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".grok", isDirectory: true)
    }
}

enum IsolatedClaudeHome {
    static func prepare(at home: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("{}\n".utf8).write(to: home.appendingPathComponent("settings.json"), options: .atomic)
        try Data("{\"mcpServers\":{}}\n".utf8).write(to: home.appendingPathComponent("mcp.json"), options: .atomic)
    }
}

enum IsolatedOpenCodeHome {
    static func prepare(at home: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let config = home.appendingPathComponent("opencode.json")
        if FileManager.default.fileExists(atPath: config.path) == false {
            try Data("{}\n".utf8).write(to: config, options: .atomic)
        }
    }
}

enum IsolatedGeminiHome {
    static func prepare(at home: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try Data("{}\n".utf8).write(to: home.appendingPathComponent("settings.json"), options: .atomic)
    }
}
