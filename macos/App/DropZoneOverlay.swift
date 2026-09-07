import SwiftUI

struct DropZoneOverlay: View {
    let title: String
    let offered: Bool
    let hot: Bool
    var reduceMotion: Bool

    var body: some View {
        let visible = hot || offered
        return VStack(spacing: 8) {
            Image(systemName: title.hasPrefix("发给") || title.hasPrefix("Send") ? "paperplane" : "tray.and.arrow.down")
                .font(.system(size: 18, weight: .light))
            Text(title)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Palette.text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Palette.panel
                Color.black.opacity(hot ? 0.08 : 0.04)
            }
        }
        .overlay(Rectangle().stroke(Palette.text.opacity(hot ? 0.35 : 0.16), lineWidth: 1))
        .opacity(visible ? 1 : 0)
        .animation(reduceMotion ? nil : Palette.overlay, value: visible)
        .animation(reduceMotion ? nil : Palette.overlay, value: hot)
        .allowsHitTesting(false)
        .accessibilityHidden(!visible)
        .accessibilityLabel(title)
    }
}
