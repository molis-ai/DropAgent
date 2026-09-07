import Foundation

public enum HeadlessCLI {
    public static func canRunJob(engine: AgentEngine, help: String) -> Bool {
        switch engine {
        case .codex:
            return help.range(of: #"\bexec\b"#, options: .regularExpression) != nil
        case .grok:
            return containsFlag(help, "--prompt-file") || containsFlag(help, "--single")
        case .claude, .cursor:
            return containsFlag(help, "--print") || help.contains("-p,") || help.contains("-p ")
        case .gemini:
            return containsFlag(help, "--prompt")
        case .opencode:
            return hasRunCommand(help)
        case .llm, .aichat, .sgpt:
            return true
        }
    }

    public static func canRunJob(presence: AgentPresence, help: String) -> Bool {
        if let engine = presence.engine {
            return canRunJob(engine: engine, help: help)
        }
        switch presence.kind {
        case .cli:
            return true
        case .tui:
            return containsFlag(help, "--print")
                || containsFlag(help, "--prompt-file")
                || containsFlag(help, "--prompt")
                || hasRunCommand(help)
        }
    }

    public static func arguments(
        engine: AgentEngine,
        help: String,
        request: AgentRunRequest,
        prompt: String
    ) -> [String] {
        switch engine {
        case .codex:
            return CodexCLI.execArguments(request: request, prompt: prompt)
        case .grok:
            return grokArguments(help: help, request: request, prompt: prompt)
        case .claude:
            return claudeArguments(help: help, request: request, prompt: prompt)
        case .gemini:
            return geminiArguments(help: help, request: request, prompt: prompt)
        case .opencode:
            return opencodeArguments(help: help, request: request, prompt: prompt)
        case .cursor:
            return cursorArguments(help: help, prompt: prompt)
        case .llm, .aichat, .sgpt:
            return [prompt]
        }
    }

    public static func arguments(
        presence: AgentPresence,
        help: String,
        request: AgentRunRequest,
        prompt: String
    ) -> [String] {
        if let engine = presence.engine {
            return arguments(engine: engine, help: help, request: request, prompt: prompt)
        }
        if presence.kind == .cli {
            if containsFlag(help, "--print") {
                return ["--print", prompt]
            }
            return [prompt]
        }
        if hasRunCommand(help) {
            return opencodeArguments(help: help, request: request, prompt: prompt)
        }
        if containsFlag(help, "--print") {
            return claudeArguments(help: help, request: request, prompt: prompt)
        }
        if containsFlag(help, "--prompt") {
            return geminiArguments(help: help, request: request, prompt: prompt)
        }
        return []
    }

    public static func readHelp(at executable: URL) -> String {
        runHelp(executable: executable, arguments: ["--help"])
    }

    public static func containsFlag(_ help: String, _ token: String) -> Bool {
        help.contains(token)
    }

    private static func grokArguments(help: String, request: AgentRunRequest, prompt: String) -> [String] {
        var arguments: [String] = []
        if containsFlag(help, "--cwd") {
            arguments.append(contentsOf: ["--cwd", request.workdir.path])
        }
        if containsFlag(help, "--prompt-file") {
            arguments.append(contentsOf: ["--prompt-file", request.promptFile.path])
        } else if containsFlag(help, "--single") {
            arguments.append(contentsOf: ["--single", prompt])
        }
        if containsFlag(help, "--output-format") {
            arguments.append(contentsOf: ["--output-format", "plain"])
        }
        return arguments
    }

    private static func claudeArguments(help: String, request: AgentRunRequest, prompt: String) -> [String] {
        var arguments: [String] = []
        if containsFlag(help, "--print") {
            arguments.append("--print")
        }
        if containsFlag(help, "--output-format") {
            arguments.append(contentsOf: ["--output-format", "text"])
        }
        if containsFlag(help, "--add-dir") {
            arguments.append(contentsOf: ["--add-dir", request.workdir.path])
        }
        arguments.append(prompt)
        return arguments
    }

    private static func geminiArguments(help: String, request: AgentRunRequest, prompt: String) -> [String] {
        _ = request
        var arguments: [String] = []
        if containsFlag(help, "--prompt") {
            arguments.append(contentsOf: ["--prompt", prompt])
        } else if containsFlag(help, "-p") {
            arguments.append(contentsOf: ["-p", prompt])
        }
        return arguments
    }

    private static func opencodeArguments(help: String, request: AgentRunRequest, prompt: String) -> [String] {
        var arguments = ["run"]
        if containsFlag(help, "--dir") {
            arguments.append(contentsOf: ["--dir", request.workdir.path])
        }
        arguments.append(prompt)
        return arguments
    }

    private static func cursorArguments(help: String, prompt: String) -> [String] {
        if containsFlag(help, "--print") {
            return ["--print", prompt]
        }
        if help.contains("-p,") || help.contains("-p ") {
            return ["-p", prompt]
        }
        return []
    }

    private static func hasRunCommand(_ help: String) -> Bool {
        help.contains("run [message")
            || help.contains("opencode run")
            || help.range(of: #"(?m)^\s+run\b"#, options: .regularExpression) != nil
    }

    private static func runHelp(executable: URL, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        do {
            try process.run()
        } catch {
            return ""
        }
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            finished.signal()
        }
        if finished.wait(timeout: .now() + 3) == .timedOut {
            process.terminate()
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            return ""
        }
        return String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }
}
