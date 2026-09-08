import DropAgentAgent
import DropAgentShelf
import Foundation
import os

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

    public func deleteOwnedOutput(_ record: ResultRecord) {
        guard let output = record.output else { return }
        let root = jobsRoot.resolvingSymlinksInPath().standardizedFileURL
        let file = output.resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard file.path.hasPrefix(prefix) else { return }
        let jobDir = file.deletingLastPathComponent().deletingLastPathComponent()
            .resolvingSymlinksInPath().standardizedFileURL
        if jobDir.path.hasPrefix(prefix) {
            JobWorkspace.forceRemove(jobDir)
        } else {
            JobWorkspace.forceRemove(file)
        }
    }

    public func start(itemIDs: [ItemID], recipe: RecipeID, optionID: String? = nil) async throws -> JobID {
        guard !itemIDs.isEmpty else { throw JobError.emptySelection }
        let presence = agent.discover(settings: agent.settings)
        guard presence.executable != nil else { throw JobError.noAgent }
        let spec = RecipeCatalog.spec(recipe)

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
        guard control.begin() else { throw JobError.notStartable }
        defer { control.end() }
        let jobID = JobID()
        let dir = jobsRoot.appendingPathComponent(jobID.rawValue, isDirectory: true)
        let input = dir.appendingPathComponent("input", isDirectory: true)
        let work = dir.appendingPathComponent("work", isDirectory: true)
        let output = dir.appendingPathComponent("output", isDirectory: true)
        let outputFile = output.appendingPathComponent(spec.outputFileName)
        do {
            try FileManager.default.createDirectory(at: input, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

            var relativeNames: [String] = []
            for item in items {
                for part in item.parts {
                    let destInput = JobWorkspace.uniqueURL(in: input, preferredName: part.name)
                    let destWork = JobWorkspace.uniqueURL(in: work, preferredName: part.name)
                    try JobWorkspace.copyRegular(from: part.url, to: destInput)
                    try JobWorkspace.copyRegular(from: part.url, to: destWork)
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
            try JobWorkspace.freezeReadOnly(at: input)

            let promptFile = dir.appendingPathComponent("prompt.txt")
            let listed = relativeNames.map { "- \($0)" }.joined(separator: "\n")
            let prompt = RecipeCatalog.prompt(for: recipe, choiceID: optionID) + "\n材料：\n" + listed + "\n"
            try Data(prompt.utf8).write(to: promptFile)
            try JobWorkspace.appendEvent(dir: dir, message: "复制到 input/ 与 work/")
            try JobWorkspace.writeManifest(
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

            if control.isCancelled {
                throw AgentError.cancelled
            }
            let result = try await agent.run(request) { event in
                let text = Self.displayEvent(event.message)
                try? JobWorkspace.appendEvent(dir: dir, message: event.message)
                for id in runningIDs {
                    try? shelf.patch(id: id) { live in
                        guard live.status == .running else { return }
                        live.event = text
                    }
                }
            }
            if control.isCancelled { throw AgentError.cancelled }
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
            throw error
        }

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
