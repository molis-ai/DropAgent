import SwiftUI

struct SettingsRuntime: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsForm.sectionTitle(Copy.t("Runtime", "Runtime"))
            Text(Copy.t(
                "有画面的进内嵌终端。纯 CLI 会在默认 shell 里发出一条普通命令。",
                "TUI tools open in the panel terminal. Plain CLIs are sent as a normal shell command."
            ))
            .font(.system(size: 11))
            .foregroundStyle(Palette.faint)
            ForEach(session.settings.customRuntimes) { custom in
                VStack(alignment: .leading, spacing: 6) {
                    Text(custom.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(custom.executable)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .textSelection(.enabled)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Button(action: { session.setCustomRuntimeKind(custom.id, kind: .tui) }) {
                            Text("TUI")
                        }
                        .buttonStyle(QuietButtonStyle(selected: custom.kind == .tui, expand: true))
                        Button(action: { session.setCustomRuntimeKind(custom.id, kind: .cli) }) {
                            Text("CLI")
                        }
                        .buttonStyle(QuietButtonStyle(selected: custom.kind == .cli, expand: true))
                        Button(action: { session.removeCustomRuntime(custom.id) }) {
                            Text(Copy.t("删除", "Remove"))
                        }
                        .buttonStyle(QuietButtonStyle(danger: true, expand: true))
                    }
                    .frame(height: 30)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panel2.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
            }
            Button(action: { session.pickTUIExecutable() }) {
                Text(Copy.t("添加 Runtime…", "Add Runtime…"))
            }
            .buttonStyle(QuietButtonStyle(expand: true))
            .accessibilityIdentifier("settings-add-runtime")
        }
    }
}
