import Foundation

public enum RecipeOutput {
    public static func finalize(_ text: String, fileName: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fileName.lowercased().hasSuffix(".json") else { return trimmed }
        return unwrapJSON(trimmed)
    }

    public static func finalizeFile(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let raw = try String(contentsOf: url, encoding: .utf8)
        let cleaned = finalize(raw, fileName: url.lastPathComponent)
        if cleaned != raw {
            try cleaned.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private static func unwrapJSON(_ text: String) -> String {
        if isJSON(text) { return text }
        guard text.hasPrefix("```") else { return text }
        var lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return text }
        lines.removeFirst()
        if lines.last?.hasPrefix("```") == true {
            lines.removeLast()
        }
        let inner = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return isJSON(inner) ? inner : text
    }

    private static func isJSON(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8), data.isEmpty == false else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
