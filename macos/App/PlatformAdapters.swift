import AppKit
import DropAgentIngest
import Foundation
import UniformTypeIdentifiers

struct SystemClipboard: ClipboardReading {
    func read() -> ClipboardPayload {
        ClipboardPayload.from(pasteboard: .general)
    }
}

enum IncomingDrop {
    static let contentTypes: [UTType] = [
        .fileURL,
        .url,
        .utf8PlainText,
        .png,
        .tiff,
        .jpeg,
        .gif,
        .webP,
        .heic,
        .image,
    ]

    static var draggedTypes: [NSPasteboard.PasteboardType] {
        contentTypes.map { NSPasteboard.PasteboardType($0.identifier) }
    }

    static func admit(pasteboard: NSPasteboard, ingest: IngestService) -> AdmitResult {
        switch ClipboardPayload.from(pasteboard: pasteboard) {
        case .empty:
            return AdmitResult(admitted: [], failures: [])
        case .files(let urls):
            return ingest.admit(urls: urls)
        case .image(let data):
            do {
                return AdmitResult(admitted: [try ingest.admitImageData(data)], failures: [])
            } catch let error as IngestError {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clipboard.png"), error: error)])
            } catch {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clipboard.png"), error: .unsupported)])
            }
        case .text(let text):
            do {
                return AdmitResult(admitted: [try ingest.admitPlainText(text)], failures: [])
            } catch let error as IngestError {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clip.txt"), error: error)])
            } catch {
                return AdmitResult(admitted: [], failures: [AdmitFailure(url: URL(fileURLWithPath: "/clip.txt"), error: .unsupported)])
            }
        }
    }
}
