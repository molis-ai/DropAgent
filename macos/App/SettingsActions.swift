import DropAgentJob
import DropAgentShelf
import SwiftUI

struct SettingsActions: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsForm.sectionTitle(Copy.t("栏上的动作", "Actions on the bar"))
            Text(Copy.t("「其他」一直在加号前面，不能拿掉。", "Other always sits before Add and cannot be hidden."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
            ForEach(Array(session.actionSlots.enumerated()), id: \.element.id) { index, slot in
                slotRow(slot, index: index)
            }
            if hiddenSlots.isEmpty == false {
                SettingsForm.sectionTitle(Copy.t("已从栏上拿掉", "Hidden from the bar"))
                ForEach(hiddenSlots) { slot in
                    HStack {
                        Text(slotTitle(slot))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Button(Copy.t("放回", "Restore")) {
                            session.showSlot(slot)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .accessibilityIdentifier("action-restore-\(slot.id)")
                    }
                    .padding(.vertical, 4)
                }
            }
            SettingsForm.sectionTitle(Copy.t("快捷动作", "Shortcuts"))
            Button(Copy.t("添加快捷动作", "Add shortcut")) {
                session.settingsOpen = false
                session.openShortcutComposer()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .accessibilityIdentifier("settings-add-shortcut")
            ForEach(session.prefs.shortcuts) { action in
                VStack(alignment: .leading, spacing: 6) {
                    Text(action.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text(action.kinds.map { Copy.kindWord($0) }.joined(separator: " · "))
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                    HStack(spacing: 12) {
                        Button(Copy.t("编辑", "Edit")) {
                            session.settingsOpen = false
                            session.openShortcutComposer(edit: action.id)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        Button(Copy.t("删除", "Delete"), role: .destructive) {
                            session.deleteShortcut(id: action.id)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.danger)
                        Spacer()
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panel2.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line))
                .accessibilityIdentifier("settings-shortcut-\(action.id)")
            }
        }
        .accessibilityIdentifier("settings-actions")
    }

    private var hiddenSlots: [ActionSlot] {
        let visible = Set(session.actionSlots.map(\.id))
        var slots: [ActionSlot] = RecipeID.barRecipes
            .map { ActionSlot.recipe($0) }
            .filter { visible.contains($0.id) == false }
        for action in session.prefs.shortcuts where visible.contains(action.storedRecipe) == false {
            slots.append(.shortcut(action.id))
        }
        return slots
    }

    private func slotRow(_ slot: ActionSlot, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(slotTitle(slot))
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
            Spacer()
            Button {
                session.moveSlot(id: slot.id, by: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .accessibilityIdentifier("settings-up-\(slot.id)")
            Button {
                session.moveSlot(id: slot.id, by: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .disabled(index == session.actionSlots.count - 1)
            .accessibilityIdentifier("settings-down-\(slot.id)")
            Button(Copy.t("拿掉", "Hide")) {
                session.hideSlot(slot)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .accessibilityIdentifier("settings-hide-\(slot.id)")
        }
        .padding(.vertical, 4)
    }

    private func slotTitle(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            return Copy.recipeShort(recipe)
        case .shortcut(let id):
            return session.shortcut(id: id)?.name ?? Copy.t("快捷", "Shortcut")
        }
    }
}
