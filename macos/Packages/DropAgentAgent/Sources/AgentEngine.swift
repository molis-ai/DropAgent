import Foundation

public enum AgentEngine: String, Codable, CaseIterable, Sendable, Identifiable {
    case grok
    case claude
    case gemini
    case codex

    public var id: String { rawValue }

    public var shortTitle: String {
        switch self {
        case .grok: return "Grok"
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        }
    }

    public var binaryName: String { rawValue }

    public var installURL: URL {
        switch self {
        case .grok:
            return URL(string: "https://docs.x.ai/docs/build/overview")!
        case .claude:
            return URL(string: "https://docs.anthropic.com/en/docs/claude-code")!
        case .gemini:
            return URL(string: "https://github.com/google-gemini/gemini-cli")!
        case .codex:
            return URL(string: "https://github.com/openai/codex")!
        }
    }
}

public enum TUIEnginePreference: String, Codable, CaseIterable, Sendable {
    case auto
    case grok
    case claude
    case gemini
    case codex

    public var engine: AgentEngine? {
        switch self {
        case .auto: return nil
        case .grok: return .grok
        case .claude: return .claude
        case .gemini: return .gemini
        case .codex: return .codex
        }
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
    case codex(path: URL, isolation: IsolationGrade)
    case grok(path: URL, isolation: IsolationGrade)
    case claude(path: URL, isolation: IsolationGrade)
    case gemini(path: URL, isolation: IsolationGrade)

    public var executable: URL? {
        switch self {
        case .none: return nil
        case .codex(let path, _), .grok(let path, _), .claude(let path, _), .gemini(let path, _):
            return path
        }
    }

    public var isolation: IsolationGrade {
        switch self {
        case .none: return .none
        case .codex(_, let isolation), .grok(_, let isolation), .claude(_, let isolation), .gemini(_, let isolation):
            return isolation
        }
    }

    public var engine: AgentEngine? {
        switch self {
        case .none: return nil
        case .codex: return .codex
        case .grok: return .grok
        case .claude: return .claude
        case .gemini: return .gemini
        }
    }

    public var shortTitle: String { engine?.shortTitle ?? "Agent" }

    public static func installed(engine: AgentEngine, path: URL, isolation: IsolationGrade) -> AgentPresence {
        switch engine {
        case .codex: return .codex(path: path, isolation: isolation)
        case .grok: return .grok(path: path, isolation: isolation)
        case .claude: return .claude(path: path, isolation: isolation)
        case .gemini: return .gemini(path: path, isolation: isolation)
        }
    }
}

public struct AgentSettings: Codable, Equatable, Sendable {
    public var executableOverride: String?
    public var tuiEngine: TUIEnginePreference
    public var tuiOverrides: [String: String]

    public init(
        executableOverride: String? = nil,
        tuiEngine: TUIEnginePreference = .auto,
        tuiOverrides: [String: String] = [:]
    ) {
        self.executableOverride = executableOverride
        self.tuiEngine = tuiEngine
        self.tuiOverrides = tuiOverrides
    }

    enum CodingKeys: String, CodingKey {
        case executableOverride
        case tuiEngine
        case tuiOverrides
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        executableOverride = try container.decodeIfPresent(String.self, forKey: .executableOverride)
        tuiEngine = try container.decodeIfPresent(TUIEnginePreference.self, forKey: .tuiEngine) ?? .auto
        tuiOverrides = try container.decodeIfPresent([String: String].self, forKey: .tuiOverrides) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(executableOverride, forKey: .executableOverride)
        try container.encode(tuiEngine, forKey: .tuiEngine)
        if tuiOverrides.isEmpty == false {
            try container.encode(tuiOverrides, forKey: .tuiOverrides)
        }
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
