import Foundation

public enum RecipeOutput {
    public static func finalize(_ text: String, fileName: String) -> String {
        guard fileName.lowercased().hasSuffix(".json") else { return text }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return unwrapJSON(trimmed)
    }

    public static func finalizeFile(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let raw = try String(contentsOf: url, encoding: .utf8)
        let cleaned = finalize(raw, fileName: url.lastPathComponent)
        if cleaned != raw {
            try cleaned.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    public static func hasDeliverable(_ url: URL, fileManager: FileManager = .default) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return looksLikeDeliverable(raw)
    }

    public static func looksLikeDeliverable(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if isProgress(trimmed) { return false }
        if isCompletionReport(trimmed) { return false }
        return true
    }

    public static func collect(
        into outputFile: URL,
        work: URL,
        lastMessage: String,
        inputNames: [String],
        input: URL,
        fileManager: FileManager = .default
    ) throws {
        if hasDeliverable(outputFile, fileManager: fileManager) {
            try finalizeFile(outputFile)
            return
        }
        if let harvested = harvest(
            work: work,
            preferredName: outputFile.lastPathComponent,
            inputNames: Set(inputNames),
            input: input,
            fileManager: fileManager
        ) {
            try replace(outputFile, with: harvested, fileManager: fileManager)
            try finalizeFile(outputFile)
            return
        }
        if looksLikeDeliverable(lastMessage) {
            try lastMessage.write(to: outputFile, atomically: true, encoding: .utf8)
            try finalizeFile(outputFile)
            return
        }
        if fileManager.fileExists(atPath: outputFile.path) {
            try? fileManager.removeItem(at: outputFile)
        }
        throw JobError.missingOutput
    }

    private static func harvest(
        work: URL,
        preferredName: String,
        inputNames: Set<String>,
        input: URL,
        fileManager: FileManager
    ) -> URL? {
        let preferred = work.appendingPathComponent(preferredName)
        if isNewDeliverable(
            preferred,
            work: work,
            input: input,
            inputNames: inputNames,
            fileManager: fileManager
        ) {
            return preferred
        }
        var candidates: [URL] = []
        if let enumerator = fileManager.enumerator(
            at: work,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if isNewDeliverable(
                    url,
                    work: work,
                    input: input,
                    inputNames: inputNames,
                    fileManager: fileManager
                ) {
                    candidates.append(url)
                }
            }
        }
        let named = candidates.filter { $0.lastPathComponent == preferredName }
        if let best = newest(named) { return best }
        let wantedExt = URL(fileURLWithPath: preferredName).pathExtension.lowercased()
        if wantedExt.isEmpty == false {
            let matching = candidates.filter { $0.pathExtension.lowercased() == wantedExt }
            if let best = newest(matching) { return best }
        }
        return newest(candidates)
    }

    private static func isNewDeliverable(
        _ url: URL,
        work: URL,
        input: URL,
        inputNames: Set<String>,
        fileManager: FileManager
    ) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else { return false }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
        if values?.isDirectory == true { return false }
        if values?.isRegularFile == false { return false }
        if isMaterialCopy(url, work: work, input: input, inputNames: inputNames, fileManager: fileManager) {
            return false
        }
        return hasDeliverable(url, fileManager: fileManager)
    }

    private static func isMaterialCopy(
        _ url: URL,
        work: URL,
        input: URL,
        inputNames: Set<String>,
        fileManager: FileManager
    ) -> Bool {
        let relative = relativePath(of: url, to: work)
        if relative.isEmpty { return true }
        if fileManager.fileExists(atPath: input.appendingPathComponent(relative).path) {
            return true
        }
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        if parent == work.resolvingSymlinksInPath().standardizedFileURL, inputNames.contains(url.lastPathComponent) {
            return true
        }
        return false
    }

    private static func relativePath(of url: URL, to root: URL) -> String {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let filePath = url.resolvingSymlinksInPath().standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else { return "" }
        return String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func newest(_ urls: [URL]) -> URL? {
        urls.max { left, right in
            let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return leftDate < rightDate
        }
    }

    private static func replace(_ destination: URL, with source: URL, fileManager: FileManager) throws {
        if source.resolvingSymlinksInPath() == destination.resolvingSymlinksInPath() {
            return
        }
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
    }

    private static func isCompletionReport(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = trimmed.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
        guard trimmed.count <= 180, lines.count <= 3 else { return false }
        let lower = trimmed.lowercased()
        let talksAboutFile = lower.contains(".md")
            || lower.contains(".json")
            || lower.contains("文件")
            || lower.contains("file")
        let zh = trimmed.contains("已把")
            || trimmed.contains("已将")
            || trimmed.contains("已写入")
            || trimmed.contains("已生成")
            || trimmed.contains("已整合")
        let zhDone = trimmed.contains("已完成") && talksAboutFile
        let en = lower.contains("wrote ")
            || lower.contains("written ")
            || lower.contains("created ")
            || lower.contains("saved ")
            || lower.contains("combined ")
        return zh || zhDone || en
    }

    private static func isProgress(_ text: String) -> Bool {
        let progress: Set<String> = [
            "开始运行",
            "收尾",
            "在写结果",
            "在写文件",
            "工具调用",
            "工具调用完成",
            "联网",
            "思考中",
            "进行中",
            "失败",
            "等待授权",
            "写入 output/",
            "正在收取结果",
            "正在读取材料",
            "正在查找任务材料",
            "正在整理交付文件",
            "Agent 正在处理材料",
        ]
        if progress.contains(text) { return true }
        if text.hasPrefix("任务失败") { return true }
        if text.hasPrefix("识别 ") { return true }
        return false
    }

    private static func unwrapJSON(_ text: String) -> String {
        if isJSON(text) { return text }
        guard text.hasPrefix("```") else { return text }
        var lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return text }
        lines.removeFirst()
        if lines.last?.hasPrefix("```") == true {
            lines.removeLast()
        }
        let inner = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return isJSON(inner) ? inner : text
    }

    private static func isJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8), data.isEmpty == false else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
