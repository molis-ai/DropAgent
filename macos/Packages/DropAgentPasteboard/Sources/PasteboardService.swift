import AppKit
import DropAgentShelf
import Foundation
import UniformTypeIdentifiers

public struct PasteboardRepresentation: Equatable, Sendable {
    public var fileURLs: [URL]
    public var plainText: String?
    public var pngData: Data?
    public var webURL: URL?

    public var utis: [String] {
        var values: [String] = []
        if !fileURLs.isEmpty { values.append(UTType.fileURL.identifier) }
        if plainText != nil { values.append(UTType.utf8PlainText.identifier) }
        if pngData != nil { values.append(UTType.png.identifier) }
        if webURL != nil { values.append(UTType.url.identifier) }
        return values
    }
}

public enum PasteboardService {
    public static func representation(for item: Item) -> PasteboardRepresentation {
        if item.status == .done || item.status == .failed, let output = item.output {
            return representation(forOutput: output, fallback: item)
        }
        return representation(forStaged: item)
    }

    public static func promisedUTIs(for item: Item) -> [String] {
        representation(for: item).utis
    }

    public static func copy(_ item: Item, to pasteboard: NSPasteboard = .general) {
        copy([item], to: pasteboard)
    }

    public static func copy(_ items: [Item], to pasteboard: NSPasteboard = .general) {
        let group = items.filter { $0.status != .running }
        if group.count <= 1 {
            guard let item = group.first else { return }
            pasteboard.clearContents()
            pasteboard.writeObjects(writers(for: representation(for: item)))
            return
        }
        let files = fileURLs(for: group)
        pasteboard.clearContents()
        if files.count >= 1 {
            pasteboard.writeObjects(files as [NSURL])
            if files.count > 1 {
                pasteboard.setPropertyList(
                    files.map(\.path),
                    forType: NSPasteboard.PasteboardType(FileListWriter.filenamesType)
                )
            }
            return
        }
        pasteboard.writeObjects(writers(for: representation(for: group[0])))
    }

    public static func export(_ item: Item) -> [NSPasteboardWriting] {
        writers(for: representation(for: item))
    }

    public static func exportGroup(starting item: Item, selection: [Item]) -> [Item] {
        guard item.status != .running else { return [] }
        let selected = selection.filter { $0.status != .running }
        if selected.contains(where: { $0.id == item.id }), selected.count > 1 {
            return selected
        }
        return [item]
    }

    public static func fileURLs(for items: [Item]) -> [URL] {
        var seen = Set<String>()
        var urls: [URL] = []
        for item in items where item.status != .running {
            for url in representation(for: item).fileURLs {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                let key = url.standardizedFileURL.path
                if seen.insert(key).inserted {
                    urls.append(url)
                }
            }
        }
        return urls
    }

    public static let shelfDragType = NSPasteboard.PasteboardType("local.dropagent.internal-shelf")

    public static func markShelfDrag(on pasteboard: NSPasteboard = .init(name: .drag)) {
        pasteboard.setString("1", forType: shelfDragType)
    }

    public static func isShelfDrag(_ pasteboard: NSPasteboard = .init(name: .drag)) -> Bool {
        guard let value = pasteboard.string(forType: shelfDragType) else { return false }
        return value.isEmpty == false
    }

    public static func clearShelfDrag(on pasteboard: NSPasteboard = .init(name: .drag)) {
        pasteboard.setString("", forType: shelfDragType)
    }

