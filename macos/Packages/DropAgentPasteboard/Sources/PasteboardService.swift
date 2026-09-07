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
        pasteboard.clearContents()
        pasteboard.writeObjects(writers(for: representation(for: item)))
    }

    public static func export(_ item: Item) -> [NSPasteboardWriting] {
        writers(for: representation(for: item))
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
