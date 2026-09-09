import AppKit
import Foundation
import ImageIO
import Vision

public enum ImageTextError: Error, Equatable, Sendable {
    case unreadable
}

public struct ImageTextLine: Equatable, Sendable {
    public var text: String
    public var confidence: Float

    public init(text: String, confidence: Float) {
        self.text = text
        self.confidence = confidence
    }
}

public enum ImageText: Sendable {
    public static let lowConfidence: Float = 0.5

    public static func languages(choiceID: String) -> [String] {
        switch choiceID {
        case "zh": return ["zh-Hans"]
        case "en": return ["en-US"]
        default: return ["zh-Hans", "en-US"]
        }
    }

    public static func recognize(url: URL, languages: [String]) async throws -> [ImageTextLine] {
        try await Task.detached(priority: .userInitiated) {
            try recognizeSync(url: url, languages: languages)
        }.value
    }

    public static func markdown(pages: [(name: String, lines: [ImageTextLine])]) -> String {
        guard pages.isEmpty == false else { return "没有识别到文字。\n" }
        var blocks: [String] = []
        for page in pages {
            var lines: [String] = []
            if pages.count > 1 {
                lines.append("## \(page.name)")
                lines.append("")
            }
            if page.lines.isEmpty {
                lines.append("没有识别到文字。")
            } else {
                for line in page.lines {
                    if line.confidence < lowConfidence {
                        lines.append("\(line.text)（待确认）")
                    } else {
                        lines.append(line.text)
                    }
                }
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        return blocks.joined(separator: "\n\n") + "\n"
    }

    private static func recognizeSync(url: URL, languages: [String]) throws -> [ImageTextLine] {
        guard let cgImage = cgImage(at: url) else { throw ImageTextError.unreadable }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let best = observation.topCandidates(1).first else { return nil }
            let text = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false else { return nil }
            return ImageTextLine(text: text, confidence: best.confidence)
        }
    }

    private static func cgImage(at url: URL) -> CGImage? {
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            return image
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
