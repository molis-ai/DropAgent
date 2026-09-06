import Foundation

public struct ItemID: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }
}

public enum ItemKind: String, Codable, Sendable, CaseIterable {
    case pdf
    case image
    case url
    case markdown
    case clip
    case web
    case folder
    case file

    public var tag: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "PNG"
        case .url: return "URL"
        case .markdown: return "MD"
        case .clip: return "CLIP"
        case .web: return "WEB"
        case .folder: return "DIR"
        case .file: return "FILE"
        }
    }

    public var word: String {
        switch self {
        case .pdf: return "文档"
        case .image: return "图片"
        case .url: return "链接"
        case .markdown: return "文稿"
        case .clip: return "剪贴板"
        case .web: return "网站"
        case .folder: return "文件夹"
        case .file: return "文件"
        }
    }
}

public enum ItemStatus: String, Codable, Sendable {
    case idle
    case confirm
    case running
    case done
    case sent
    case failed
}

public enum IsolationShown: String, Codable, Sendable {
    case workspace
    case unconfirmed
    case safeCopy
    case tui
    case none

    public var spokenFact: String? {
        switch self {
        case .workspace:
            return "Workspace Sandbox：Agent 只能写任务工作区"
        case .unconfirmed:
            return "未确认工作区限制，仍在副本目录跑"
        case .safeCopy:
            return "Safe Copy：原文件不会被 DropAgent 覆盖，结果另存"
        case .tui, .none:
            return nil
        }
    }
}

public struct ItemPart: Codable, Equatable, Sendable {
    public var name: String
    public var url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct Item: Codable, Equatable, Sendable {
    public var id: ItemID
    public var kind: ItemKind
    public var title: String
    public var sourceURL: URL
    public var parts: [ItemPart]
    public var status: ItemStatus
    public var recipe: String?
    public var output: URL?
    public var isolationShown: IsolationShown
    public var sourceChecksum: String?
    public var createdAt: Date
    public var event: String
    public var failureReason: String?

    public init(
        id: ItemID = ItemID(),
        kind: ItemKind,
        title: String,
        sourceURL: URL,
        parts: [ItemPart],
        status: ItemStatus = .idle,
        recipe: String? = nil,
        output: URL? = nil,
        isolationShown: IsolationShown = .none,
        sourceChecksum: String? = nil,
        createdAt: Date = Date(),
        event: String = "",
        failureReason: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.sourceURL = sourceURL
        self.parts = parts
        self.status = status
        self.recipe = recipe
        self.output = output
        self.isolationShown = isolationShown
        self.sourceChecksum = sourceChecksum
        self.createdAt = createdAt
        self.event = event
        self.failureReason = failureReason
    }

    public var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: createdAt)
    }

    public var displayTag: String {
        let name = (output?.lastPathComponent ?? title).lowercased()
        if name.hasSuffix(".json") { return "JSON" }
        if kind == .image {
            return Self.imageTag(from: parts.first?.name ?? title)
        }
        if kind == .file {
            return Self.fileTag(from: parts.first?.name ?? title)
        }
        if kind == .markdown {
            return Self.markdownTag(from: output?.lastPathComponent ?? title)
        }
        return kind.tag
    }

    private static func markdownTag(from filename: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension.uppercased()
        if ext.isEmpty || ext == "MD" || ext == "TXT" || ext == "MARKDOWN" { return "MD" }
        if (1...5).contains(ext.count) { return ext }
        return "MD"
    }

    private static func imageTag(from filename: String) -> String {
        let name = filename.lowercased()
        if name.hasSuffix(".jpg") || name.hasSuffix(".jpeg") { return "JPG" }
        if name.hasSuffix(".heic") || name.hasSuffix(".heif") { return "HEIC" }
        if name.hasSuffix(".gif") { return "GIF" }
        if name.hasSuffix(".webp") { return "WEBP" }
        if name.hasSuffix(".tif") || name.hasSuffix(".tiff") { return "TIFF" }
        return "PNG"
    }

    private static func fileTag(from filename: String) -> String {
        let ext = URL(fileURLWithPath: filename).pathExtension.uppercased()
        if (1...4).contains(ext.count) { return ext }
        return "FILE"
    }

    public var metaLine: String {
        switch status {
        case .idle:
            if kind == .web, event.isEmpty == false {
                return "\(kind.word) · \(event)"
            }
            return "\(kind.word) · 待处理"
        case .confirm:
            return "\(kind.word) · \(recipe ?? "动作") · 未运行"
        case .running:
            return event.isEmpty ? kind.word : event
        case .done:
            return sourceURL.isFileURL ? "\(kind.word) · 来自 \(sourceURL.lastPathComponent)" : kind.word
        case .sent:
            return kind.word
        case .failed:
            return failureReason ?? "\(kind.word) · 失败"
        }
    }
}
