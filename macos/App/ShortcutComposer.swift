import DropAgentShelf
import SwiftUI

struct ShortcutComposer: View {
    @ObservedObject var session: AppSession

    var body: some View {
        if session.shortcutDraft != nil {
            form
        }
    }

    private var draftBind: Binding<ShortcutDraft> {
        Binding(
            get: { session.shortcutDraft ?? .blank() },
            set: { session.shortcutDraft = $0 }
        )
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(draftBind.wrappedValue.id == nil
                 ? Copy.t("新快捷动作", "New shortcut")
                 : Copy.t("编辑快捷动作", "Edit shortcut"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.text)
            TextField(Copy.t("名字，比如抽付款日", "Name, e.g. Payment dates"), text: draftBind.name)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .padding(.horizontal, 8)
                .frame(height: 28)
                .background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier("shortcut-name")
            HStack(spacing: 6) {
                ForEach(ItemKind.allCases, id: \.self) { kind in
                    let on = draftBind.wrappedValue.kinds.contains(kind)
                    Button {
                        if on { draftBind.wrappedValue.kinds.remove(kind) }
                        else { draftBind.wrappedValue.kinds.insert(kind) }
                    } label: {
                        Text(Copy.kindWord(kind))
                            .font(.system(size: 11, weight: on ? .semibold : .regular))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .background(on ? Palette.panelPress : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shortcut-kind-\(kind.rawValue)")
                }
            }
            TextEditor(text: draftBind.prompt)
                .font(.system(size: 12))
                .foregroundStyle(Palette.text)
                .frame(minHeight: 64, maxHeight: 88)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityIdentifier("shortcut-prompt")
            HStack(spacing: 12) {
                Button(action: session.saveShortcutDraft) {
                    Text(Copy.t("保存", "Save"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shortcut-save")
                Button(action: session.closeShortcutComposer) {
                    Text(Copy.t("取消", "Cancel"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shortcut-cancel")
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
