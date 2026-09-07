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

public enum TUIEnginePreference: String, Codable, CaseIterable, Sendable {
    case auto
    case grok
    case claude
    case gemini
    case opencode
    case cursor
    case codex
    case llm
    case aichat
    case sgpt

    public var engine: AgentEngine? {
        AgentEngine(rawValue: rawValue)
    }

    public var menuTitle: String {
        switch self {
        case .auto: return "自动"
        default: return engine?.shortTitle ?? rawValue
        }
    }
}

public enum IsolationGrade: String, Sendable, Equatable {
    case workspace
    case unknown
    case none
    case tui
}

public enum AgentPresence: Equatable, Sendable {
    case none
    case grok(path: URL, isolation: IsolationGrade)
    case claude(path: URL, isolation: IsolationGrade)
    case gemini(path: URL, isolation: IsolationGrade)
    case opencode(path: URL, isolation: IsolationGrade)
    case cursor(path: URL, isolation: IsolationGrade)
    case codex(path: URL, isolation: IsolationGrade)
    case llm(path: URL, isolation: IsolationGrade)
    case aichat(path: URL, isolation: IsolationGrade)
    case sgpt(path: URL, isolation: IsolationGrade)
    case custom(id: String, title: String, path: URL, kind: RuntimeKind, isolation: IsolationGrade)

    public var executable: URL? {
        switch self {
        case .none:
            return nil
        case .custom(_, _, let path, _, _):
            return path
        case .grok(let path, _), .claude(let path, _), .gemini(let path, _), .opencode(let path, _),
             .cursor(let path, _), .codex(let path, _), .llm(let path, _), .aichat(let path, _), .sgpt(let path, _):
            return path
        }
    }

    public var isolation: IsolationGrade {
        switch self {
        case .none:
            return .none
        case .custom(_, _, _, _, let isolation):
            return isolation
        case .grok(_, let isolation), .claude(_, let isolation), .gemini(_, let isolation),
             .opencode(_, let isolation), .cursor(_, let isolation), .codex(_, let isolation),
             .llm(_, let isolation), .aichat(_, let isolation), .sgpt(_, let isolation):
            return isolation
        }
    }

    public var engine: AgentEngine? {
        switch self {
        case .none, .custom: return nil
        case .grok: return .grok
        case .claude: return .claude
        case .gemini: return .gemini
        case .opencode: return .opencode
        case .cursor: return .cursor
        case .codex: return .codex
        case .llm: return .llm
        case .aichat: return .aichat
        case .sgpt: return .sgpt
        }
    }

    public var kind: RuntimeKind {
        switch self {
        case .custom(_, _, _, let kind, _): return kind
        case .llm, .aichat, .sgpt: return .cli
        default: return .tui
        }
    }

    public var runtimeKey: String {
        switch self {
        case .none: return ""
        case .custom(let id, _, _, _, _): return "custom:\(id)"
        default: return engine?.rawValue ?? ""
        }
    }

    public var homeKey: String {
        switch self {
        case .custom(let id, _, _, _, _): return "custom-\(id)"
        default: return engine?.rawValue ?? "runtime"
        }
    }

    public var shortTitle: String {
        switch self {
        case .custom(_, let title, _, _, _): return title
        default: return engine?.shortTitle ?? "Agent"
        }
    }

    public static func installed(engine: AgentEngine, path: URL, isolation: IsolationGrade) -> AgentPresence {
        switch engine {
        case .grok: return .grok(path: path, isolation: isolation)
        case .claude: return .claude(path: path, isolation: isolation)
        case .gemini: return .gemini(path: path, isolation: isolation)
        case .opencode: return .opencode(path: path, isolation: isolation)
        case .cursor: return .cursor(path: path, isolation: isolation)
        case .codex: return .codex(path: path, isolation: isolation)
        case .llm: return .llm(path: path, isolation: isolation)
        case .aichat: return .aichat(path: path, isolation: isolation)
        case .sgpt: return .sgpt(path: path, isolation: isolation)
        }
    }

    public func withIsolation(_ isolation: IsolationGrade) -> AgentPresence {
        switch self {
        case .none:
            return .none
        case .custom(let id, let title, let path, let kind, _):
            return .custom(id: id, title: title, path: path, kind: kind, isolation: isolation)
        default:
            guard let engine, let path = executable else { return .none }
            return .installed(engine: engine, path: path, isolation: isolation)
        }
    }
}

