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

public protocol CodexExecuting: Sendable {
    func supportsWorkspaceSandbox(at executable: URL) -> Bool
    func exec(executable: URL, request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult
    func cancel()
}

public final class CodexCLI: CodexExecuting, @unchecked Sendable {
    private let running = OSAllocatedUnfairLock<Process?>(initialState: nil)

    public init() {}

    public func cancel() {
        running.withLock { $0?.terminate() }
    }

    public func supportsWorkspaceSandbox(at executable: URL) -> Bool {
        let process = Process()
        process.executableURL = executable
        process.arguments = ["exec", "--help"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = out
        do {
            try process.run()
        } catch {
            return false
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
            return false
        }
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return text.contains("--sandbox") && text.contains("workspace-write")
    }

    public func exec(executable: URL, request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        let prompt = String(decoding: try Data(contentsOf: request.promptFile), as: UTF8.self)
        let arguments = CodexCLI.execArguments(request: request, prompt: prompt)

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = request.workdir
        process.environment = CodexCLI.recipeEnvironment(executable: executable)
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err

        let collected = OSAllocatedUnfairLock<[AgentEvent]>(initialState: [])
        let leftover = OSAllocatedUnfairLock<Data>(initialState: Data())
        let stdoutHandle = out.fileHandleForReading
        stdoutHandle.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            leftover.withLock { buffer in
                buffer.append(chunk)
                while let range = buffer.firstRange(of: Data([0x0A])) {
                    let line = Data(buffer[..<range.lowerBound])
                    buffer.removeSubrange(..<range.upperBound)
                    if let event = CodexJSONL.event(from: line) {
                        collected.withLock { $0.append(event) }
                        onEvent?(event)
                    }
                }
            }
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AgentRunResult, Error>) in
                let resumed = OSAllocatedUnfairLock(initialState: false)
                @Sendable func finish(_ result: Result<AgentRunResult, Error>) {
                    guard resumed.withLock({ taken in
                        if taken { return false }
                        taken = true
                        return true
                    }) else { return }
                    continuation.resume(with: result)
                }
                process.terminationHandler = { finished in
                    stdoutHandle.readabilityHandler = nil
                    self.running.withLock { current in
                        if current === process { current = nil }
                    }
                    leftover.withLock { buffer in
                        let tail = stdoutHandle.readDataToEndOfFile()
                        if !tail.isEmpty { buffer.append(tail) }
                        if !buffer.isEmpty, let event = CodexJSONL.event(from: buffer) {
                            collected.withLock { $0.append(event) }
                            onEvent?(event)
                        }
                    }
                    let stderr = err.fileHandleForReading.readDataToEndOfFile()
                    for extra in CodexJSONL.events(from: String(decoding: stderr, as: UTF8.self)) {
                        collected.withLock { $0.append(extra) }
                        onEvent?(extra)
                    }
                    let events = collected.withLock { $0 }
                    let last: String
                    if let existing = try? String(contentsOf: request.outputFile, encoding: .utf8) {
                        last = existing
                    } else {
                        last = events.last?.message ?? ""
                        try? last.write(to: request.outputFile, atomically: true, encoding: .utf8)
                    }
                    if finished.terminationReason == .uncaughtSignal {
                        finish(.failure(AgentError.cancelled))
                        return
                    }
                    if finished.terminationStatus != 0 && last.isEmpty {
                        finish(.failure(AgentError.failed(finished.terminationStatus)))
                        return
                    }
                    finish(.success(AgentRunResult(
                        exitCode: finished.terminationStatus,
                        events: events,
                        lastMessage: last
                    )))
                }
                self.running.withLock { $0 = process }
                do {
                    try process.run()
                } catch {
                    stdoutHandle.readabilityHandler = nil
                    self.running.withLock { current in
                        if current === process { current = nil }
                    }
                    finish(.failure(error))
                }
            }
        } onCancel: {
            process.terminate()
        }
    }

    public static func recipeEnvironment(executable: URL) -> [String: String] {
        let bin = executable.deletingLastPathComponent().path
        var env: [String: String] = [
            "PATH": "\(bin):/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "LANG": "en_US.UTF-8",
        ]
        if let user = ProcessInfo.processInfo.environment["USER"] {
            env["USER"] = user
        }
        return env
    }

    public static func interactiveEnvironment(executable: URL) -> [String] {
        InteractiveLaunch.processEnvironment(executable: executable)
    }

    public static func execArguments(request: AgentRunRequest, prompt: String) -> [String] {
        var arguments = [
            "exec",
            "--ephemeral",
            "--ignore-user-config",
            "--ignore-rules",
            "--skip-git-repo-check",
            "--json",
            "--cd", request.workdir.path,
            "--output-last-message", request.outputFile.path,
        ]
        if request.isolation == .workspace {
            arguments.append(contentsOf: ["--sandbox", "workspace-write"])
            if request.network {
                arguments.append(contentsOf: ["-c", "sandbox_workspace_write.network_access=true"])
            }
        }
        arguments.append(prompt)
        return arguments
    }
}

public enum CodexJSONL {
    public static func event(from line: Data) -> AgentEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            return nil
        }
        if let message = object["message"] as? String, !message.isEmpty, isHuman(message) {
            return AgentEvent(message: message)
        }
        guard let type = object["type"] as? String, !type.isEmpty else {
            return nil
        }
        if shouldIgnore(type) { return nil }
        let item = object["item"] as? [String: Any]
        let itemType = ((item?["type"] as? String) ?? "").lowercased()
        guard let text = display(type: type, itemType: itemType) else {
            return nil
        }
        return AgentEvent(message: text)
    }

    public static func events(from text: String) -> [AgentEvent] {
        text.split(separator: "\n").compactMap { line in
            event(from: Data(line.utf8))
        }
    }

    private static func isHuman(_ message: String) -> Bool {
        if message.contains(where: { $0 >= "\u{4e00}" && $0 <= "\u{9fff}" }) { return true }
        if message.contains(" ") { return true }
        if message.contains(".") { return false }
        return true
    }

    private static func shouldIgnore(_ type: String) -> Bool {
        type.contains("token") || type.hasPrefix("event_msg") || type.hasSuffix(".delta")
    }

    private static func display(type: String, itemType: String) -> String? {
        let lowered = type.lowercased()
        if lowered.contains("approval") || lowered.contains("auth") {
            return "等待授权"
        }
        if lowered.contains("error") || lowered.contains("failed") {
            return "失败"
        }
        switch lowered {
        case "thread.started", "turn.started":
            return "开始运行"
        case "turn.completed", "thread.completed":
            return "收尾"
        case "agent_message", "message":
            return "在写结果"
        case "item.started":
            return itemStarted(itemType)
        case "item.completed":
            return itemCompleted(itemType)
        default:
            return nil
        }
    }

    private static func itemStarted(_ itemType: String) -> String {
        if itemType.contains("search") || itemType.contains("web") {
            return "联网"
        }
        if itemType.contains("command") || itemType.contains("shell") || itemType.contains("mcp") || itemType.contains("tool") {
            return "工具调用"
        }
        if itemType.contains("file") || itemType.contains("patch") {
            return "在写文件"
        }
        if itemType.contains("message") {
            return "在写结果"
        }
        if itemType.contains("reason") {
            return "思考中"
        }
        return "进行中"
    }

    private static func itemCompleted(_ itemType: String) -> String? {
        if itemType.contains("command") || itemType.contains("shell") {
            return "工具调用完成"
        }
        if itemType.contains("message") {
            return "在写结果"
        }
        return nil
    }
}
