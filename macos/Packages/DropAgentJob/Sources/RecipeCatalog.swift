import DropAgentShelf
import Foundation

public enum RecipeID: String, Codable, Sendable, CaseIterable {
    case summarize
    case extract
    case translate
    case redact
    case toMarkdown
    case brief

    public var shortTitle: String {
        switch self {
        case .summarize: return "总结"
        case .extract: return "抽取"
        case .translate: return "翻译"
        case .redact: return "脱敏"
        case .toMarkdown: return "转 MD"
        case .brief: return "整合"
        }
    }

    public var fullTitle: String {
        switch self {
        case .summarize: return "总结文件"
        case .extract: return "提取结构化信息"
        case .translate: return "翻译并保留格式"
        case .redact: return "敏感信息脱敏"
        case .toMarkdown: return "转换为 Markdown"
        case .brief: return "把几份材料整合成一份"
        }
    }

    public var minimumCount: Int {
        self == .brief ? 2 : 1
    }

    public static func fromStored(_ stored: String?) -> RecipeID? {
        guard let stored, stored.isEmpty == false else { return nil }
        if let id = RecipeID(rawValue: stored) { return id }
        switch stored {
        case "新交付", "根据多份材料生成一个新交付", "Brief", "Combine":
            return .brief
        default:
            return allCases.first { $0.fullTitle == stored || $0.shortTitle == stored }
        }
    }
}

public struct RecipeSpec: Equatable, Sendable {
    public var id: RecipeID
    public var acceptedKinds: Set<ItemKind>
    public var outputFileName: String
    public var needsNetwork: Bool
    public var prompt: String

    public var shortTitle: String { id.shortTitle }
    public var fullTitle: String { id.fullTitle }

    public var outputKind: ItemKind {
        switch URL(fileURLWithPath: outputFileName).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp":
            return .image
        case "pdf":
            return .pdf
        default:
            return .markdown
        }
    }
}

public enum RecipeCatalog {
    public static let all: [RecipeSpec] = RecipeID.allCases.map(spec)

    public static func spec(_ id: RecipeID) -> RecipeSpec {
        switch id {
        case .summarize:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .markdown, .clip, .url, .web, .folder],
                outputFileName: "summary.md",
                needsNetwork: false,
                prompt: prompt(for: id)
            )
        case .extract:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .markdown, .clip, .web],
                outputFileName: "extracted.json",
                needsNetwork: false,
                prompt: prompt(for: id)
            )
        case .translate:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.markdown, .clip, .pdf, .web],
                outputFileName: "translated.md",
                needsNetwork: true,
                prompt: prompt(for: id)
            )
        case .redact:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.markdown, .clip, .pdf, .web],
                outputFileName: "redacted.md",
                needsNetwork: false,
                prompt: prompt(for: id)
            )
        case .toMarkdown:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .url, .markdown, .clip, .web],
                outputFileName: "converted.md",
                needsNetwork: false,
                prompt: prompt(for: id)
            )
        case .brief:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .markdown, .clip, .url, .web, .folder, .file],
                outputFileName: "brief.md",
                needsNetwork: false,
                prompt: prompt(for: id)
            )
        }
    }
}
