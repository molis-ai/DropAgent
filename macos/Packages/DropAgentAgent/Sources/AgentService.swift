import Foundation
import os

public final class AgentService: AgentRunning, @unchecked Sendable {
    private let runner: CodexExecuting
    private let printCLI: PrintCLI
    private let fileManager: FileManager
    private let pathEnvironment: String
    private let home: URL
    private let helpByPath = OSAllocatedUnfairLock<[String: String]>(initialState: [:])
    public var settings: AgentSettings

    public init(
        runner: CodexExecuting,
        printCLI: PrintCLI = PrintCLI(),
        settings: AgentSettings = AgentSettings(),
        fileManager: FileManager = .default,
        pathEnvironment: String? = nil,
        home: URL? = nil
    ) {
        self.runner = runner
        self.printCLI = printCLI
        self.settings = settings
        self.fileManager = fileManager
        self.pathEnvironment = pathEnvironment ?? ProcessInfo.processInfo.environment["PATH"] ?? ""
        self.home = home ?? FileManager.default.homeDirectoryForCurrentUser
    }

    public func discover(settings: AgentSettings) -> AgentPresence {
        recipePresence(settings: settings)
    }

    public func recipePresence(settings: AgentSettings) -> AgentPresence {
        let tui = tuiPresence(settings: settings)
        guard let path = tui.executable else { return .none }
        let help = helpText(at: path)
        guard HeadlessCLI.canRunJob(presence: tui, help: help) else { return .none }
        let isolation: IsolationGrade
        if tui.engine == .codex {
            isolation = runner.supportsWorkspaceSandbox(at: path) ? .workspace : .unknown
        } else {
            isolation = .unknown
        }
        return tui.withIsolation(isolation)
    }

    public func tuiPresence(settings: AgentSettings) -> AgentPresence {
        let merged = merge(settings)
        let installed = installedEngines(settings: merged)
        if let id = merged.selectedCustomID {
            return installed.first { $0.runtimeKey == "custom:\(id)" } ?? .none
        }
        if let wanted = merged.tuiEngine.engine {
            return installed.first { $0.engine == wanted } ?? .none
        }
        for engine in AgentEngine.tuiCases {
            if let found = installed.first(where: { $0.engine == engine }) {
                return found
            }
        }
        for engine in AgentEngine.cliCases {
            if let found = installed.first(where: { $0.engine == engine }) {
                return found
            }
        }
        return installed.first { $0.engine == nil } ?? .none
    }

    public func installedEngines(settings: AgentSettings) -> [AgentPresence] {
        let merged = merge(settings)
        var found: [AgentPresence] = []
        for engine in AgentEngine.allCases {
            let item = presence(engine: engine, settings: merged, isolation: .tui)
            if item.executable != nil {
                found.append(item)
            }
        }
        for custom in merged.customRuntimes {
            let path = URL(fileURLWithPath: custom.executable)
            guard fileManager.isExecutableFile(atPath: path.path) else { continue }
            found.append(
                .custom(
                    id: custom.id,
                    title: custom.title,
                    path: path,
                    kind: custom.kind,
                    isolation: .tui
                )
            )
        }
        return found
    }

    public func isolationCopy(for presence: AgentPresence) -> String {
        switch presence.isolation {
        case .workspace:
            return "Workspace Sandbox：Agent 只能写任务工作区"
        case .unknown:
            return "未确认工作区限制，仍在副本目录跑"
        case .tui:
            return "在终端执行，不是副本沙箱"
        case .none:
            return "未发现 Agent"
        }
    }

