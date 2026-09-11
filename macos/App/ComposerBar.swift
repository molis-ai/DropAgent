import SwiftUI

struct ComposerBar: View {
    @ObservedObject var session: AppSession
    @State private var composerFocused = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Text(session.selectedItems.isEmpty ? "" : "\(session.selectedItems.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .frame(minWidth: 16, alignment: .leading)
                .padding(.bottom, 10)
                .accessibilityHidden(session.selectedItems.isEmpty)
            ComposerField(
                text: $session.promptText,
                focused: $composerFocused,
                placeholder: session.composerPlaceholder,
                enabled: session.canSendToTUI,
                onSubmit: { session.sendToTUI() }
            )
            .frame(height: 36)
            .padding(.horizontal, 10)
            .background(Palette.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(composerFocused ? Palette.accent : Palette.line)
            }
            Button { session.sendToTUI() } label: {
                Label(Copy.t("发送", "Send"), systemImage: "arrow.up")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!session.canSendToTUI)
            .accessibilityIdentifier("send")
            .accessibilityLabel(Copy.t("发送到 \(session.tuiTitle) 终端", "Send to the \(session.tuiTitle) terminal"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .onAppear { if session.otherOpen { composerFocused = true } }
        .onChange(of: session.otherOpen) { _, open in if open { composerFocused = true } }
    }
}
