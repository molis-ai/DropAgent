import Foundation

enum Onboarding {
    static let sampleFileName = "先读我.md"
    static let headline = "材料放下，轻松处理。"
    static let step1Title = "放上来"
    static let step2Title = "选动作"
    static let step3Title = "拖走"
    static let tryTitle = "放入示例文稿"
    static let skipTitle = "我自己添加"
    static let step3Detail = "新文件可拖出。原件不动。"

    static let sampleMarkdown = """
    # 先读我

    这是架子上的一份材料。DropAgent 只处理副本。

    - 选「总结」会得到新的 summary.md
    - 也可以发给右上角的终端
    - 跑完把新文件拖走；原件不动
    """

    static func shouldShow(markerExists: Bool, isEmpty: Bool) -> Bool {
        markerExists == false && isEmpty
    }

    static func step1Detail(captureOK: Bool, captureLabel: String) -> String {
        captureOK ? "拖到架子、⌘V，或 \(captureLabel) 抓当前页" : "拖到架子、⌘V，或用菜单抓当前页"
    }

    static func step2Detail(hasAgent: Bool, hasRecipe: Bool, tuiTitle: String) -> String {
        if hasRecipe { return "总结、翻译，或发给 \(tuiTitle)" }
        if hasAgent { return "发给 \(tuiTitle)。当前终端暂不支持快捷动作。" }
        return "先放着。装好终端后再发给它。"
    }
}
