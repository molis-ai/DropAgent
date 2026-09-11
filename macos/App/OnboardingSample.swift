import AppKit
import CoreText
import DropAgentShelf

/// A selectable-text PDF. Admission and extraction use the normal product paths.
enum OnboardingSample {
    @MainActor
    static func write(to url: URL) throws {
        let data = NSMutableData()
        var page = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(data: data),
              let context = CGContext(consumer: consumer, mediaBox: &page, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(page)
        let title = Copy.t("周五工作备忘", "Friday studio notes")
        let body = Copy.t(
            "\n\n下周一把季度报告发给财务。附件包括一份 PDF 和三张产品截图。\n\n待办事项\n确认报告中的收入数字。\n把产品截图放进附件文件夹。\n请林同学在周五前补齐客户反馈。\n\n这是一份可以自由试用的示例文件。\n提取文字后，你会得到 pdf.md。原 PDF 保持不变。",
            "\n\nSend the quarterly report to finance on Monday. Include one PDF and three product screenshots.\n\nNext steps\nCheck the revenue figures in the report.\nPut the screenshots in the attachments folder.\nAsk Lin to add customer feedback by Friday.\n\nThis sample is yours to experiment with.\nExtract its text to get pdf.md. The original PDF stays unchanged."
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        let text = NSMutableAttributedString(string: title + body, attributes: [
            .font: NSFont.systemFont(ofSize: 15),
            .foregroundColor: NSColor(calibratedWhite: 0.18, alpha: 1),
            .paragraphStyle: paragraph,
        ])
        text.addAttributes([.font: NSFont.systemFont(ofSize: 27, weight: .semibold)], range: NSRange(location: 0, length: (title as NSString).length))
        let frame = CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(text), CFRange(),
            CGPath(rect: page.insetBy(dx: 48, dy: 60), transform: nil), nil
        )
        CTFrameDraw(frame, context)
        context.endPDFPage()
        context.closePDF()
        try (data as Data).write(to: url, options: .atomic)
    }

    static func contains(_ item: Item) -> Bool {
        let sampleRoot = DropAgentPaths.root.appendingPathComponent("Samples", isDirectory: true).standardizedFileURL.path + "/"
        return item.kind == .pdf && item.title == Onboarding.sampleFileName
            && item.sourceURL.standardizedFileURL.path.hasPrefix(sampleRoot)
    }
}
