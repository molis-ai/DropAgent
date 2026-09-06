import CryptoKit
import DropAgentCapture
import DropAgentShelf
import Foundation
import UniformTypeIdentifiers

public enum IngestError: Error, Equatable, Sendable {
    case missingSource
    case unsupported
    case emptyClipboard
    case captureFailed
    case symlinkRejected
}

public struct AdmitFailure: Equatable, Sendable {
    public var url: URL
    public var error: IngestError

    public init(url: URL, error: IngestError) {
        self.url = url
        self.error = error
    }
}

public struct AdmitResult: Equatable, Sendable {
    public var admitted: [Item]
    public var failures: [AdmitFailure]

    public init(admitted: [Item], failures: [AdmitFailure]) {
        self.admitted = admitted
        self.failures = failures
    }
}

public protocol ClipboardReading: Sendable {
    func read() -> ClipboardPayload
}

public enum ClipboardPayload: Equatable, Sendable {
    case empty
    case files([URL])
    case image(Data)
    case text(String)
}

public struct IngestService: Sendable {
    private let shelf: ShelfStore
    private let inboxRoot: URL
    private let capture: CaptureService

    public init(shelf: ShelfStore, inboxRoot: URL, capture: CaptureService) {
        self.shelf = shelf
        self.inboxRoot = inboxRoot
        self.capture = capture
    }

    public func admit(urls: [URL]) -> AdmitResult {
        var admitted: [Item] = []
        var failures: [AdmitFailure] = []
        for url in urls {
            do {
                let item = try admitOne(url: url)
                admitted.append(item)
            } catch let error as IngestError {
                failures.append(AdmitFailure(url: url, error: error))
            } catch {
                failures.append(AdmitFailure(url: url, error: .unsupported))
            }
        }
        return AdmitResult(admitted: admitted, failures: failures)
    }

    public func admitClipboard(_ clipboard: ClipboardReading) throws -> [Item] {
        switch clipboard.read() {
        case .empty:
            throw IngestError.emptyClipboard
        case .files(let urls):
            let result = admit(urls: urls)
            if result.admitted.isEmpty { throw result.failures.first?.error ?? .unsupported }
            return result.admitted
        case .image(let data):
            return [try admitImageData(data)]
        case .text(let text):
            return [try admitPlainText(text)]
        }
    }

    public func admitImageData(_ data: Data) throws -> Item {
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent("clipboard.png")
        try data.write(to: dest)
        let item = Item(
            id: id,
            kind: .image,
            title: "剪贴板图片",
            sourceURL: dest,
            parts: [ItemPart(name: "clipboard.png", url: dest)],
            sourceChecksum: FileDigest.sha256(of: data)
        )
        return try shelf.add(item)
    }

    public func admitPlainText(_ text: String) throws -> Item {
        try admitText(text)
    }

    public func admitCurrentPage(target: BrowserFront? = nil) async throws -> Item {
        let captured: PageCapture
        do {
            captured = try await capture.captureFrontBrowser(target: target)
        } catch CaptureError.unsupportedBrowser {
            throw IngestError.captureFailed
        } catch {
            throw IngestError.captureFailed
        }
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var parts: [ItemPart] = []
        let urlFile = folder.appendingPathComponent("url.txt")
        try Data(captured.url.absoluteString.utf8).write(to: urlFile)
        parts.append(ItemPart(name: "url.txt", url: urlFile))
        if let markdown = captured.markdown {
            let file = folder.appendingPathComponent("page.md")
            try markdown.write(to: file)
            parts.append(ItemPart(name: "page.md", url: file))
        }
        if let png = captured.snapshotPNG {
            let file = folder.appendingPathComponent("snapshot.png")
            try png.write(to: file)
            parts.append(ItemPart(name: "snapshot.png", url: file))
        }
        let event = captured.failures.map(\.rawValue).joined(separator: " · ")
        let item = Item(
            id: id,
            kind: .web,
            title: captured.title,
            sourceURL: captured.url,
            parts: parts,
            event: event
        )
        return try shelf.add(item)
    }

    private func admitOne(url: URL) throws -> Item {
        if let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return try admitText(url.absoluteString, forcedKind: .url, title: url.host ?? url.absoluteString, source: url)
        }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            throw IngestError.missingSource
        }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            throw IngestError.symlinkRejected
        }
        if isDir.boolValue == false,
           url.pathExtension.lowercased() == "webloc",
           let link = WeblocURL.read(url)
        {
            return try admitText(link.absoluteString, forcedKind: .url, title: link.host ?? link.absoluteString, source: link)
        }
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = url.lastPathComponent
        let dest = folder.appendingPathComponent(name)
        try FileManager.default.copyItem(at: url, to: dest)
        try MaterialCopy.stripSymlinks(at: dest)
        let kind = Self.kind(for: url, isDirectory: isDir.boolValue)
        let checksum: String?
        if !isDir.boolValue {
            checksum = try FileDigest.sha256(of: url)
        } else {
            checksum = nil
        }
        let item = Item(
            id: id,
            kind: kind,
            title: name,
            sourceURL: url,
            parts: [ItemPart(name: name, url: dest)],
            sourceChecksum: checksum
        )
        return try shelf.add(item)
    }

    private func admitText(_ text: String, forcedKind: ItemKind? = nil, title: String? = nil, source: URL? = nil) throws -> Item {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IngestError.emptyClipboard }
        let isURL = trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
        let kind = forcedKind ?? (isURL ? .url : .clip)
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let filename = kind == .url ? "link.txt" : "clip.txt"
        let dest = folder.appendingPathComponent(filename)
        try Data(trimmed.utf8).write(to: dest)
        let sourceURL = source ?? URL(string: trimmed) ?? dest
        let item = Item(
            id: id,
            kind: kind,
            title: title ?? (kind == .url ? (URL(string: trimmed)?.host ?? "链接") : "剪贴板"),
            sourceURL: kind == .url ? (URL(string: trimmed) ?? dest) : sourceURL,
            parts: [ItemPart(name: filename, url: dest)]
        )
        return try shelf.add(item)
    }

    public static func kind(for url: URL, isDirectory: Bool) -> ItemKind {
        if isDirectory { return .folder }
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" { return .pdf }
        if ["png", "jpg", "jpeg", "webp", "gif", "tif", "tiff", "heic"].contains(ext) { return .image }
        if ext == "md" || ext == "txt" || ext == "markdown" { return .markdown }
        if ext == "rtf" || ext == "rtfd" { return .file }
        if ext == "html" || ext == "htm" { return .file }
        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .pdf) { return .pdf }
            if type.conforms(to: .image) { return .image }
            if type.conforms(to: .plainText) || type.conforms(to: .text) { return .markdown }
        }
        return .file
    }
}

enum WeblocURL {
    static func read(_ file: URL) -> URL? {
        guard let data = try? Data(contentsOf: file),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let text = plist["URL"] as? String
        else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" else {
            return nil
        }
        return url
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

    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

enum MaterialCopy {
    static func stripSymlinks(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
            return
        }
        guard isDir.boolValue else { return }
        let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        for child in children {
            try stripSymlinks(at: child)
        }
    }
}
