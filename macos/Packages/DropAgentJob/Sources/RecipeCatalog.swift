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
        case .brief: return "新交付"
        }
    }

    public var fullTitle: String {
        switch self {
        case .summarize: return "总结文件"
        case .extract: return "提取结构化信息"
        case .translate: return "翻译并保留格式"
        case .redact: return "敏感信息脱敏"
        case .toMarkdown: return "转换为 Markdown"
        case .brief: return "根据多份材料生成一个新交付"
        }
    }

    public var minimumCount: Int {
        self == .brief ? 2 : 1
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
                prompt: """
                阅读当前工作目录里的全部材料。只使用相对路径，不要访问目录之外的文件。
                用中文写一份简洁 Markdown 总结，作为最终回复。
                不要修改已有文件。
                """
            )
        case .extract:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .markdown, .clip, .web],
                outputFileName: "extracted.json",
                needsNetwork: false,
                prompt: """
                阅读当前工作目录里的材料。只使用相对路径。
                提取结构化信息，最终回复必须是 JSON 对象。
                不要修改已有文件。
                """
            )
        case .translate:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.markdown, .clip, .pdf, .web],
                outputFileName: "translated.md",
                needsNetwork: true,
                prompt: """
                阅读当前工作目录里的材料。只使用相对路径。
                翻译成中文并尽量保留原有结构，最终回复为 Markdown。
                不要修改已有文件。
                """
            )
        case .redact:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.markdown, .clip, .pdf, .web],
                outputFileName: "redacted.md",
                needsNetwork: false,
                prompt: """
                阅读当前工作目录里的材料。只使用相对路径。
                把姓名、电话、邮箱、密钥、金额等敏感信息替换为 [REDACTED]，最终回复为 Markdown。
                不要修改已有文件。
                """
            )
        case .toMarkdown:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .url, .markdown, .clip, .web],
                outputFileName: "converted.md",
                needsNetwork: false,
                prompt: """
                阅读当前工作目录里的材料。只使用相对路径。
                转成结构清楚的 Markdown，作为最终回复。
                不要修改已有文件。
                """
            )
        case .brief:
            return RecipeSpec(
                id: id,
                acceptedKinds: [.pdf, .image, .markdown, .clip, .url, .web, .folder, .file],
                outputFileName: "brief.md",
                needsNetwork: false,
                prompt: """
                阅读当前工作目录里的全部材料。只使用相对路径。
                根据这些材料生成一份可交付的 briefing（Markdown）。
                不要修改已有文件。
                """
            )
        }
    }
}
