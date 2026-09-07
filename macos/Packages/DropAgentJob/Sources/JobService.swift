import CryptoKit
import DropAgentAgent
import DropAgentShelf
import Foundation
import os

public struct JobID: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
}

public struct JobRecord: Equatable, Sendable {
    public var id: JobID
    public var recipe: RecipeID
    public var itemIDs: [ItemID]
    public var directory: URL
    public var outputFile: URL
}

public enum JobError: Error, Equatable, Sendable {
    case noAgent
    case emptySelection
    case notStartable
    case missingItem
}

public struct JobService: Sendable {
    private let shelf: ShelfStore
    private let agent: AgentRunning
    private let jobsRoot: URL
    private let control = JobControl()

    public init(shelf: ShelfStore, agent: AgentRunning, jobsRoot: URL) {
        self.shelf = shelf
        self.agent = agent
        self.jobsRoot = jobsRoot
    }

    public func cancel() {
        control.markCancelled()
        agent.cancelCurrent()
    }

    public func start(itemIDs: [ItemID], recipe: RecipeID) async throws -> JobID {
        guard !itemIDs.isEmpty else { throw JobError.emptySelection }
        let presence = agent.discover(settings: agent.settings)
        guard presence.executable != nil else { throw JobError.noAgent }
        let spec = RecipeCatalog.spec(recipe)
        control.begin()

        var items: [Item] = []
        for id in itemIDs {
            guard let item = shelf.item(id: id) else { throw JobError.missingItem }
            guard item.status == .idle || item.status == .confirm || item.status == .failed else {
                throw JobError.notStartable
            }
            guard spec.acceptedKinds.contains(item.kind) else {
                throw JobError.notStartable
            }
            items.append(item)
        }
        guard items.count >= recipe.minimumCount else { throw JobError.notStartable }
        let jobID = JobID()
        let dir = jobsRoot.appendingPathComponent(jobID.rawValue, isDirectory: true)
        let input = dir.appendingPathComponent("input", isDirectory: true)
        let work = dir.appendingPathComponent("work", isDirectory: true)
        let output = dir.appendingPathComponent("output", isDirectory: true)
        try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        var relativeNames: [String] = []
        for item in items {
            for part in item.parts {
                let destInput = uniqueURL(in: input, preferredName: part.name)
                let destWork = uniqueURL(in: work, preferredName: part.name)
                try copyRegular(from: part.url, to: destInput)
                try copyRegular(from: part.url, to: destWork)
                relativeNames.append(destWork.lastPathComponent)
            }
            try shelf.patch(id: item.id) { live in
                live.status = .running
                live.recipe = spec.fullTitle
                live.event = "复制到 input/ 与 work/"
                live.isolationShown = Self.shown(for: presence.isolation)
                live.failureReason = nil
            }
        }
        try freezeReadOnly(at: input)

        let promptFile = dir.appendingPathComponent("prompt.txt")
        let listed = relativeNames.map { "- \($0)" }.joined(separator: "\n")
        let prompt = spec.prompt + "\n\n材料：\n" + listed + "\n"
        try Data(prompt.utf8).write(to: promptFile)
        let outputFile = output.appendingPathComponent(spec.outputFileName)
        try appendEvent(dir: dir, message: "复制到 input/ 与 work/")
        try writeManifest(
            dir: dir,
            jobID: jobID,
            recipe: recipe,
            agent: presence.engine?.rawValue ?? "none",
            isolation: presence.isolation,
            items: items
        )

        let request = AgentRunRequest(
            workdir: work,
            promptFile: promptFile,
            outputFile: outputFile,
            isolation: presence.isolation,
            network: spec.needsNetwork
        )
        let runningIDs = items.map(\.id)

        do {
            if control.isCancelled {
                throw AgentError.cancelled
            }
            let result = try await agent.run(request) { event in
                let text = Self.displayEvent(event.message)
                try? appendEvent(dir: dir, message: event.message)
                for id in runningIDs {
                    try? shelf.patch(id: id) { live in
                        guard live.status == .running else { return }
                        live.event = text
                    }
                }
            }
            if result.lastMessage.isEmpty == false, FileManager.default.fileExists(atPath: outputFile.path) == false {
                try result.lastMessage.write(to: outputFile, atomically: true, encoding: .utf8)
            }
            try RecipeOutput.finalizeFile(outputFile)
            let mismatch = items.contains(where: hashMismatch)
            try restoreInputs(items)
            _ = shelf.addResult(
                ResultRecord(
                    sourceItemIDs: items.map(\.id),
                    recipe: spec.fullTitle,
                    title: spec.outputFileName,
                    kind: spec.outputKind,
                    output: outputFile,
                    isolationShown: Self.shown(for: presence.isolation),
                    status: mismatch ? .failed : .done,
                    failureReason: mismatch ? "原件中途变了，结果按副本做的" : nil
                )
            )
        } catch AgentError.cancelled {
            try restoreInputs(items)
            control.end()
            throw AgentError.cancelled
        } catch {
            let reason = Self.failureCopy(error, lastEvent: items.first.flatMap { shelf.item(id: $0.id)?.event } ?? "")
            try restoreInputs(items)
            let existing = FileManager.default.fileExists(atPath: outputFile.path) ? outputFile : nil
            _ = shelf.addResult(
                ResultRecord(
                    sourceItemIDs: items.map(\.id),
                    recipe: spec.fullTitle,
                    title: spec.outputFileName,
                    kind: spec.outputKind,
                    output: existing,
                    isolationShown: Self.shown(for: presence.isolation),
                    status: .failed,
                    failureReason: reason
                )
            )
            control.end()
            throw error
        }

        control.end()
        return jobID
    }

