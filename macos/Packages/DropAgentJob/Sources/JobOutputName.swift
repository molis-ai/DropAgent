import Foundation

public enum JobOutputName {
    public static func markdown(originalTitle: String, action: String) -> String {
        "\(safe(stem(originalTitle)))-\(safe(action)).md"
    }

    private static func stem(_ title: String) -> String {
        URL(fileURLWithPath: title).deletingPathExtension().lastPathComponent
    }

    public static func safe(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let mapped = trimmed.map { character -> Character in
            if character.isNewline || character == "/" || character == "\\" || character == ":" || character == "\0" {
                return "-"
            }
            return character
        }
        let collapsed = String(mapped)
            .replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".- "))
        if collapsed.isEmpty { return "file" }
        return String(collapsed.prefix(48))
    }
}
