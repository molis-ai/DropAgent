import Foundation

enum StagedPreview {
    enum Mode: Equatable {
        case markdown
        case json
        case code
    }

    static func mode(title: String, body: String) -> Mode {
        let ext = URL(fileURLWithPath: title).pathExtension.lowercased()
        if ext == "json" { return ResultJSON.pretty(body) == nil ? .code : .json }
        if isProse(ext) { return .markdown }
        if ResultJSON.pretty(body) != nil { return .json }
        return .code
    }

    private static func isProse(_ ext: String) -> Bool {
        ext.isEmpty || ext == "md" || ext == "txt" || ext == "markdown"
    }
}
