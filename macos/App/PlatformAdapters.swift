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
}
