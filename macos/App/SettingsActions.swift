import DropAgentJob
import DropAgentShelf
import SwiftUI

struct SettingsActions: View {
    @ObservedObject var session: AppSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draggingID: String?
    @State private var dragLocation = CGPoint.zero
    @State private var grabOffset: CGFloat = 0
    @State private var dragOrder: [String] = []
    @State private var previewIDs: [String] = []
    @State private var rowFrames: [String: CGRect] = [:]
    @State private var startFrames: [String: CGRect] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsForm.sectionTitle(Copy.t("栏上的动作", "Actions on the bar"))
            Text(Copy.t("「其他」一直在加号前面，不能拿掉。", "Other always sits before Add and cannot be hidden."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(session.actionSlots) { slot in
                    slotRow(slot)
                        .opacity(draggingID == slot.id ? 0 : 1)
                        .offset(y: neighborOffset(slot.id))
                        .animation(
                            reduceMotion || draggingID == slot.id ? nil : Palette.selectionMotion,
                            value: previewIDs
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear.preference(
                                    key: ActionChipFrameKey.self,
                                    value: [slot.id: geo.frame(in: .named("settings-actions"))]
                                )
                            }
                        )
                }
            }
            .coordinateSpace(name: "settings-actions")
            .overlay(alignment: .topLeading) { floatingRow }
            .onPreferenceChange(ActionChipFrameKey.self) { frames in
                if draggingID == nil {
                    rowFrames = frames
                }
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
        .scrollDisabled(draggingID != nil)
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

    private func slotRow(_ slot: ActionSlot) -> some View {
        HStack(spacing: 8) {
            DragGrip()
                .frame(width: 8, height: 22)
                .accessibilityIdentifier("settings-handle-\(slot.id)")
                .highPriorityGesture(settingsDrag(for: slot.id))
            Text(slotTitle(slot))
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
            Spacer(minLength: 0)
            Button(Copy.t("拿掉", "Hide")) {
                session.hideSlot(slot)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .accessibilityIdentifier("settings-hide-\(slot.id)")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var floatingRow: some View {
        if let id = draggingID, let slot = session.actionSlots.first(where: { $0.id == id }) {
            slotRow(slot)
                .background(Palette.panel)
                .scaleEffect(reduceMotion ? 1 : 1.02)
                .shadow(
                    color: Color.black.opacity(reduceMotion ? 0 : 0.12),
                    radius: reduceMotion ? 0 : 8,
                    y: reduceMotion ? 0 : 3
                )
                .offset(y: floatingY)
                .allowsHitTesting(false)
        }
    }

    private func settingsDrag(for id: String) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("settings-actions"))
            .onChanged { value in
                if draggingID == nil {
                    let order = session.actionSlots.map(\.id)
                    dragOrder = order
                    previewIDs = order
                    startFrames = rowFrames
                    grabOffset = value.startLocation.y - (rowFrames[id]?.minY ?? 0)
                    draggingID = id
                    session.beginActionDrag(id: id)
                    NSCursor.closedHand.set()
                }
                dragLocation = value.location
                updateSettingsPreview()
            }
            .onEnded { _ in
                commitSettingsDrag()
            }
    }

    private func updateSettingsPreview() {
        guard let draggingID else { return }
        let sizes = startFrames.mapValues(\.height)
        let height = sizes[draggingID] ?? 0
        let origin = startFrames[dragOrder.first ?? ""]?.minY ?? 0
        let center = floatingY + height / 2 - origin
        let insert = ActionBarReorder.insertIndex(
            dragging: draggingID,
            center: center,
            order: dragOrder,
            sizes: sizes
        )
        let preview = ActionBarReorder.previewOrder(dragging: draggingID, insert: insert, order: dragOrder)
        if preview != previewIDs {
            previewIDs = preview
        }
    }

    private func commitSettingsDrag() {
        if previewIDs.isEmpty == false {
            session.applyActionOrder(previewIDs)
        }
        session.endActionDrag()
        draggingID = nil
        dragLocation = .zero
        grabOffset = 0
        dragOrder = []
        previewIDs = []
        startFrames = [:]
        NSCursor.arrow.set()
    }

    private var floatingY: CGFloat {
        dragLocation.y - grabOffset
    }

    private func neighborOffset(_ id: String) -> CGFloat {
        ActionBarReorder.offset(
            id: id,
            dragging: draggingID,
            start: dragOrder,
            preview: previewIDs,
            sizes: startFrames.mapValues(\.height)
        )
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
