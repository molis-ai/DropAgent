import DropAgentShelf
import Foundation

public enum StageEditError: Error, Equatable, Sendable {
    case notOwned
    case notText
}

public enum StageEdit {
    public static let debounceNanos: UInt64 = 400_000_000
    public static let maxBytes = 512 * 1024

    public static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "json",
        "swift", "py", "js", "ts", "mjs", "css",
        "yaml", "yml", "xml", "toml", "ini",
        "rs", "go", "rb", "sh", "zsh",
        "c", "h", "cc", "cpp", "m", "mm",
        "csv", "log",
    ]

    public static func editableURL(_ item: Item, inboxRoot: URL, jobsRoot: URL) -> URL? {
        switch item.status {
        case .running, .confirm:
            return nil
        case .idle, .done, .sent, .failed:
            break
        }
        switch item.kind {
        case .image, .pdf, .folder, .url:
            return nil
        case .web:
            guard let part = item.parts.first(where: { $0.name.lowercased().hasSuffix(".md") }) else {
                return nil
            }
            return ownedEditableFile(part.url, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
        case .clip, .markdown, .file:
            if let output = item.output {
                return ownedEditableFile(output, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
            }
            guard let url = preferredTextURL(in: item) else { return nil }
            return ownedEditableFile(url, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
        }
    }

    public static func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    public static func write(_ text: String, to url: URL, inboxRoot: URL, jobsRoot: URL) throws {
        guard isOwned(url, inboxRoot: inboxRoot, jobsRoot: jobsRoot) else {
            throw StageEditError.notOwned
        }
        let parent = url.deletingLastPathComponent()
        guard isOwned(parent, inboxRoot: inboxRoot, jobsRoot: jobsRoot) else {
            throw StageEditError.notOwned
        }
        guard isListedText(url) else { throw StageEditError.notText }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            throw StageEditError.notText
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func schedule(_ text: String, to url: URL, inboxRoot: URL, jobsRoot: URL) {
        buffer.queue.async {
            buffer.pending = Pending(url: url, text: text, inboxRoot: inboxRoot, jobsRoot: jobsRoot)
            buffer.work?.cancel()
            let work = DispatchWorkItem {
                writePending()
            }
            buffer.work = work
            buffer.queue.asyncAfter(
                deadline: .now() + .nanoseconds(Int(debounceNanos)),
                execute: work
            )
        }
    }

    public static func flush() {
        buffer.queue.sync {
            buffer.work?.cancel()
            buffer.work = nil
            writePending()
        }
    }

    public static func isListedText(_ url: URL) -> Bool {
        if ReadableHTML.isHTMLFile(url) { return false }
        return textExtensions.contains(url.pathExtension.lowercased())
    }

    private static func preferredTextURL(in item: Item) -> URL? {
        if let part = item.parts.first(where: { isListedText($0.url) }) {
            return part.url
        }
        if let part = item.parts.first, isListedText(part.url) {
            return part.url
        }
        return nil
    }

    private static func ownedEditableFile(_ url: URL, inboxRoot: URL, jobsRoot: URL) -> URL? {
        guard isOwned(url, inboxRoot: inboxRoot, jobsRoot: jobsRoot) else { return nil }
        guard isListedText(url) else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue == false else {
            return nil
        }
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        if data.count > maxBytes { return nil }
        if data.contains(0) { return nil }
        if data.isEmpty { return url }
        guard String(data: data, encoding: .utf8) != nil else { return nil }
        return url
    }

    private static func isOwned(_ url: URL, inboxRoot: URL, jobsRoot: URL) -> Bool {
        OwnedCopy.isInside(url, root: inboxRoot) || OwnedCopy.isInside(url, root: jobsRoot)
    }

    private static func writePending() {
        guard let pending = buffer.pending else { return }
        buffer.pending = nil
        try? write(pending.text, to: pending.url, inboxRoot: pending.inboxRoot, jobsRoot: pending.jobsRoot)
    }

    private struct Pending {
        var url: URL
        var text: String
        var inboxRoot: URL
        var jobsRoot: URL
    }

    private final class Buffer: @unchecked Sendable {
        let queue = DispatchQueue(label: "local.dropagent.stage-edit")
        var pending: Pending?
        var work: DispatchWorkItem?
    }

    private static let buffer = Buffer()
}
