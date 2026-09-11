import PDFKit
import SwiftUI

struct PDFContentView: NSViewRepresentable {
    var url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.displaysPageBreaks = true
        view.setAccessibilityLabel(Copy.t("PDF 预览，可滚动和选择文字", "PDF preview. Scroll or select text."))
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        view.backgroundColor = Palette.paper2NS
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
