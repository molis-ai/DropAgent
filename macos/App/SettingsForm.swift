import SwiftUI

@MainActor
enum SettingsForm {
    static func shortcutRow(session: AppSession, slot: HotKeySlot, title: String, caption: String) -> some View {
        let recording = session.recordingHotKey == slot
        let chord = session.chord(for: slot)
        let taken = (slot == .toggle && session.hotKeyToggleOK == false)
            || (slot == .capture && session.hotKeyCaptureOK == false)
            || (slot == .files && session.hotKeyFilesOK == false)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .textSelection(.enabled)
                    Text(taken ? Copy.t("这个组合被占用。", "This shortcut is already in use.") : caption)
                        .font(.system(size: 11))
                        .foregroundStyle(taken ? Palette.muted : Palette.faint)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 8)
                Button(action: {
                    if recording {
                        session.cancelRecording()
                    } else {
                        session.beginRecording(slot)
                    }
                }) {
                    Text(recording ? Copy.t("按下…", "Press…") : chord.label)
                        .font(.system(size: 12, weight: .semibold).monospaced())
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(recording ? Palette.panelPress : Palette.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("shortcut-\(slot.rawValue)")
                if chord != slot.defaultChord {
                    Button(action: { session.resetHotKey(slot) }) {
                        Text(Copy.t("默认", "Default"))
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                            .padding(.horizontal, 8)
                            .frame(height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    static func guideLine(title: String, keys: String, caption: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 8)
            Text(keys)
                .font(.system(size: 12, weight: .semibold).monospaced())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    static func guideCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
            Text(body)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    static func toggleRow(
        title: String,
        caption: String,
        isOn: Bool,
        identifier: String,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .textSelection(.enabled)
                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.faint)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    onChange(newValue)
                }
            ))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Palette.text)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
    }

    static func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .textSelection(.enabled)
    }

    static func pathRow(
        title: String,
        caption: String,
        path: URL,
        isOverride: Bool,
        choose: @escaping () -> Void,
        reset: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
            Text(Copy.displayPath(path))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Palette.muted)
                .textSelection(.enabled)
                .lineLimit(2)
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
            HStack(spacing: 8) {
                Button(action: choose) {
                    Text(Copy.t("选择文件夹…", "Choose Folder…"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(QuietButtonStyle())
                if isOverride {
                    Button(action: reset) {
                        Text(Copy.t("恢复默认", "Reset"))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.line)
        )
    }

    static func segmented<Value: Equatable>(
        items: [(Value, String)],
        selected: Value,
        onPick: @escaping (Value) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let on = item.0 == selected
                Text(item.1)
                    .font(.system(size: 12, weight: on ? .semibold : .regular))
                    .foregroundStyle(Palette.text)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(on ? Palette.panel : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture { onPick(item.0) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityLabel(item.1)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .padding(2)
                if index < items.count - 1 {
                    Divider().overlay(Palette.line)
                        .frame(height: 16)
                }
            }
        }
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Palette.line)
        )
    }
}