public struct AgentSettings: Codable, Equatable, Sendable {
    public var executableOverride: String?
    public var tuiEngine: TUIEnginePreference
    public var tuiOverrides: [String: String]
    public var customRuntimes: [CustomRuntime]
    public var selectedCustomID: String?

    public init(
        executableOverride: String? = nil,
        tuiEngine: TUIEnginePreference = .auto,
        tuiOverrides: [String: String] = [:],
        customRuntimes: [CustomRuntime] = [],
        selectedCustomID: String? = nil
    ) {
        self.executableOverride = executableOverride
        self.tuiEngine = tuiEngine
        self.tuiOverrides = tuiOverrides
        self.customRuntimes = customRuntimes
        self.selectedCustomID = selectedCustomID
    }

    enum CodingKeys: String, CodingKey {
        case executableOverride
        case tuiEngine
        case tuiOverrides
        case customRuntimes
        case selectedCustomID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        executableOverride = try container.decodeIfPresent(String.self, forKey: .executableOverride)
        tuiEngine = try container.decodeIfPresent(TUIEnginePreference.self, forKey: .tuiEngine) ?? .auto
        tuiOverrides = try container.decodeIfPresent([String: String].self, forKey: .tuiOverrides) ?? [:]
        customRuntimes = try container.decodeIfPresent([CustomRuntime].self, forKey: .customRuntimes) ?? []
        selectedCustomID = try container.decodeIfPresent(String.self, forKey: .selectedCustomID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(executableOverride, forKey: .executableOverride)
        try container.encode(tuiEngine, forKey: .tuiEngine)
        if tuiOverrides.isEmpty == false {
            try container.encode(tuiOverrides, forKey: .tuiOverrides)
        }
        if customRuntimes.isEmpty == false {
            try container.encode(customRuntimes, forKey: .customRuntimes)
        }
        try container.encodeIfPresent(selectedCustomID, forKey: .selectedCustomID)
    }
}

public struct AgentRunRequest: Equatable, Sendable {
    public var workdir: URL
    public var promptFile: URL
    public var outputFile: URL
    public var isolation: IsolationGrade
    public var network: Bool

    public init(
        workdir: URL,
        promptFile: URL,
        outputFile: URL,
        isolation: IsolationGrade,
        network: Bool = false
    ) {
        self.workdir = workdir
        self.promptFile = promptFile
        self.outputFile = outputFile
        self.isolation = isolation
        self.network = network
    }
}

public struct AgentEvent: Equatable, Sendable {
    public var message: String

    public init(message: String) {
        self.message = message
    }
}

public struct AgentRunResult: Equatable, Sendable {
    public var exitCode: Int32
    public var events: [AgentEvent]
    public var lastMessage: String

    public init(exitCode: Int32, events: [AgentEvent], lastMessage: String) {
        self.exitCode = exitCode
        self.events = events
        self.lastMessage = lastMessage
    }
}

public struct SessionHandle: Equatable, Sendable {
    public var executable: URL
    public var arguments: [String]
    public var environment: [String]

    public init(executable: URL, arguments: [String] = [], environment: [String] = []) {
        self.executable = executable
        self.arguments = arguments
        self.environment = environment
    }
}

public enum AgentError: Error, Equatable, Sendable {
    case notFound
    case failed(Int32)
    case cancelled
}

public protocol AgentRunning: Sendable {
    var settings: AgentSettings { get }
    func discover(settings: AgentSettings) -> AgentPresence
    func recipePresence(settings: AgentSettings) -> AgentPresence
    func tuiPresence(settings: AgentSettings) -> AgentPresence
    func installedEngines(settings: AgentSettings) -> [AgentPresence]
    func isolationCopy(for presence: AgentPresence) -> String
    func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult
    func ensureInteractiveSession() throws -> SessionHandle
    func cancelCurrent()
}

public extension AgentRunning {
    func recipePresence(settings: AgentSettings) -> AgentPresence {
        discover(settings: settings)
    }

    func tuiPresence(settings: AgentSettings) -> AgentPresence {
        discover(settings: settings)
    }

    func installedEngines(settings: AgentSettings) -> [AgentPresence] {
        let found = discover(settings: settings)
        return found.executable == nil ? [] : [found]
    }
}
