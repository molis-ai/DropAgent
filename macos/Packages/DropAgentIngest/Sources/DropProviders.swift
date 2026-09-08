import AppKit
import DropAgentShelf
import Foundation
import UniformTypeIdentifiers

extension IngestService {
    @MainActor
    public func admitProviders(_ providers: [NSItemProvider], capturePages: Bool = true) async -> AdmitResult {
        var urls: [URL] = []
        var admitted: [Item] = []
        var failures: [AdmitFailure] = []
        var pageCaptureIDs: [ItemID] = []
        var seenPaths = Set<String>()
        for provider in providers {
            if let url = await DropProviders.fileOrHTTPURL(provider) {
                let key = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
                if seenPaths.insert(key).inserted {
                    urls.append(url)
                }
                continue
            }
            if let data = await DropProviders.imageData(provider) {
                do {
                    admitted.append(try admitImageData(data))
                } catch let error as IngestError {
                    failures.append(AdmitFailure(url: URL(fileURLWithPath: "/dropped-image"), error: error))
                } catch {
                    failures.append(AdmitFailure(url: URL(fileURLWithPath: "/dropped-image"), error: .unsupported))
                }
                continue
            }
            if let text = await DropProviders.string(provider) {
                do {
                    let outcome = try admitTextPayload(text, capturePages: capturePages)
                    admitted.append(outcome.item)
                    if outcome.needsPageCapture {
                        pageCaptureIDs.append(outcome.item.id)
                    }
                } catch let error as IngestError {
                    failures.append(AdmitFailure(url: URL(fileURLWithPath: "/dropped-text"), error: error))
                } catch {
                    failures.append(AdmitFailure(url: URL(fileURLWithPath: "/dropped-text"), error: .unsupported))
                }
            }
        }
        let fromURLs = admit(urls: urls, capturePages: capturePages)
        return AdmitResult(
            admitted: admitted + fromURLs.admitted,
            failures: failures + fromURLs.failures,
            pageCaptureIDs: pageCaptureIDs + fromURLs.pageCaptureIDs
        )
    }
}

@MainActor
enum DropProviders {
    static func fileOrHTTPURL(_ provider: NSItemProvider) async -> URL? {
        if provider.canLoadObject(ofClass: URL.self), let url = try? await loadURL(provider), url.isFileURL || url.scheme == "http" || url.scheme == "https" {
            return url
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let url = try? await loadFileURL(provider) {
            return url
        }
        let fileTypes = provider.registeredTypeIdentifiers.filter { id in
            id != UTType.utf8PlainText.identifier
                && id != UTType.plainText.identifier
                && id != UTType.url.identifier
                && id != UTType.png.identifier
                && id != UTType.image.identifier
        }
        for type in fileTypes {
            if let url = try? await loadKeptFile(provider, type: type) {
                return url
            }
        }
        if provider.canLoadObject(ofClass: NSString.self),
           let text = try? await loadString(provider),
           let url = URL(string: text), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        return nil
    }

    static func imageData(_ provider: NSItemProvider) async -> Data? {
        let types = [
            UTType.png.identifier,
            UTType.jpeg.identifier,
            UTType.tiff.identifier,
            UTType.heic.identifier,
            UTType.gif.identifier,
            UTType.webP.identifier,
            UTType.image.identifier,
        ]
        for type in types where provider.hasItemConformingToTypeIdentifier(type) {
            if let data = try? await loadData(provider, type: type) {
                if let image = NSImage(data: data),
                   let tiff = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    return png
                }
                return data
            }
        }
        return nil
    }

    static func string(_ provider: NSItemProvider) async -> String? {
        guard provider.canLoadObject(ofClass: NSString.self) else { return nil }
        return try? await loadString(provider)
    }

    private static func loadURL(_ provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? IngestError.unsupported)
                }
            }
        }
    }

    private static func loadFileURL(_ provider: NSItemProvider) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else if let text = item as? String, let url = URL(string: text) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? IngestError.unsupported)
                }
            }
        }
    }

    private static func loadString(_ provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadObject(ofClass: NSString.self) { object, error in
                if let text = object as? String {
                    continuation.resume(returning: text)
                } else if let text = object as? NSString {
                    continuation.resume(returning: text as String)
                } else {
                    continuation.resume(throwing: error ?? IngestError.unsupported)
                }
            }
        }
    }

    private static func loadKeptFile(_ provider: NSItemProvider, type: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                guard let url else {
                    continuation.resume(throwing: error ?? IngestError.unsupported)
                    return
                }
                let dest = FileManager.default.temporaryDirectory
                    .appendingPathComponent("DropAgentDrop", isDirectory: true)
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
                    .appendingPathComponent(url.lastPathComponent)
                do {
                    try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: dest)
                    continuation.resume(returning: dest)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func loadData(_ provider: NSItemProvider, type: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: error ?? IngestError.unsupported)
                }
            }
        }
    }
}
