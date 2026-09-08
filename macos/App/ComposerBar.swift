import SwiftUI

struct ComposerBar: View {
    @ObservedObject var session: AppSession
    @State private var composerFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(Copy.t("发给 \(session.tuiTitle)", "Send to \(session.tuiTitle)"), systemImage: "terminal")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
                Text(Copy.t("\(session.selectedItems.count) 份材料", "\(session.selectedItems.count) materials"))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                ComposerField(
                    text: $session.promptText,
                    focused: $composerFocused,
                    placeholder: session.composerPlaceholder,
                    enabled: session.canSendToTUI,
                    onSubmit: { session.sendToTUI() }
                )
                .frame(height: 38)
                .padding(.leading, 12)
                .layoutPriority(1)
                Button { session.sendToTUI() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 34, height: 34)
                .disabled(!session.canSendToTUI)
                .accessibilityIdentifier("send")
                .accessibilityLabel(Copy.t("发送到 \(session.tuiTitle) 终端", "Send to the \(session.tuiTitle) terminal"))
                .padding(.trailing, 4)
            }
            .background(Palette.field)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(composerFocused ? Palette.accent.opacity(0.65) : Palette.line))
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .overlay(alignment: .top) { Divider().overlay(Palette.line) }
        .onAppear { if session.otherOpen { composerFocused = true } }
        .onChange(of: session.otherOpen) { _, open in if open { composerFocused = true } }
    }
}
