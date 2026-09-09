import DropAgentShelf
import SwiftUI

struct ContentStage: View {
    let item: Item

    var body: some View {
        ScrollView {
            ResultPreview(item: item, expanded: true)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: LivePanelChrome.previewStageHeight)
        .background(Palette.panel)
        .clipShape(RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                .stroke(Palette.line)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Copy.t("内容 \(item.title)", "Content \(item.title)"))
        .accessibilityIdentifier("content-stage")
    }
}
