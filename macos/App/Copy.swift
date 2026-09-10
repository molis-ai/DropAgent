import DropAgentJob
import DropAgentShelf
import Foundation

enum Copy {
    nonisolated(unsafe) static var language: AppLanguage = .system

    static func t(_ zh: String, _ en: String) -> String {
        language.resolved == .en ? en : zh
    }

    static var htmlExtractedHint: String {
        t("从 HTML 抽出的正文，不是网页预览。", "Extracted from HTML. This is not a page preview.")
    }

    static var stageEditHint: String {
        t("改的是副本，原件不动。", "Editing the copy. The original stays put.")
    }

    static var stageReadHint: String {
        t("点一下开始改", "Click to edit")
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

    static func recipeShort(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("总结", "Summarize")
        case .extract: return t("抽取", "Extract")
        case .imageText: return t("文字提取", "Get Text")
        case .pdfText: return t("文字提取", "Get Text")
        case .translate: return t("翻译", "Translate")
        case .redact: return t("脱敏", "Redact")
        case .toMarkdown: return t("转 MD", "To Markdown")
        case .brief: return t("整合", "Combine")
        case .shortcut: return t("快捷", "Shortcut")
        }
    }

    static func recipeFull(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("总结文件", "Summarize the file")
        case .extract: return t("提取结构化信息", "Extract structured data")
        case .imageText: return t("提取图片文字", "Get text from the image")
        case .pdfText: return t("提取 PDF 文字", "Get text from the PDF")
        case .translate: return t("翻译并保留格式", "Translate and keep formatting")
        case .redact: return t("敏感信息脱敏", "Redact sensitive information")
        case .toMarkdown: return t("转换为 Markdown", "Convert to Markdown")
        case .brief: return t("把几份材料整合成一份", "Combine several items into one document")
        case .shortcut: return t("快捷动作", "Shortcut action")
        }
    }

    static func recipeBlurb(_ id: RecipeID) -> String {
        switch id {
        case .summarize: return t("收成一篇短文，原件不动", "A short note. Original stays put.")
        case .extract: return t("抽出要点、待办或数据", "Pull out points, todos, or data.")
        case .imageText: return t("本机认出图里的字，不发送", "Read the words on-device. Nothing is sent.")
        case .pdfText: return t("抽出 PDF 里可选中的字，不发送", "Pull selectable PDF text on-device. Nothing is sent.")
        case .translate: return t("译成指定语言，尽量留版式", "Translate and keep the layout.")
        case .redact: return t("去掉联系方式、证件等敏感信息", "Strip contacts, IDs, and similar private bits.")
        case .toMarkdown: return t("转成可编辑的 Markdown", "Turn it into editable Markdown.")
        case .brief: return t("选几份，合成一份新稿", "Combine several items into one document.")
        case .shortcut: return t("在副本里跑你写的那句话", "Run your instruction on a copy.")
        }
    }

    static var otherShort: String { t("其他", "Other") }

    static var otherBlurb: String {
        t("写一句话，连同选中材料发给终端", "Write a line and send the selection to the terminal.")
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
