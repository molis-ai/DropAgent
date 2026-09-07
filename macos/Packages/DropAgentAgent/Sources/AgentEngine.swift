import Foundation

public enum RuntimeKind: String, Codable, Sendable, Equatable {
    case tui
    case cli
}

public struct CustomRuntime: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var executable: String
    public var kind: RuntimeKind

    public init(id: String = UUID().uuidString, title: String, executable: String, kind: RuntimeKind) {
        self.id = id
        self.title = title
        self.executable = executable
        self.kind = kind
    }
}

public enum AgentEngine: String, Codable, CaseIterable, Sendable, Identifiable {
    case grok
    case claude
    case gemini
    case opencode
    case cursor
    case codex
    case llm
    case aichat
    case sgpt

    public var id: String { rawValue }

    public var kind: RuntimeKind {
        switch self {
        case .llm, .aichat, .sgpt: return .cli
        default: return .tui
        }
    }

    public static var tuiCases: [AgentEngine] { allCases.filter { $0.kind == .tui } }
    public static var cliCases: [AgentEngine] { allCases.filter { $0.kind == .cli } }

    public var shortTitle: String {
        switch self {
        case .grok: return "Grok"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .opencode: return "OpenCode"
        case .cursor: return "Cursor CLI"
        case .codex: return "Codex"
        case .llm: return "LLM"
        case .aichat: return "AIChat"
        case .sgpt: return "ShellGPT"
        }
    }

    public var binaryNames: [String] {
        switch self {
        case .cursor: return ["cursor-agent"]
        default: return [rawValue]
        }
    }

    public var binaryName: String { binaryNames[0] }

    public var installURL: URL {
        switch self {
        case .grok:
            return URL(string: "https://docs.x.ai/docs/build/overview")!
        case .claude:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code")!
        case .gemini:
            return URL(string: "https://github.com/google-gemini/gemini-cli")!
        case .opencode:
            return URL(string: "https://opencode.ai/docs/cli/")!
        case .cursor:
            return URL(string: "https://cursor.com/docs/cli/overview")!
        case .codex:
            return URL(string: "https://github.com/openai/codex")!
        case .llm:
            return URL(string: "https://llm.datasette.io")!
        case .aichat:
            return URL(string: "https://github.com/sigoden/aichat")!
        case .sgpt:
            return URL(string: "https://github.com/TheR1D/shell_gpt")!
        }
    }

    public static func identified(binaryName: String, help: String, path: String = "") -> AgentEngine? {
        let name = binaryName.lowercased()
        let lower = help.lowercased()
        let pathLower = path.lowercased()
        if name == "grok" || lower.contains("grok build") {
            return .grok
        }
        if name == "claude" || lower.contains("claude code") {
            return .claude
        }
        if name == "gemini" {
            return .gemini
        }
        if name == "opencode" || (lower.contains("opencode") && (lower.contains("--prompt") || lower.contains("run [message"))) {
            return .opencode
        }
        if name == "cursor-agent" {
            return .cursor
        }
        if name == "agent" {
            if pathLower.contains("/.grok/") || lower.contains("grok build") {
                return .grok
            }
            if lower.contains("cursor") {
                return .cursor
            }
        }
        if name == "codex" {
            return .codex
        }
        if name == "llm" {
            return .llm
        }
        if name == "aichat" {
            return .aichat
        }
        if name == "sgpt" {
            return .sgpt
        }
        return nil
    }

    public static func detectedKind(binaryName: String, help: String) -> RuntimeKind {
        if let engine = identified(binaryName: binaryName, help: help) {
            return engine.kind
        }
        let lower = help.lowercased()
        if lower.contains("terminal user interface") || lower.contains(" tui") || lower.contains("interactive session") {
            return .tui
        }
        if ["llm", "aichat", "sgpt"].contains(binaryName.lowercased()) {
            return .cli
        }
        return .tui
    }
}
