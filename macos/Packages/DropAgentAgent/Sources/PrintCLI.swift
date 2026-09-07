import Foundation
import os

public final class PrintCLI: @unchecked Sendable {
    private let running = OSAllocatedUnfairLock<Process?>(initialState: nil)

    public init() {}

    public func cancel() {
        running.withLock { $0?.terminate() }
    }

    public func run(
        executable: URL,
        arguments: [String],
        request: AgentRunRequest,
        onEvent: (@Sendable (AgentEvent) -> Void)?
    ) async throws -> AgentRunResult {
        guard arguments.isEmpty == false else {
            throw AgentError.notFound
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = request.workdir
        process.environment = CodexCLI.recipeEnvironment(executable: executable)
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        onEvent?(AgentEvent(message: "开始运行"))

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
                    self.running.withLock { current in
                        if current === process { current = nil }
                    }
                    let stdout = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    let stderr = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                    let last: String
                    if let existing = try? String(contentsOf: request.outputFile, encoding: .utf8),
                       existing.isEmpty == false {
                        last = existing
                    } else {
                        last = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                        if last.isEmpty == false {
                            try? last.write(to: request.outputFile, atomically: true, encoding: .utf8)
                        }
                    }
                    if finished.terminationReason == .uncaughtSignal {
                        finish(.failure(AgentError.cancelled))
                        return
                    }
                    if finished.terminationStatus != 0 && last.isEmpty {
                        let reason = stderr.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
                        if reason.isEmpty == false {
                            onEvent?(AgentEvent(message: "失败"))
                        }
                        finish(.failure(AgentError.failed(finished.terminationStatus)))
                        return
                    }
                    finish(.success(AgentRunResult(
                        exitCode: finished.terminationStatus,
                        events: [AgentEvent(message: "开始运行")],
                        lastMessage: last
                    )))
                }
                self.running.withLock { $0 = process }
                do {
                    try process.run()
                } catch {
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
}
