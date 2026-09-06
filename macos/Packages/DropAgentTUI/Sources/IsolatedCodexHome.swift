import Foundation

/// DropAgent-owned Codex home for the in-panel TUI.
/// Copies login only; never copies the user's MCP, hooks, plugins, or config.toml.
public enum IsolatedCodexHome {
    public static func prepare(at home: URL, trusting cwd: URL) throws {
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        let real = cwd.resolvingSymlinksInPath().path
        let escaped = real
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let config = """
        # DropAgent TUI home. Recipe isolation lives in Agent exec flags;
        # this file exists so the interactive session does not load ~/.codex MCP or hooks.

        [projects."\(escaped)"]
        trust_level = "trusted"
        """
        try config.write(to: home.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)
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
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], override.isEmpty == false {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }
}
