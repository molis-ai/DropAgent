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

    public func start(
        itemIDs: [ItemID],
        recipe: RecipeID,
        optionID: String? = nil,
        custom: CustomJobSpec? = nil
    ) async throws -> JobID {
        guard !itemIDs.isEmpty else { throw JobError.emptySelection }
        if recipe == .shortcut, custom == nil { throw JobError.notStartable }
        let spec = RecipeCatalog.spec(recipe)
        let presence = agent.discover(settings: agent.settings)
        let requiresAgent = custom != nil || spec.requiresAgent
        let accepted = custom?.acceptedKinds ?? spec.acceptedKinds
        let outputName = custom?.outputFileName ?? spec.outputFileName
        let displayTitle = custom?.title ?? spec.fullTitle
        if requiresAgent {
            guard presence.executable != nil else { throw JobError.noAgent }
        }

        var items: [Item] = []
        for id in itemIDs {
            guard let item = shelf.item(id: id) else { throw JobError.missingItem }
            guard item.status == .idle || item.status == .confirm || item.status == .failed else {
                throw JobError.notStartable
            }
            guard accepted.contains(item.kind) else {
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
        let outputFile = output.appendingPathComponent(outputName)
        let shown = requiresAgent ? Self.shown(for: presence.isolation) : .safeCopy
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
                    live.recipe = displayTitle
                    live.event = "复制到 input/ 与 work/"
                    live.isolationShown = shown
                    live.failureReason = nil
                }
            }
            try JobWorkspace.freezeReadOnly(at: input)
            try JobWorkspace.appendEvent(dir: dir, message: "复制到 input/ 与 work/")
            try JobWorkspace.writeManifest(
                dir: dir,
                jobID: jobID,
                recipe: recipe,
                agent: localAgentName(recipe, presence: presence),
                isolation: requiresAgent ? presence.isolation : .none,
                items: items
            )

            let runningIDs = items.map(\.id)
            if control.isCancelled {
                throw AgentError.cancelled
            }
            var lastMessage = ""
            if requiresAgent {
                let promptFile = dir.appendingPathComponent("prompt.txt")
                let listed = relativeNames.map { "- \($0)" }.joined(separator: "\n")
                let body: String
                if let custom {
                    body = RecipeCatalog.fileGuardrail(outputFileName: outputName) + "\n" + custom.prompt + "\n"
                } else {
                    body = RecipeCatalog.prompt(for: recipe, choiceID: optionID)
                }
                let prompt = body + "\n材料：\n" + listed + "\n"
                try Data(prompt.utf8).write(to: promptFile)
                let request = AgentRunRequest(
                    workdir: work,
                    promptFile: promptFile,
                    outputFile: outputFile,
                    isolation: presence.isolation,
                    network: spec.needsNetwork
                )
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
                lastMessage = result.lastMessage
            } else {
                switch recipe {
                case .imageText:
                    try await runImageText(
                        names: relativeNames,
                        work: work,
                        outputFile: outputFile,
                        dir: dir,
                        choiceID: optionID,
                        runningIDs: runningIDs
                    )
                case .pdfText:
                    try await runPdfText(
                        names: relativeNames,
                        work: work,
                        outputFile: outputFile,
                        dir: dir,
                        runningIDs: runningIDs
                    )
                default:
                    throw JobError.notStartable
                }
            }
            try RecipeOutput.collect(
                into: outputFile,
                work: work,
                lastMessage: lastMessage,
                inputNames: relativeNames,
                input: input
            )
            try JobWorkspace.appendEvent(dir: dir, message: "写入 output/")
            let mismatch = items.contains(where: hashMismatch)
            try restoreInputs(items)
            _ = shelf.addResult(
                ResultRecord(
                    sourceItemIDs: items.map(\.id),
                    recipe: displayTitle,
                    title: outputName,
                    kind: spec.outputKind,
                    output: outputFile,
                    isolationShown: shown,
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
            let existing = RecipeOutput.hasDeliverable(outputFile) ? outputFile : nil
            _ = shelf.addResult(
                ResultRecord(
                    sourceItemIDs: items.map(\.id),
                    recipe: displayTitle,
                    title: outputName,
                    kind: spec.outputKind,
                    output: existing,
                    isolationShown: shown,
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

    private func runImageText(
        names: [String],
        work: URL,
        outputFile: URL,
        dir: URL,
        choiceID: String?,
        runningIDs: [ItemID]
    ) async throws {
        let languages = ImageText.languages(
            choiceID: RecipeCatalog.resolvedChoiceID(.imageText, optionID: choiceID)
        )
        var pages: [(name: String, lines: [ImageTextLine])] = []
        for name in names {
            if control.isCancelled { throw AgentError.cancelled }
            let event = "识别 \(name)"
            try JobWorkspace.appendEvent(dir: dir, message: event)
            for id in runningIDs {
                try? shelf.patch(id: id) { live in
                    guard live.status == .running else { return }
                    live.event = event
                }
            }
            let lines = try await ImageText.recognize(
                url: work.appendingPathComponent(name),
                languages: languages
            )
            pages.append((name, lines))
        }
        if control.isCancelled { throw AgentError.cancelled }
        try ImageText.markdown(pages: pages).write(to: outputFile, atomically: true, encoding: .utf8)
        try JobWorkspace.appendEvent(dir: dir, message: "写入 output/")
    }

    private func runPdfText(
        names: [String],
        work: URL,
        outputFile: URL,
        dir: URL,
        runningIDs: [ItemID]
    ) async throws {
        var files: [(name: String, pages: [String])] = []
        for name in names {
            if control.isCancelled { throw AgentError.cancelled }
            let event = "抽出 \(name)"
            try JobWorkspace.appendEvent(dir: dir, message: event)
            for id in runningIDs {
                try? shelf.patch(id: id) { live in
                    guard live.status == .running else { return }
                    live.event = event
                }
            }
            let pages = try await PDFText.pages(url: work.appendingPathComponent(name))
            files.append((name, pages))
        }
        if control.isCancelled { throw AgentError.cancelled }
        try PDFText.markdown(files: files).write(to: outputFile, atomically: true, encoding: .utf8)
        try JobWorkspace.appendEvent(dir: dir, message: "写入 output/")
    }

    private func localAgentName(_ recipe: RecipeID, presence: AgentPresence) -> String {
        if RecipeCatalog.spec(recipe).requiresAgent {
            return presence.engine?.rawValue ?? "none"
        }
        switch recipe {
        case .pdfText: return "pdfkit"
        default: return "vision"
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
        case JobError.missingOutput:
            return "这次没有生成文件"
        case AgentError.notFound:
            return "没找到 Codex"
        case ImageTextError.unreadable:
            return "打不开这张图"
        case PDFTextError.unreadable:
            return "打不开这份 PDF"
        case PDFTextError.locked:
            return "这份 PDF 有密码，抽不出文字"
        default:
            return "任务失败"
        }
    }
}
