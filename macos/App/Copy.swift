import DropAgentJob
import DropAgentShelf
import Foundation

enum Copy {
    nonisolated(unsafe) static var language: AppLanguage = .system

    static func t(_ zh: String, _ en: String) -> String {
        language.resolved == .en ? en : zh
    }

    static var htmlExtractedHint: String {
        t("已提取 HTML 正文；原网页布局未保留。", "Text extracted from HTML. The original page layout is not preserved.")
    }

    static var stageEditHint: String {
        t("正在编辑副本。原文件保持不变。", "Editing a copy. The original stays unchanged.")
    }

    static var stageReadHint: String {
        t("点击编辑副本", "Click to edit the copy")
    }

    static func kindWord(_ kind: ItemKind) -> String {
        switch kind {
        case .pdf: return t("文档", "Document")
        case .image: return t("图片", "Image")
        case .url: return t("链接", "Link")
        case .markdown: return t("文稿", "Note")
        case .clip: return t("剪贴板", "Clipboard")
        case .web: return t("网站", "Page")
        case .folder: return t("文件夹", "Folder")
        case .file: return t("文件", "File")
        }
    }

    static func recipeSettings(_ id: RecipeID) -> String {
        switch id {
        case .imageText: return t("图片文字提取", "Image text")
        case .pdfText: return t("PDF 文字提取", "PDF text")
        default: return recipeShort(id)
        }
    }

    static func recipeShort(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("总结", "Summarize")
        case .extract: return t("提取信息", "Extract data")
        case .imageText: return t("提取文字", "Extract text")
        case .pdfText: return t("提取文字", "Extract text")
        case .translate: return t("翻译", "Translate")
        case .redact: return t("脱敏", "Redact")
        case .toMarkdown: return t("转为 Markdown", "To Markdown")
        case .brief: return t("整合", "Combine")
        case .shortcut: return t("自定义动作", "Custom action")
        }
    }

    static func recipeFull(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("总结文件", "Summarize the file")
        case .extract: return t("提取结构化信息", "Extract structured data")
        case .imageText: return t("提取图片文字", "Extract image text")
        case .pdfText: return t("提取 PDF 文字", "Extract PDF text")
        case .translate: return t("翻译文件", "Translate the file")
        case .redact: return t("敏感信息脱敏", "Redact sensitive information")
        case .toMarkdown: return t("转换为 Markdown", "Convert to Markdown")
        case .brief: return t("整合多份材料", "Combine files")
        case .shortcut: return t("快捷动作", "Shortcut action")
        }
    }

    static func recipeBlurb(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("提炼重点，生成摘要", "Turn key points into a summary.")
        case .extract: return t("提取要点、待办或结构化数据", "Extract key points, tasks, or structured data.")
        case .imageText: return t("在本机识别图片中的文字", "Recognize text on your Mac.")
        case .pdfText: return t("在本机提取 PDF 中可选择的文字", "Extract selectable PDF text on your Mac.")
        case .translate: return t("译为指定语言，尽量保留格式", "Translate while preserving formatting where possible.")
        case .redact: return t("移除联系方式、证件等敏感信息", "Remove contact details, IDs, and other sensitive data.")
        case .toMarkdown: return t("生成可编辑的 Markdown 文件", "Create an editable Markdown file.")
        case .brief: return t("将多份材料整理为一份文档", "Combine several files into one document.")
        case .shortcut: return t("在副本上执行自定义指令", "Run a custom instruction on a copy.")
        }
    }

    static var otherShort: String { t("对话", "Chat") }

    static var otherBlurb: String {
        t("将指令和选中材料发送给 Agent 终端", "Send instructions and selected files to the agent terminal.")
    }

    static func recipeStored(_ stored: String?) -> String {
        guard let stored, stored.isEmpty == false else { return t("动作", "Action") }
        if let id = RecipeID.fromStored(stored) { return recipeFull(id) }
        return stored
    }

    static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