    public func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        let presence = recipePresence(settings: settings)
        guard let path = presence.executable else { throw AgentError.notFound }
        let help = helpText(at: path)
        if presence.engine == .codex {
            return try await runner.exec(executable: path, request: request, onEvent: onEvent)
        }
        let arguments = HeadlessCLI.arguments(presence: presence, help: help, request: request, prompt: String(decoding: try Data(contentsOf: request.promptFile), as: UTF8.self))
        return try await printCLI.run(
            executable: path,
            arguments: arguments,
            request: request,
            onEvent: onEvent
        )
    }

    public func ensureInteractiveSession() throws -> SessionHandle {
        let presence = tuiPresence(settings: settings)
        guard let path = presence.executable else { throw AgentError.notFound }
        return SessionHandle(
            executable: path,
            arguments: [],
            environment: InteractiveLaunch.processEnvironment(executable: path)
        )
    }

    public func cancelCurrent() {
        runner.cancel()
        printCLI.cancel()
    }

    private func helpText(at url: URL) -> String {
        helpByPath.withLock { cache in
            if let cached = cache[url.path] { return cached }
            let text = HeadlessCLI.readHelp(at: url)
            cache[url.path] = text
            return text
        }
    }

    public static func candidates(settings: AgentSettings, pathEnvironment: String, home: URL) -> [URL] {
        candidates(engine: .codex, settings: settings, pathEnvironment: pathEnvironment, home: home)
    }

    public static func candidates(
        engine: AgentEngine,
        settings: AgentSettings,
        pathEnvironment: String,
        home: URL
    ) -> [URL] {
        var urls: [URL] = []
        if engine == .codex, let override = settings.executableOverride, !override.isEmpty {
            urls.append(URL(fileURLWithPath: override))
        }
        if let override = settings.tuiOverrides[engine.rawValue], !override.isEmpty {
            urls.append(URL(fileURLWithPath: override))
        }
        let binaryNames = engine.binaryNames
        var directories: [URL] = pathEnvironment.split(separator: ":").map {
            URL(fileURLWithPath: String($0), isDirectory: true)
        }
        directories.append(contentsOf: [
            home.appendingPathComponent(".grok/bin", isDirectory: true),
            home.appendingPathComponent(".local/bin", isDirectory: true),
            home.appendingPathComponent(".opencode/bin", isDirectory: true),
            home.appendingPathComponent(".cursor/bin", isDirectory: true),
            home.appendingPathComponent("bin", isDirectory: true),
            URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
            URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
        ])
        for directory in directories {
            for binary in binaryNames {
                urls.append(directory.appendingPathComponent(binary))
            }
        }
        if engine == .cursor {
            for directory in directories where directory.path.contains(".grok") == false {
                urls.append(directory.appendingPathComponent("agent"))
            }
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }
    }

    private func merge(_ settings: AgentSettings) -> AgentSettings {
        var merged = self.settings
        if let override = settings.executableOverride {
            merged.executableOverride = override
        }
        merged.tuiEngine = settings.tuiEngine
        merged.selectedCustomID = settings.selectedCustomID
        merged.customRuntimes = settings.customRuntimes
        if settings.tuiOverrides.isEmpty == false {
            merged.tuiOverrides = settings.tuiOverrides
        }
        return merged
    }

    private enum IsolationKind {
        case recipe
        case tui
    }

    private func presence(engine: AgentEngine, settings: AgentSettings, isolation kind: IsolationKind) -> AgentPresence {
        let candidates = Self.candidates(
            engine: engine,
            settings: settings,
            pathEnvironment: pathEnvironment,
            home: home
        )
        guard let path = candidates.first(where: { url in
            guard fileManager.isExecutableFile(atPath: url.path) else { return false }
            if engine == .cursor, url.lastPathComponent == "agent" {
                return AgentEngine.identified(
                    binaryName: url.lastPathComponent,
                    help: helpText(at: url),
                    path: url.path
                ) == .cursor
            }
            return true
        }) else {
            return .none
        }
        let isolation: IsolationGrade
        switch kind {
        case .tui:
            isolation = .tui
        case .recipe:
            isolation = engine == .codex && runner.supportsWorkspaceSandbox(at: path) ? .workspace : .unknown
        }
        return .installed(engine: engine, path: path, isolation: isolation)
    }
}
