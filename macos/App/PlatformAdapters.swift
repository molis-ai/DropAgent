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
        contentTypes.map { NSPasteboard.PasteboardType($0.identifier) } + [
            .URL,
            .string,
            .html,
            .rtf,
            NSPasteboard.PasteboardType("public.item"),
            NSPasteboard.PasteboardType("public.url-name"),
            NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType"),
            NSPasteboard.PasteboardType("com.apple.webkit.WebURLsWithTitles"),
            NSPasteboard.PasteboardType("org.chromium.drag-dummy-type"),
            NSPasteboard.PasteboardType("org.chromium.bookmark-entry"),
            NSPasteboard.PasteboardType("org.chromium.bookmark-dictionary-list"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            .fileURL,
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-content-type"),
            NSPasteboard.PasteboardType("NSPromiseContentsPboardType"),
        ]
    }
}
