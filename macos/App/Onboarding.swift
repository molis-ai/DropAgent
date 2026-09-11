import Foundation

enum Onboarding {
    static let sampleFileName = "DropAgent Sample.pdf"
    static var title: String { Copy.t("放入材料，生成新文件。", "Add a file. Create something new.") }
    static var intro: String {
        Copy.t("用示例 PDF 体验文字提取。原文件保持不变。",
               "Extract text from a sample PDF. Your original stays unchanged.")
    }
    static var tryTitle: String { Copy.t("试用示例 PDF", "Try sample PDF") }
    static var coach: String {
        Copy.t("选择动作，确认后运行。新文件会出现在结果区。",
               "Choose an action, review, then run. New files appear in Results.")
    }
    static var coachDismiss: String { Copy.t("关闭引导", "Dismiss guide") }
    static func shouldShow(markerExists: Bool, isEmpty: Bool) -> Bool { !markerExists && isEmpty }
    static func shouldShowCoach(dismissed: Bool, hasSelection: Bool, isBusy: Bool) -> Bool {
        !dismissed && hasSelection && !isBusy
    }
}
