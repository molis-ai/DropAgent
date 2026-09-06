import AppKit
import Foundation

public extension ClipboardPayload {
    static func from(pasteboard: NSPasteboard) -> ClipboardPayload {
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty {
            return .files(urls)
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let http = urls.first(where: { $0.scheme == "http" || $0.scheme == "https" })
        {
            return .text(http.absoluteString)
        }
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let tiff = images.first?.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return .image(png)
        }
        if let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return .text(text)
        }
        if let rtf = pasteboard.data(forType: .rtf), let text = plainText(fromRTF: rtf) {
            return .text(text)
        }
        return .empty
    }

    static func plainText(fromRTF data: Data) -> String? {
        guard let attributed = NSAttributedString(rtf: data, documentAttributes: nil) else { return nil }
        let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

public struct PasteboardClipboard: ClipboardReading {
    private let payload: ClipboardPayload

    public init(_ pasteboard: NSPasteboard) {
        payload = .from(pasteboard: pasteboard)
    }

    public func read() -> ClipboardPayload {
        payload
    }
}
