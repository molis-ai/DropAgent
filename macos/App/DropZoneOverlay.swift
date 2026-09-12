import SwiftUI

struct DropZoneOverlay: View {
    let title: String
    var subtitle: String = ""
    let offered: Bool
    let hot: Bool
    var reduceMotion: Bool

    var body: some View {
        let visible = hot || offered
        return ZStack {
            Palette.panel.opacity(hot ? 0.42 : 0.32)
            RoundedRectangle(cornerRadius: LivePanelChrome.cardRadius, style: .continuous)
                .strokeBorder(
                    Palette.text.opacity(hot ? 0.38 : 0.18),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )
                .padding(10)
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .light))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.muted)
                }
            }
            .foregroundStyle(Palette.text)
        }
        .opacity(visible ? 1 : 0)
        .animation(reduceMotion ? nil : Palette.overlay, value: visible)
        .animation(reduceMotion ? nil : Palette.overlay, value: hot)
        .allowsHitTesting(false)
        .accessibilityHidden(!visible)
        .accessibilityLabel(subtitle.isEmpty ? title : "\(title)。\(subtitle)")
    }
}
