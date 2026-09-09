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
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(composerFocused ? Palette.text : Palette.line)
                    .frame(height: 1)
            }
            Button { session.pasteFromClipboard() } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.faint)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("float-paste")
            .accessibilityLabel(Copy.t("从剪贴板加入", "Paste from clipboard"))
            .help(session.prefs.pasteHotKey.label)
            Button { session.sendToTUI() } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
