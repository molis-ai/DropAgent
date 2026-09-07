import Foundation

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
