import AppKit
import DropAgentIngest
import DropAgentShelf
import SwiftUI

struct SourceLinkText: View {
    let url: URL
    var size: CGFloat = 12

    var body: some View {
        let text = url.absoluteString
        if SourceLink.isOpenable(url) {
            Button(text) { SourceLink.open(url) }
                .buttonStyle(.plain)
                .font(.system(size: size))
                .foregroundStyle(Palette.ice)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .accessibilityLabel(Copy.t("打开 \(text)", "Open \(text)"))
        } else {
            Text(text)
                .font(.system(size: size))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
        }
    }
}

enum PanelInspect {
    static func htmlURL(_ item: Item) -> URL? {
        if ReadableHTML.isHTMLFile(item.sourceURL) { return item.parts.first?.url ?? item.sourceURL }
        if let part = item.parts.first(where: { ReadableHTML.isHTMLFile($0.url) }) { return part.url }
        if ReadableHTML.isHTMLFile(URL(fileURLWithPath: item.title)) {
            return item.parts.first?.url
        }
        return nil
    }
}
