import Foundation
import os

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
