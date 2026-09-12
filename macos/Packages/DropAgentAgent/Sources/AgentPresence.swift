import Foundation

public enum TUIEnginePreference: String, Codable, CaseIterable, Sendable {
    case auto
    case grok
    case claude
    case gemini
    case opencode
    case cursor
    case codex
    case kimi
    case codebuddy
    case qwen

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
    case kimi(path: URL, isolation: IsolationGrade)
    case codebuddy(path: URL, isolation: IsolationGrade)
    case qwen(path: URL, isolation: IsolationGrade)
    case custom(id: String, title: String, path: URL, kind: RuntimeKind, isolation: IsolationGrade)

    public var executable: URL? {
        switch self {
        case .none:
            return nil
        case .custom(_, _, let path, _, _):
            return path
        case .grok(let path, _), .claude(let path, _), .gemini(let path, _), .opencode(let path, _),
             .cursor(let path, _), .codex(let path, _), .kimi(let path, _), .codebuddy(let path, _), .qwen(let path, _):
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
             .kimi(_, let isolation), .codebuddy(_, let isolation), .qwen(_, let isolation):
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
        case .kimi: return .kimi
        case .codebuddy: return .codebuddy
        case .qwen: return .qwen
        }
    }

    public var kind: RuntimeKind {
        switch self {
        case .custom(_, _, _, let kind, _): return kind
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
        case .kimi: return .kimi(path: path, isolation: isolation)
        case .codebuddy: return .codebuddy(path: path, isolation: isolation)
        case .qwen: return .qwen(path: path, isolation: isolation)
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