    public static func attachFileListToDragPasteboard(_ urls: [URL]) {
        guard urls.count > 1 else { return }
        let pb = NSPasteboard(name: .drag)
        pb.setPropertyList(
            urls.map(\.path),
            forType: NSPasteboard.PasteboardType(FileListWriter.filenamesType)
        )
        let already = Set(
            ((pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? [])
                .map { $0.standardizedFileURL.path }
        )
        let extra = urls.filter { already.contains($0.standardizedFileURL.path) == false }
        if extra.isEmpty == false {
            pb.writeObjects(extra as [NSURL])
        }
    }

    public static func itemProvider(for items: [Item]) -> NSItemProvider {
        let group = items.filter { $0.status != .running }
        if group.count <= 1 {
            return group.first.map { itemProvider(for: $0) } ?? NSItemProvider()
        }
        let files = fileURLs(for: group)
        if files.count > 1 {
            return NSItemProvider(object: FileListWriter(urls: files))
        }
        if let fileItem = group.first(where: { representation(for: $0).fileURLs.isEmpty == false }) {
            return itemProvider(for: fileItem)
        }
        return itemProvider(for: group[0])
    }

    public static func itemProvider(forClipFiles urls: [URL]) -> NSItemProvider {
        let existing = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        if existing.count > 1 {
            return NSItemProvider(object: FileListWriter(urls: existing))
        }
        if let url = existing.first {
            let provider = NSItemProvider()
            provider.suggestedName = url.lastPathComponent
            provider.registerObject(url as NSURL, visibility: .all)
            return provider
        }
        return NSItemProvider()
    }

    public static func itemProvider(forClip record: ClipRecord, imageURL: URL?) -> NSItemProvider {
        switch record.kind {
        case .text:
            let provider = NSItemProvider()
            if let text = record.text {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.utf8PlainText.identifier,
                    visibility: .all
                ) { completion in
                    completion(Data(text.utf8), nil)
                    return nil
                }
            }
            return provider
        case .url:
            let provider = NSItemProvider()
            if let text = record.text, let url = URL(string: text) {
                provider.registerDataRepresentation(
                    forTypeIdentifier: UTType.url.identifier,
                    visibility: .all
                ) { completion in
                    completion(Data(text.utf8), nil)
                    return nil
                }
                provider.registerObject(url as NSURL, visibility: .all)
                if provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) == false {
                    provider.registerDataRepresentation(
                        forTypeIdentifier: UTType.utf8PlainText.identifier,
                        visibility: .all
                    ) { completion in
                        completion(Data(text.utf8), nil)
                        return nil
                    }
                }
            }
            return provider
        case .image:
            guard let url = imageURL, FileManager.default.fileExists(atPath: url.path) else {
                return NSItemProvider()
            }
            let provider = NSItemProvider()
            provider.suggestedName = url.lastPathComponent
            provider.registerFileRepresentation(
                forTypeIdentifier: UTType.png.identifier,
                fileOptions: [],
                visibility: .all
            ) { completion in
                completion(url, false, nil)
                return nil
            }
            return provider
        case .files:
            let urls = record.filePaths
                .map { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            if urls.count > 1 {
                return NSItemProvider(object: FileListWriter(urls: urls))
            }
            if let url = urls.first {
                let provider = NSItemProvider()
                provider.suggestedName = url.lastPathComponent
                provider.registerFileRepresentation(
                    forTypeIdentifier: UTType.fileURL.identifier,
                    fileOptions: [],
                    visibility: .all
                ) { completion in
                    completion(url, false, nil)
                    return nil
                }
                provider.registerObject(url as NSURL, visibility: .all)
                return provider
            }
            return NSItemProvider()
        }
    }

