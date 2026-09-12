import Foundation

public struct RecipeChoice: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
}

public struct RecipeChoiceGroup: Equatable, Sendable {
    public var label: String
    public var hint: String
    public var choices: [RecipeChoice]
    public var defaultID: String
}

extension RecipeCatalog {
    public static func choices(for id: RecipeID) -> RecipeChoiceGroup {
        switch id {
        case .summarize:
            return RecipeChoiceGroup(
                label: "篇幅",
                hint: "",
                choices: [
                    RecipeChoice(id: "short", title: "短 · 200 字"),
                    RecipeChoice(id: "medium", title: "中 · 500 字"),
                    RecipeChoice(id: "long", title: "长 · 1000 字"),
                    RecipeChoice(id: "outline", title: "提纲")
                ],
                defaultID: "medium"
            )
        case .extract:
            return RecipeChoiceGroup(
                label: "抽取",
                hint: "",
                choices: [
                    RecipeChoice(id: "points", title: "要点"),
                    RecipeChoice(id: "todos", title: "待办"),
                    RecipeChoice(id: "quotes", title: "引用与数据"),
                    RecipeChoice(id: "json", title: "全量 JSON")
                ],
                defaultID: "json"
            )
        case .imageText:
            return RecipeChoiceGroup(
                label: "语言",
                hint: "本机识别，不发送",
                choices: [
                    RecipeChoice(id: "zh-en", title: "中英"),
                    RecipeChoice(id: "zh", title: "中文"),
                    RecipeChoice(id: "en", title: "English")
                ],
                defaultID: "zh-en"
            )
        case .pdfText:
            return RecipeChoiceGroup(
                label: "",
                hint: "",
                choices: [],
                defaultID: ""
            )
        case .translate:
            return RecipeChoiceGroup(
                label: "译成",
                hint: "源语言自动识别",
                choices: [
                    RecipeChoice(id: "zh", title: "中文"),
                    RecipeChoice(id: "en", title: "English"),
                    RecipeChoice(id: "ja", title: "日本語"),
                    RecipeChoice(id: "ko", title: "한국어")
                ],
                defaultID: "zh"
            )
        case .redact:
            return RecipeChoiceGroup(
                label: "范围",
                hint: "",
                choices: [
                    RecipeChoice(id: "contact", title: "联系方式"),
                    RecipeChoice(id: "ids", title: "金额证件"),
                    RecipeChoice(id: "all", title: "全套")
                ],
                defaultID: "all"
            )
        case .toMarkdown:
            return RecipeChoiceGroup(
                label: "版式",
                hint: "",
                choices: [
                    RecipeChoice(id: "structure", title: "保结构"),
                    RecipeChoice(id: "body", title: "只要正文"),
                    RecipeChoice(id: "toc", title: "带目录")
                ],
                defaultID: "structure"
            )
        case .brief:
            return RecipeChoiceGroup(
                label: "篇幅",
                hint: "",
                choices: [
                    RecipeChoice(id: "page", title: "一页"),
                    RecipeChoice(id: "full", title: "完整一份")
                ],
                defaultID: "full"
            )
        case .shortcut:
            return RecipeChoiceGroup(label: "", hint: "", choices: [], defaultID: "")
        }
    }

    public static func resolvedChoiceID(_ id: RecipeID, optionID: String?) -> String {
        let group = choices(for: id)
        if let optionID, group.choices.contains(where: { $0.id == optionID }) {
            return optionID
        }
        return group.defaultID
    }

    public static func prompt(for id: RecipeID, choiceID: String? = nil) -> String {
        let choice = resolvedChoiceID(id, optionID: choiceID)
        return fileGuardrail(outputFileName: outputFileName(for: id))
            + "\n" + instruction(for: id, choiceID: choice) + "\n"
    }

    public static func fileGuardrail(outputFileName: String) -> String {
        """
        阅读当前工作目录里的材料。只使用相对路径，不要访问目录之外的文件。
        不要修改已有材料文件。
        把完整结果写成文件：\(outputFileName)
        该文件里必须是交付正文，不要写「已完成」「已写入 \(outputFileName)」这类说明。
        不要只在对话里口头回复；结果区只会收取这一份文件。
        """
    }

    private static func instruction(for id: RecipeID, choiceID: String) -> String {
        switch id {
        case .summarize:
            switch choiceID {
            case "short":
                return "用中文写一份约 200 字的短总结（Markdown）。"
            case "long":
                return "用中文写一份约 1000 字的长总结（Markdown）。"
            case "outline":
                return "用中文只写提纲，不要展开成段落（Markdown）。"
            default:
                return "用中文写一份约 500 字的简洁 Markdown 总结。"
            }
        case .extract:
            switch choiceID {
            case "points":
                return "提取要点列表，写成 Markdown。"
            case "todos":
                return "提取待办事项，写成 Markdown。"
            case "quotes":
                return "提取引用与数据，写成 Markdown。"
            default:
                return "提取结构化信息，写成 JSON 对象。"
            }
        case .imageText:
            return "用本机识别图片中的文字，不要调用终端 Agent，不要补写图里没有的内容。"
        case .pdfText:
            return "抽出 PDF 里已经嵌着的文字，不要调用终端 Agent，不要做扫描件 OCR。"
        case .translate:
            let target: String
            switch choiceID {
            case "en": target = "English"
            case "ja": target = "日本語"
            case "ko": target = "한국어"
            default: target = "中文"
            }
            return "源语言自动识别。翻译成 \(target) 并尽量保留原有结构，写成 Markdown。"
        case .redact:
            switch choiceID {
            case "contact":
                return "把电话、邮箱、地址等联系方式替换为 [REDACTED]，写成 Markdown。"
            case "ids":
                return "把金额、证件号、账号等替换为 [REDACTED]，写成 Markdown。"
            default:
                return "把姓名、电话、邮箱、密钥、金额等敏感信息替换为 [REDACTED]，写成 Markdown。"
            }
        case .toMarkdown:
            switch choiceID {
            case "body":
                return "转成只要正文的 Markdown，去掉导航和页眉页脚。"
            case "toc":
                return "转成带目录的结构清楚的 Markdown。"
            default:
                return "转成尽量保留原有结构的 Markdown。"
            }
        case .brief:
            let length = choiceID == "page"
                ? "大约一页。"
                : "完整一份，把各份材料里该保留的内容都写进去。"
            return """
            用中文把这些材料写成一份合成稿（Markdown）。
            正文必须来自材料：保留结论、数字、日期、人名、待办和关键原话；重复的合并，说法冲突的并列并标明来源。
            不要只交代「已整合」或「已生成 \(outputFileName(for: .brief))」。
            篇幅：\(length)
            """
        case .shortcut:
            return "按用户给出的说明处理当前工作目录里的材料，写成 Markdown。"
        }
    }
}
