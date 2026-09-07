import SwiftUI

struct ComposerBar: View {
    @ObservedObject var session: AppSession
    @State private var composerFocused = false

    var body: some View {
        HStack(spacing: 6) {
            if session.selectedItems.isEmpty == false {
                Text(Copy.t("\(session.selectedItems.count) 项", "\(session.selectedItems.count) items"))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.muted)
                    .frame(minWidth: 32, alignment: .leading)
                    .accessibilityLabel(Copy.t("已选 \(session.selectedItems.count) 项", "\(session.selectedItems.count) selected"))
            }
            ComposerField(
                text: $session.promptText,
                focused: $composerFocused,
                placeholder: session.composerPlaceholder,
                enabled: session.canSendToTUI,
                onSubmit: { session.sendToTUI() }
            )
                .frame(height: 30)
                .padding(.horizontal, 8)
                .background(Palette.field)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(composerFocused ? Palette.text : Palette.line)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!session.canSendToTUI)
                .opacity(session.canSendToTUI ? 1 : 0.72)
                .layoutPriority(1)
            Button {
                session.pasteFromClipboard()
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
            }
                .buttonStyle(QuietButtonStyle())
                .frame(width: 36)
                .accessibilityLabel(Copy.t("从剪贴板加入架子", "Paste onto the shelf"))
            Button {
                session.sendToTUI()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
                .buttonStyle(PrimaryButtonStyle())
                .frame(width: 36)
                .disabled(!session.canSendToTUI)
                .accessibilityIdentifier("send")
                .accessibilityLabel(Copy.t("发送到 \(session.tuiTitle) 终端", "Send to the \(session.tuiTitle) terminal"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlay(alignment: .top) { Divider().background(Palette.line) }
        .onAppear {
            if session.otherOpen { composerFocused = true }
        }
        .onChange(of: session.otherOpen) { _, open in
            if open { composerFocused = true }
        }
    }
}