    public func job(id: JobID) -> JobRecord? {
        let dir = jobsRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        let manifestURL = dir.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let recipe = RecipeID(rawValue: object["recipe"] as? String ?? "") ?? .summarize
        let itemIDs = ((object["items"] as? [[String: Any]]) ?? []).compactMap { row -> ItemID? in
            guard let value = row["id"] as? String, value.isEmpty == false else { return nil }
            return ItemID(rawValue: value)
        }
        let outputDir = dir.appendingPathComponent("output", isDirectory: true)
        let outputFile = outputDir.appendingPathComponent(RecipeCatalog.spec(recipe).outputFileName)
        return JobRecord(
            id: id,
            recipe: recipe,
            itemIDs: itemIDs,
            directory: dir,
            outputFile: FileManager.default.fileExists(atPath: outputFile.path) ? outputFile : outputDir
        )
    }

    private func hashMismatch(_ item: Item) -> Bool {
        guard let expected = item.sourceChecksum else { return false }
        guard item.sourceURL.isFileURL else { return false }
        guard FileManager.default.fileExists(atPath: item.sourceURL.path) else { return true }
        let current = (try? FileDigest.sha256(of: item.sourceURL)) ?? ""
        return current != expected
    }

    private func restoreInputs(_ items: [Item]) throws {
        for item in items {
            try shelf.patch(id: item.id) { live in
                live.status = .idle
                live.recipe = nil
                live.event = ""
                live.failureReason = nil
                live.output = nil
                live.isolationShown = .none
            }
        }
    }

    private static func shown(for grade: IsolationGrade) -> IsolationShown {
        switch grade {
        case .workspace: return .workspace
        case .unknown: return .unconfirmed
        case .tui: return .tui
        case .none: return .none
        }
    }

    private func copyRegular(from source: URL, to dest: URL) throws {
        try FileManager.default.copyItem(at: source, to: dest)
        try stripSymlinks(at: dest)
    }

    private func stripSymlinks(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
            return
        }
        guard isDir.boolValue else { return }
        for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            try stripSymlinks(at: child)
        }
    }

    private func freezeReadOnly(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try freezeReadOnly(at: child)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: url.path)
        } else {
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        }
    }

    private func uniqueURL(in directory: URL, preferredName: String) -> URL {
        var dest = directory.appendingPathComponent(preferredName)
        var i = 2
        let base = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        while FileManager.default.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            dest = directory.appendingPathComponent(name)
            i += 1
        }
        return dest
    }

    private func appendEvent(dir: URL, message: String) throws {
        let file = dir.appendingPathComponent("events.jsonl")
        let line = "{\"message\":\(jsonString(message))}\n"
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } else {
            try Data(line.utf8).write(to: file)
        }
    }

    private func writeManifest(
        dir: URL,
        jobID: JobID,
        recipe: RecipeID,
        agent: String,
        isolation: IsolationGrade,
        items: [Item]
    ) throws {
        let listed: [[String: Any]] = items.map { item in
            var row: [String: Any] = [
                "id": item.id.rawValue,
                "title": item.title,
            ]
            if let checksum = item.sourceChecksum {
                row["checksum"] = checksum
            }
            return row
        }
        let payload: [String: Any] = [
            "id": jobID.rawValue,
            "recipe": recipe.rawValue,
            "agent": agent,
            "isolation": isolation.rawValue,
            "items": listed,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: dir.appendingPathComponent("manifest.json"))
    }

    private func jsonString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}

enum FileDigest {
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = try? handle.read(upToCount: 1024 * 1024)
            guard let chunk, !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension JobService {
    static func displayEvent(_ message: String) -> String {
        let line = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? message
        if line.count <= 48 { return line }
        return String(line.prefix(47)) + "…"
    }

    static func failureCopy(_ error: Error, lastEvent: String) -> String {
        if lastEvent.contains("失败") {
            return lastEvent
        }
        switch error {
        case AgentError.notFound:
            return "没找到 Codex"
        default:
            return "任务失败"
        }
    }
}

final class JobControl: @unchecked Sendable {
    private let cancelled = OSAllocatedUnfairLock(initialState: false)

    func begin() {
        cancelled.withLock { $0 = false }
    }

    func markCancelled() {
        cancelled.withLock { $0 = true }
    }

    func end() {
        cancelled.withLock { $0 = false }
    }

    var isCancelled: Bool {
        cancelled.withLock { $0 }
    }
}
