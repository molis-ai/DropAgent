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
        VStack(alignment: .leading, spacing: 12) {
            Text(Copy.t("将常用动作加入动作栏，拖动手柄调整顺序。", "Add frequent actions to the bar. Drag handles to reorder."))
                .font(.system(size: 11))
                .foregroundStyle(Palette.faint)
            HStack(alignment: .top, spacing: 16) {
                poolColumn
                Rectangle()
                    .fill(Palette.line)
                    .frame(width: 1)
                    .padding(.vertical, 4)
                barColumn
            }
        }
        .accessibilityIdentifier("settings-actions")
        .scrollDisabled(draggingID != nil)
    }

    private var poolColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsForm.sectionTitle(Copy.t("更多动作", "More actions"))
            if session.shortcutDraft != nil {
                ShortcutComposer(session: session, inset: false)
                if let error = session.errorText {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.warning)
                }
            } else {
                Button(Copy.t("新建自定义动作", "New custom action")) {
                    session.openShortcutComposer()
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("settings-add-shortcut")
            }
            if session.poolSlots.isEmpty && session.shortcutDraft == nil {
                Text(Copy.t("所有动作均已加入动作栏。也可新建自定义动作。", "All actions are on the bar. You can also create a custom action."))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            ForEach(session.poolSlots) { slot in
                poolRow(slot)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccessibleID(identifier: "settings-action-pool").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("settings-action-pool")
    }

    private var barColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsForm.sectionTitle(Copy.t("动作栏", "Action bar"))
            if session.actionSlots.isEmpty {
                Text(Copy.t("从左侧选择动作，加入动作栏。", "Choose an action on the left to add it here."))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(session.actionSlots) { slot in
                    barRow(slot)
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AccessibleID(identifier: "settings-action-bar").frame(width: 0, height: 0).allowsHitTesting(false))
        .accessibilityIdentifier("settings-action-bar")
    }

    private func poolRow(_ slot: ActionSlot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(slotTitle(slot))
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
            if case .shortcut(let id) = slot, let action = session.shortcut(id: id) {
                Text(action.kinds.map { Copy.kindWord($0) }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                Button(Copy.t("加入动作栏", "Add to bar")) {
                    session.showSlot(slot)
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("action-restore-\(slot.id)")
                if case .shortcut(let id) = slot {
                    Button(Copy.t("编辑", "Edit")) {
                        session.openShortcutComposer(edit: id)
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button(Copy.t("删除", "Delete"), role: .destructive) {
                        session.deleteShortcut(id: id)
                    }
                    .buttonStyle(QuietButtonStyle(danger: true))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel2.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Palette.line))
        .accessibilityIdentifier(poolRowID(slot))
    }

    private func barRow(_ slot: ActionSlot) -> some View {
        HStack(spacing: 8) {
            DragGrip()
                .frame(width: 8, height: 22)
                .accessibilityIdentifier("settings-handle-\(slot.id)")
                .highPriorityGesture(settingsDrag(for: slot.id))
            Text(slotTitle(slot))
                .font(.system(size: 13))
                .foregroundStyle(Palette.text)
            Spacer(minLength: 0)
            if case .shortcut(let id) = slot {
                Button(Copy.t("编辑", "Edit")) {
                    session.openShortcutComposer(edit: id)
                }
                .buttonStyle(QuietButtonStyle())
            }
            Button(Copy.t("放回池子", "Return to pool")) {
                session.hideSlot(slot)
            }
            .buttonStyle(QuietButtonStyle())
            .accessibilityIdentifier("settings-hide-\(slot.id)")
        }
        .padding(.vertical, 4)
    }

    private func poolRowID(_ slot: ActionSlot) -> String {
        if case .shortcut(let id) = slot {
            return "settings-shortcut-\(id)"
        }
        return "settings-pool-\(slot.id)"
    }

    private func slotRow(_ slot: ActionSlot) -> some View {
        barRow(slot)
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
            return Copy.recipeSettings(recipe)
        case .shortcut(let id):
            return session.shortcut(id: id)?.name ?? Copy.t("快捷", "Shortcut")
        }
    }
}
