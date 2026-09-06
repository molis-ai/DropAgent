import Foundation

public enum InteractiveLaunch {
    public static func configure(
        _ session: inout SessionHandle,
        engine: AgentEngine,
        cwd: URL,
        injection: String,
        isolatedHome: URL
    ) {
        session.arguments = arguments(engine: engine, cwd: cwd, injection: injection, isolatedHome: isolatedHome)
        session.environment = environment(
            existing: session.environment,
            executable: session.executable,
            engine: engine,
            isolatedHome: isolatedHome
        )
    }

    public static func arguments(
        engine: AgentEngine,
        cwd: URL,
        injection: String,
        isolatedHome: URL
    ) -> [String] {
        switch engine {
        case .codex:
            return [
                "--disable", "apps",
                "--disable", "hooks",
                "--disable", "computer_use",
                "--no-alt-screen",
                "-C", cwd.path,
                injection,
            ]
        case .grok:
            return [
                "--no-alt-screen",
                "--cwd", cwd.path,
                injection,
            ]
        case .claude:
            return [
                "--strict-mcp-config",
                "--mcp-config", isolatedHome.appendingPathComponent("mcp.json").path,
                "--setting-sources", "project,local",
                "--add-dir", cwd.path,
                injection,
            ]
        case .gemini:
            return ["--prompt", injection]
        }
    }

    public static func environment(
        existing: [String],
        executable: URL,
        engine: AgentEngine,
        isolatedHome: URL
    ) -> [String] {
        var env = existing.isEmpty
            ? processEnvironment(executable: executable)
            : existing
        env.removeAll {
            $0.hasPrefix("CODEX_HOME=")
                || $0.hasPrefix("GROK_HOME=")
                || $0.hasPrefix("CLAUDE_CONFIG_DIR=")
                || $0.hasPrefix("GEMINI_CONFIG_DIR=")
        }
        switch engine {
        case .codex:
            env.append("CODEX_HOME=\(isolatedHome.path)")
        case .grok:
            env.append("GROK_HOME=\(isolatedHome.path)")
            env.append("GROK_MEMORY=0")
        case .claude:
            env.append("CLAUDE_CONFIG_DIR=\(isolatedHome.path)")
        case .gemini:
            env.append("GEMINI_CONFIG_DIR=\(isolatedHome.path)")
        }
        return env
    }

    public static func processEnvironment(executable: URL) -> [String] {
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let bin = executable.deletingLastPathComponent().path
        let extras = [
            bin,
            "\(home)/.grok/bin",
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
        ]
        let current = (env["PATH"] ?? "").split(separator: ":").map(String.init)
        var parts: [String] = []
        var seen = Set<String>()
        for item in extras + current where seen.insert(item).inserted && !item.isEmpty {
            parts.append(item)
        }
        env["PATH"] = parts.joined(separator: ":")
        env["HOME"] = env["HOME"] ?? home
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        return env.map { "\($0.key)=\($0.value)" }
    }
}
