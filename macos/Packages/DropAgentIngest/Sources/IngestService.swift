import AppKit
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
    public var pageCaptureIDs: [ItemID]

    public init(admitted: [Item], failures: [AdmitFailure], pageCaptureIDs: [ItemID] = []) {
        self.admitted = admitted
        self.failures = failures
        self.pageCaptureIDs = pageCaptureIDs
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

    public init(shelf: ShelfStore, inboxRoot: URL, capture: CaptureService? = nil) {
        self.shelf = shelf
        self.inboxRoot = inboxRoot
        self.capture = capture ?? CaptureService(
            browser: AppleScriptBrowser(),
            fetcher: URLSessionFetcher(),
            snapshot: FrontWindowSnapshot(),
            pageSnapshot: URLPageSnapshot()
        )
    }

    public static let pageCapturePendingEvent = "正在抓取"

    public func admit(urls: [URL], capturePages: Bool = true) -> AdmitResult {
        var admitted: [Item] = []
        var failures: [AdmitFailure] = []
        var pageCaptureIDs: [ItemID] = []
        for url in urls {
            do {
                let outcome = try admitOne(url: url, capturePages: capturePages)
                admitted.append(outcome.item)
                if outcome.needsPageCapture {
                    pageCaptureIDs.append(outcome.item.id)
                }
            } catch let error as IngestError {
                failures.append(AdmitFailure(url: url, error: error))
            } catch {
                failures.append(AdmitFailure(url: url, error: .unsupported))
            }
        }
        return AdmitResult(admitted: admitted, failures: failures, pageCaptureIDs: pageCaptureIDs)
    }

    public func admitClipboard(_ clipboard: ClipboardReading, capturePages: Bool = true) throws -> [Item] {
        let payload = clipboard.read()
        if case .empty = payload { throw IngestError.emptyClipboard }
        let result = admitPayload(payload, capturePages: capturePages)
        if result.admitted.isEmpty { throw result.failures.first?.error ?? .unsupported }
        return result.admitted
    }

    public func admitPasteboard(_ pasteboard: NSPasteboard, capturePages: Bool = true) -> AdmitResult {
        admitPayload(ClipboardPayload.from(pasteboard: pasteboard), capturePages: capturePages)
    }

    public func admitPayload(_ payload: ClipboardPayload, capturePages: Bool = true) -> AdmitResult {
        switch payload {
        case .empty:
            return AdmitResult(admitted: [], failures: [])
        case .files(let urls):
            return admit(urls: urls, capturePages: capturePages)
        case .image(let data):
            do {
                return AdmitResult(admitted: [try admitImageData(data)], failures: [])
            } catch let error as IngestError {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clipboard.png"), error: error)])
            } catch {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clipboard.png"), error: .unsupported)])
            }
        case .text(let text):
            do {
                let outcome = try admitTextPayload(text, capturePages: capturePages)
                return AdmitResult(
                    admitted: [outcome.item],
                    failures: [],
                    pageCaptureIDs: outcome.needsPageCapture ? [outcome.item.id] : []
                )
            } catch let error as IngestError {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clip.txt"), error: error)])
            } catch {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clip.txt"), error: .unsupported)])
            }
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
        try admitTextPayload(text, capturePages: true).item
    }

    public func captureDroppedPages(ids: [ItemID]) async {
        for id in ids {
            await fillDroppedPage(id: id)
        }
    }

    public func admitCurrentPage(token: PageAdmitToken? = nil) async throws -> Item {
        let captured: PageCapture
        do {
            captured = try await capture.captureFrontBrowser(target: token?.browser)
        } catch CaptureError.unsupportedBrowser {
            throw IngestError.captureFailed
        } catch {
            throw IngestError.captureFailed
        }
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        let parts = try writeCapturedPage(folder: folder, captured: captured)
        let item = Item(
            id: id,
            kind: .web,
            title: captured.title,
            sourceURL: captured.url,
            parts: parts,
            event: captured.failures.map(\.rawValue).joined(separator: " · ")
        )
        return try shelf.add(item)
    }

    func admitTextPayload(_ text: String, capturePages: Bool) throws -> PageAdmitOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if capturePages, let url = Self.httpURL(from: trimmed) {
            return PageAdmitOutcome(item: try admitPageStub(url: url), needsPageCapture: true)
        }
        return PageAdmitOutcome(item: try admitText(trimmed), needsPageCapture: false)
    }

    private func admitOne(url: URL, capturePages: Bool) throws -> PageAdmitOutcome {
        if Self.isHTTP(url) {
            if capturePages {
                return PageAdmitOutcome(item: try admitPageStub(url: url), needsPageCapture: true)
            }
            return PageAdmitOutcome(
                item: try admitText(url.absoluteString, forcedKind: .url, title: url.host ?? url.absoluteString, source: url),
                needsPageCapture: false
            )
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
            if capturePages {
                return PageAdmitOutcome(item: try admitPageStub(url: link), needsPageCapture: true)
            }
            return PageAdmitOutcome(
                item: try admitText(link.absoluteString, forcedKind: .url, title: link.host ?? link.absoluteString, source: link),
                needsPageCapture: false
            )
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
        return PageAdmitOutcome(item: try shelf.add(item), needsPageCapture: false)
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

    private func admitPageStub(url: URL) throws -> Item {
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent("url.txt")
        try writeTextFile(dest, url.absoluteString)
        let item = Item(
            id: id,
            kind: .web,
            title: url.host ?? url.absoluteString,
            sourceURL: url,
            parts: [ItemPart(name: "url.txt", url: dest)],
            event: Self.pageCapturePendingEvent
        )
        return try shelf.add(item)
    }

    private func fillDroppedPage(id: ItemID) async {
        guard let item = shelf.item(id: id), item.kind == .web, Self.isHTTP(item.sourceURL) else { return }
        let captured = await capture.captureURL(item.sourceURL)
        guard shelf.item(id: id) != nil else { return }
        let folder = item.parts.first?.url.deletingLastPathComponent()
            ?? inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        do {
            let parts = try writeCapturedPage(folder: folder, captured: captured)
            try shelf.patch(id: id) { live in
                live.title = captured.title
                live.sourceURL = captured.url
                live.parts = parts
                live.event = captured.failures.map(\.rawValue).joined(separator: " · ")
            }
        } catch {
            try? shelf.patch(id: id) { live in
                if live.event == Self.pageCapturePendingEvent {
                    live.event = CaptureFailure.network.rawValue
                }
            }
        }
    }

    private func writeCapturedPage(folder: URL, captured: PageCapture) throws -> [ItemPart] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var parts: [ItemPart] = []
        let urlFile = folder.appendingPathComponent("url.txt")
        try writeTextFile(urlFile, captured.url.absoluteString)
        parts.append(ItemPart(name: "url.txt", url: urlFile))
        if let markdown = captured.markdown {
            let file = folder.appendingPathComponent("page.md")
            try writeTextFile(file, markdown)
            parts.append(ItemPart(name: "page.md", url: file))
        }
        if let png = captured.snapshotPNG {
            let file = folder.appendingPathComponent("snapshot.png")
            try png.write(to: file)
            parts.append(ItemPart(name: "snapshot.png", url: file))
        }
        return parts
    }

    private static func isHTTP(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    private static func httpURL(from text: String) -> URL? {
        guard text.hasPrefix("http://") || text.hasPrefix("https://"),
              let url = URL(string: text)
        else { return nil }
        return isHTTP(url) ? url : nil
    }

    private func writeTextFile(_ url: URL, _ text: String) throws {
        try writeTextFile(url, Data(text.utf8))
    }

    private func writeTextFile(_ url: URL, _ data: Data) throws {
        var data = data
        if data.isEmpty == false, data.last != 0x0A {
            data.append(0x0A)
        }
        try data.write(to: url)
    }
}

struct PageAdmitOutcome {
    var item: Item
    var needsPageCapture: Bool
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
