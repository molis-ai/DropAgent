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
                        .font(.system(size: 12))
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
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .buttonStyle(QuietButtonStyle(selected: recording))
                .accessibilityIdentifier("shortcut-\(slot.rawValue)")
                if chord != slot.defaultChord {
                    Button(action: { session.resetHotKey(slot) }) {
                        Text(Copy.t("默认", "Default"))
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func guideLine(title: String, keys: String, caption: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.text)
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.faint)
            }
            Spacer(minLength: 8)
            Text(keys)
                .font(.system(size: 12, weight: .semibold).monospaced())
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Palette.panel)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func guideCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.text)
                .textSelection(.enabled)
            Text(body)
                .font(.system(size: 12))
                .foregroundStyle(Palette.faint)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    .font(.system(size: 12))
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
                .tint(Palette.accent)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
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
                .font(.system(size: 12))
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
        .background(Palette.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    static func segmented<Value: Equatable>(
        items: [(Value, String)],
        selected: Value,
        onPick: @escaping (Value) -> Void
    ) -> some View {
        SettingsSegments(items: items, selected: selected, onPick: onPick)
    }
}

private struct SettingsSegments<Value: Equatable>: View {
    let items: [(Value, String)]
    let selected: Value
    let onPick: (Value) -> Void
    @Namespace private var selection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let on = item.0 == selected
                Button { onPick(item.0) } label: {
                    Text(item.1)
                        .font(.system(size: 12, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? Palette.text : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(RowButtonStyle())
                .background {
                    if on {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Palette.panel)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            .matchedGeometryEffect(id: "selected", in: selection)
                    }
                }
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityLabel(item.1)
            }
        }
        .padding(3)
        .background(Palette.panel2, in: RoundedRectangle(cornerRadius: 10))
        .animation(reduceMotion ? nil : Palette.selectionMotion, value: selected)
    }
}