    public static func itemProvider(for item: Item) -> NSItemProvider {
        let rep = representation(for: item)
        let provider = NSItemProvider()
        if let url = rep.fileURLs.first, FileManager.default.fileExists(atPath: url.path) {
            let type = contentType(for: url)
            provider.suggestedName = url.lastPathComponent
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
                completion(url.dataRepresentation, nil)
                return nil
            }
            provider.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { completion in
                completion(url, false, nil)
                return nil
            }
            provider.registerObject(url as NSURL, visibility: .all)
        }
        if let text = rep.plainText, !provider.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier) {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.utf8PlainText.identifier, visibility: .all) { completion in
                completion(Data(text.utf8), nil)
                return nil
            }
        }
        if let png = rep.pngData, !provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { completion in
                completion(png, nil)
                return nil
            }
        }
        if let web = rep.webURL, !provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all) { completion in
                completion(Data(web.absoluteString.utf8), nil)
                return nil
            }
        }
        return provider
    }

    private static func contentType(for url: URL) -> UTType {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return .folder
        }
        if url.hasDirectoryPath { return .folder }
        if let type = UTType(filenameExtension: url.pathExtension), !type.identifier.isEmpty {
            return type
        }
        return .data
    }

    public static func writers(for representation: PasteboardRepresentation) -> [NSPasteboardWriting] {
        var objects: [NSPasteboardWriting] = []
        objects.append(contentsOf: representation.fileURLs as [NSURL])
        if let text = representation.plainText {
            objects.append(text as NSString)
        }
        if let url = representation.webURL {
            objects.append(url as NSURL)
        }
        if let png = representation.pngData {
            objects.append(NSImage(data: png) ?? NSImage())
        }
        return objects
    }

    private static func representation(forOutput output: URL, fallback: Item) -> PasteboardRepresentation {
        var text: String?
        if let body = try? String(contentsOf: output, encoding: .utf8) {
            text = body
        }
        let png = output.pathExtension.lowercased() == "png" ? pngData(from: output) : nil
        return PasteboardRepresentation(fileURLs: [output], plainText: text, pngData: png, webURL: fallback.kind == .url ? fallback.sourceURL : nil)
    }

    private static func pngData(from url: URL) -> Data? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        if let data = try? Data(contentsOf: url), isPNG(data) {
            return data
        }
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private static func isPNG(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    }

    private static func namedWebFolder(from source: URL, title: String, id: ItemID) -> URL {
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropAgentWebDrag", isDirectory: true)
            .appendingPathComponent(id.rawValue, isDirectory: true)
            .appendingPathComponent(webFolderName(title), isDirectory: true)
        let fm = FileManager.default
        try? fm.removeItem(at: dest.deletingLastPathComponent())
        do {
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: dest)
            return dest
        } catch {
            return source
        }
    }

    private static func webFolderName(_ title: String) -> String {
        let cleaned = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\0", with: "")
        let collapsed = cleaned
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        if collapsed.isEmpty || collapsed == "." || collapsed == ".." {
            return "网站"
        }
        if collapsed.count > 120 {
            return String(collapsed.prefix(120)).trimmingCharacters(in: CharacterSet(charactersIn: "- "))
        }
        return collapsed
    }

    private static func representation(forStaged item: Item) -> PasteboardRepresentation {
        switch item.kind {
        case .pdf, .folder, .file:
            return PasteboardRepresentation(fileURLs: item.parts.map(\.url), plainText: nil, pngData: nil, webURL: nil)
        case .markdown, .clip:
            let text = item.parts.first.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) }
            return PasteboardRepresentation(fileURLs: item.parts.map(\.url), plainText: text, pngData: nil, webURL: nil)
        case .image:
            let png = item.parts.first.flatMap { pngData(from: $0.url) }
            return PasteboardRepresentation(fileURLs: item.parts.map(\.url), plainText: nil, pngData: png, webURL: nil)
        case .url:
            let text = item.sourceURL.absoluteString
            return PasteboardRepresentation(fileURLs: [], plainText: text, pngData: nil, webURL: item.sourceURL)
        case .web:
            let inbox = item.parts.first?.url.deletingLastPathComponent()
            let folder = inbox.map { namedWebFolder(from: $0, title: item.title, id: item.id) }
            let md = item.parts.first { $0.name.hasSuffix(".md") }.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) }
            let png = item.parts.first { $0.name.hasSuffix(".png") }.flatMap { pngData(from: $0.url) }
            return PasteboardRepresentation(
                fileURLs: folder.map { [$0] } ?? item.parts.map(\.url),
                plainText: md,
                pngData: png,
                webURL: item.sourceURL
            )
        }
    }
}

final class FileListWriter: NSObject, NSItemProviderWriting {
    static let filenamesType = "NSFilenamesPboardType"

    let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls
        super.init()
    }

    static var writableTypeIdentifiersForItemProvider: [String] {
        [filenamesType, UTType.fileURL.identifier]
    }

    func loadData(
        withTypeIdentifier typeIdentifier: String,
        forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, (any Error)?) -> Void
    ) -> Progress? {
        if typeIdentifier == Self.filenamesType {
            do {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: urls.map(\.path),
                    format: .xml,
                    options: 0
                )
                completionHandler(data, nil)
            } catch {
                completionHandler(nil, error)
            }
            return nil
        }
        if typeIdentifier == UTType.fileURL.identifier, let first = urls.first {
            completionHandler(first.dataRepresentation, nil)
            return nil
        }
        completionHandler(nil, nil)
        return nil
    }
}
