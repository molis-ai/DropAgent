import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

public struct ClipID: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }
}

public enum ClipKind: String, Codable, Sendable {
    case text
    case image
    case url
    case files
}

public struct ClipDraft: Equatable, Sendable {
    public static let maxImageBytes = 8 * 1024 * 1024
    public static let maxTextBytes = 256 * 1024

    public var kind: ClipKind
    public var title: String
    public var text: String?
    public var imagePNG: Data?
    public var filePaths: [String]

    public init?(kind: ClipKind, title: String, text: String? = nil, imagePNG: Data? = nil, filePaths: [String] = []) {
        let trimmed = text.map { Self.clipText($0) }
        switch kind {
        case .text, .url:
            guard let trimmed, trimmed.isEmpty == false else { return nil }
            self.text = trimmed
            self.imagePNG = nil
            self.filePaths = []
        case .image:
            guard let imagePNG, imagePNG.isEmpty == false, imagePNG.count <= Self.maxImageBytes else { return nil }
            self.text = nil
            self.imagePNG = imagePNG
            self.filePaths = []
        case .files:
            let paths = Self.normalizedPaths(filePaths)
            guard paths.isEmpty == false else { return nil }
            self.text = nil
            self.imagePNG = nil
            self.filePaths = paths
        }
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if self.title.isEmpty {
            self.title = Self.fallbackTitle(kind: kind, text: self.text, filePaths: self.filePaths)
        }
    }

    public var fingerprint: String {
        switch kind {
        case .text:
            return "t:" + Self.digest(Data((text ?? "").utf8))
        case .url:
            return "u:" + (text ?? "")
        case .image:
            return "i:" + Self.digest(imagePNG ?? Data())
        case .files:
            return "f:" + filePaths.joined(separator: "\n")
        }
    }

    public static func titleForText(_ text: String) -> String {
        let line = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if line.isEmpty { return "文本" }
        if line.count <= 40 { return line }
        return String(line.prefix(40)).trimmingCharacters(in: .whitespaces) + "…"
    }

    public static func titleForURL(_ text: String) -> String {
        if let url = URL(string: text), let host = url.host, host.isEmpty == false {
            return host
        }
        return titleForText(text)
    }

    public static func titleForFiles(_ paths: [String]) -> String {
        let names = paths.map { URL(fileURLWithPath: $0).lastPathComponent }.filter { $0.isEmpty == false }
        if names.count == 1 { return names[0] }
        if names.isEmpty { return "文件" }
        return "\(names.count) 个文件"
    }

    public static func isHTTPURL(_ text: String) -> Bool {
        let scheme = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    private static func clipText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.utf8.count <= maxTextBytes { return trimmed }
        let data = Data(trimmed.utf8).prefix(maxTextBytes)
        return String(data: data, encoding: .utf8) ?? String(trimmed.prefix(maxTextBytes / 2))
    }

    private static func normalizedPaths(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for path in paths {
            let key = URL(fileURLWithPath: path).standardizedFileURL.path
            if seen.insert(key).inserted {
                ordered.append(key)
            }
        }
        return ordered
    }

    private static func fallbackTitle(kind: ClipKind, text: String?, filePaths: [String]) -> String {
        switch kind {
        case .text: return titleForText(text ?? "")
        case .url: return titleForURL(text ?? "")
        case .image: return "图片"
        case .files: return titleForFiles(filePaths)
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

public struct ClipRecord: Equatable, Sendable, Identifiable, Codable {
    public var id: ClipID
    public var kind: ClipKind
    public var title: String
    public var createdAt: Date
    public var fingerprint: String
    public var text: String?
    public var imageFile: String?
    public var filePaths: [String]

    public var filesMissing: Bool {
        guard kind == .files else { return false }
        return filePaths.contains { FileManager.default.fileExists(atPath: $0) == false }
    }
}

public enum ClipPasteboard {
    public static let concealedTypes: [NSPasteboard.PasteboardType] = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    public static func isIgnored(_ pasteboard: NSPasteboard) -> Bool {
        if pasteboard.availableType(from: concealedTypes) != nil { return true }
        for item in pasteboard.pasteboardItems ?? [] {
            if item.availableType(from: concealedTypes) != nil { return true }
        }
        return false
    }
}

public final class ClipHistoryStore: @unchecked Sendable {
    public static let limit = 10

    private let lock = NSLock()
    private var ordered: [ClipRecord] = []
    private let directory: URL
    private let fileURL: URL
    public var onChange: (@Sendable () -> Void)?

    public init(directory: URL) {
        self.directory = directory
        self.fileURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
        load()
    }

    public func records() -> [ClipRecord] {
        lock.lock()
        defer { lock.unlock() }
        return ordered
    }

    public func record(id: ClipID) -> ClipRecord? {
        lock.lock()
        defer { lock.unlock() }
        return ordered.first { $0.id == id }
    }

    @discardableResult
    public func record(_ draft: ClipDraft) -> ClipRecord {
        lock.lock()
        if let index = ordered.firstIndex(where: { $0.fingerprint == draft.fingerprint }) {
            var existing = ordered.remove(at: index)
            existing.createdAt = Date()
            existing.title = draft.title
            ordered.insert(existing, at: 0)
            let copy = existing
            lock.unlock()
            persist()
            notify()
            return copy
        }
        let id = ClipID()
        var imageFile: String?
        if let png = draft.imagePNG {
            let name = "\(id.rawValue).png"
            let url = blobsDirectory.appendingPathComponent(name)
            try? png.write(to: url, options: .atomic)
            imageFile = name
        }
        let item = ClipRecord(
            id: id,
            kind: draft.kind,
            title: draft.title,
            createdAt: Date(),
            fingerprint: draft.fingerprint,
            text: draft.text,
            imageFile: imageFile,
            filePaths: draft.filePaths
        )
        ordered.insert(item, at: 0)
        let evicted = ordered.count > Self.limit ? Array(ordered.suffix(from: Self.limit)) : []
        if evicted.isEmpty == false {
            ordered = Array(ordered.prefix(Self.limit))
            for old in evicted {
                removeBlob(old)
            }
        }
        lock.unlock()
        persist()
        notify()
        return item
    }

    public func remove(id: ClipID) {
        lock.lock()
        if let index = ordered.firstIndex(where: { $0.id == id }) {
            let old = ordered.remove(at: index)
            removeBlob(old)
        }
        lock.unlock()
        persist()
        notify()
    }

    public func imageURL(for id: ClipID) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard let name = ordered.first(where: { $0.id == id })?.imageFile else { return nil }
        let url = blobsDirectory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    public func imageData(for id: ClipID) -> Data? {
        imageURL(for: id).flatMap { try? Data(contentsOf: $0) }
    }

    private var blobsDirectory: URL {
        directory.appendingPathComponent("blobs", isDirectory: true)
    }

    private func removeBlob(_ record: ClipRecord) {
        guard let name = record.imageFile else { return }
        try? FileManager.default.removeItem(at: blobsDirectory.appendingPathComponent(name))
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let document = try? decoder.decode(ClipHistoryDocument.self, from: data) {
            ordered = document.records
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(ClipHistoryDocument(records: ordered))
            try data.write(to: fileURL, options: .atomic)
        } catch {}
    }

    private func notify() {
        onChange?()
    }
}

private struct ClipHistoryDocument: Codable {
    var records: [ClipRecord]
}
