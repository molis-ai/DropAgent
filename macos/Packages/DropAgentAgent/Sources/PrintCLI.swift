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
        process.standardInput = FileHandle.nullDevice
        let stdoutData = OSAllocatedUnfairLock(initialState: Data())
        let stderrData = OSAllocatedUnfairLock(initialState: Data())
        let drains = DispatchGroup()
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
                    drains.wait()
                    let stdout = String(decoding: stdoutData.withLock { $0 }, as: UTF8.self)
                    let stderr = String(decoding: stderrData.withLock { $0 }, as: UTF8.self)
                    if finished.terminationReason == .uncaughtSignal {
                        finish(.failure(AgentError.cancelled))
                        return
                    }
                    if finished.terminationStatus != 0 {
                        if !stderr.isEmpty { onEvent?(AgentEvent(message: "任务失败，请检查终端登录或权限")) }
                        finish(.failure(AgentError.failed(finished.terminationStatus)))
                        return
                    }
                    let last: String
                    if let existing = try? String(contentsOf: request.outputFile, encoding: .utf8),
                       existing.isEmpty == false {
                        last = existing
                    } else {
                        let format = arguments.firstIndex(of: "--output-format").flatMap { index in
                            arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
                        }
                        if format == "streaming-messages-json" {
                            // The result record is the CLI's final reply. Assistant tool-call
                            // preambles and thinking blocks are progress, never deliverables.
                            let records = stdout.split(whereSeparator: \.isNewline).compactMap { line in
                                try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
                            }
                            guard let result = records.last(where: { $0["type"] as? String == "result" }),
                                  result["is_error"] as? Bool == false,
                                  result["subtype"] as? String == "success",
                                  let text = result["result"] as? String else {
                                onEvent?(AgentEvent(message: "任务失败：终端没有返回完整的最终结果"))
                                finish(.failure(AgentError.failed(-1)))
                                return
                            }
                            last = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if format == "json" {
                            guard let object = try? JSONSerialization.jsonObject(with: Data(stdout.utf8)) as? [String: Any],
                                  let text = object["text"] as? String else {
                                onEvent?(AgentEvent(message: "任务失败：终端没有返回可读取的最终结果"))
                                finish(.failure(AgentError.failed(-1)))
                                return
                            }
                            last = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            last = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if last.isEmpty == false {
                            try? last.write(to: request.outputFile, atomically: true, encoding: .utf8)
                        }
                    }
                    finish(.success(AgentRunResult(
                        exitCode: finished.terminationStatus,
                        events: [AgentEvent(message: "开始运行")],
                        lastMessage: last
                    )))
                }
                self.running.withLock { $0 = process }
                do {
                    // Start draining both pipes immediately. Waiting for termination first can
                    // deadlock once a CLI writes more than the OS pipe buffer can hold.
                    drains.enter()
                    drains.enter()
                    try process.run()
                    DispatchQueue.global(qos: .utility).async {
                        var pending = Data()
                        while true {
                            let data = out.fileHandleForReading.availableData
                            if data.isEmpty { break }
                            stdoutData.withLock { $0.append(data) }
                            if arguments.contains("streaming-messages-json") {
                                pending.append(data)
                                while let newline = pending.firstIndex(of: 10) {
                                    let line = Data(pending[..<newline])
                                    pending.removeSubrange(...newline)
                                    if let event = Self.progressEvent(line) { onEvent?(event) }
                                }
                            }
                        }
                        drains.leave()
                    }
                    DispatchQueue.global(qos: .utility).async {
                        let data = err.fileHandleForReading.readDataToEndOfFile()
                        stderrData.withLock { $0 = data }
                        drains.leave()
                    }
                } catch {
                    // No reader was started when launch failed. Balance the reservations
                    // so the dispatch group can be released and the same runner can retry.
                    drains.leave()
                    drains.leave()
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
    private static func progressEvent(_ line: Data) -> AgentEvent? {
        guard let record = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return nil }
        if record["type"] as? String == "result" { return AgentEvent(message: "正在收取结果") }
        guard record["type"] as? String == "assistant",
              let message = record["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]],
              let tool = content.first(where: { $0["type"] as? String == "tool_use" }),
              let name = tool["name"] as? String else { return nil }
        let text: String
        switch name {
        case "read_file": text = "正在读取材料"
        case "list_dir", "glob", "search": text = "正在查找任务材料"
        case "write_file", "edit_file", "apply_patch": text = "正在整理交付文件"
        default: text = "Agent 正在处理材料"
        }
        return AgentEvent(message: text)
    }

}
