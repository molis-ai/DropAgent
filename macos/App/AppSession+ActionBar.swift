import AppKit
import DropAgentJob
import DropAgentShelf
import Foundation

extension AppSession {
    var actionSlots: [ActionSlot] {
        ActionBarLayout.slots(order: prefs.actionOrder, shortcuts: prefs.shortcuts)
    }

    var poolSlots: [ActionSlot] {
        ActionBarLayout.poolSlots(order: prefs.actionOrder, shortcuts: prefs.shortcuts)
    }

    func barSlots(organizing: Bool) -> [ActionSlot] {
        actionSlots.filter { slot in
            if organizing { return true }
            return slotFitsSelection(slot)
        }
    }

    func slotFitsSelection(_ slot: ActionSlot) -> Bool {
        switch slot {
        case .recipe(let recipe):
            if RecipeCatalog.spec(recipe).requiresAgent == false {
                return recipeFitsSelection(recipe)
            }
            return true
        case .shortcut(let id):
            guard let action = shortcut(id: id) else { return false }
            let batch = recipeBatch
            guard batch.isEmpty == false else { return false }
            return batch.allSatisfy { action.kindSet.contains($0.kind) }
        }
    }

    func shortcut(id: String) -> ShortcutAction? {
        prefs.shortcuts.first { $0.id == id }
    }

    func shortcut(stored: String?) -> ShortcutAction? {
        guard let id = RecipeID.shortcutStoredID(stored) else { return nil }
        return shortcut(id: id)
    }

    func displayedActionName(_ stored: String?) -> String {
        if let action = shortcut(stored: stored) { return action.name }
        return Copy.recipeStored(stored)
    }

    func canRunSlot(_ slot: ActionSlot) -> Bool {
        switch slot {
        case .recipe(let recipe):
            return canRunRecipe(recipe)
        case .shortcut(let id):
            guard slotFitsSelection(.shortcut(id)) else { return false }
            return hasRecipe
        }
    }

    func slotHelp(_ slot: ActionSlot) -> String {
        switch slot {
        case .recipe(let recipe):
            return recipeFitsSelection(recipe) ? Copy.recipeBlurb(recipe) : recipeHelp(recipe)
        case .shortcut(let id):
            guard let action = shortcut(id: id) else { return "" }
            if hasRecipe == false {
                return hasAgent ? HotKeyCopy.missingJobLine(tuiTitle: tuiTitle) : "未发现终端 Agent"
            }
            if slotFitsSelection(.shortcut(id)) {
                return Copy.t("在副本里跑，写出新的 Markdown", "Run on a copy and write a new Markdown file")
            }
            return Copy.t("选中的材料不能用「\(action.name)」", "The selected items cannot use “\(action.name)”")
        }
    }

    func chooseSlot(_ slot: ActionSlot) {
        switch slot {
        case .recipe(let recipe):
            chooseRecipe(recipe)
        case .shortcut(let id):
            chooseShortcut(id: id)
        }
    }

    func chooseShortcut(id: String) {
        guard let action = shortcut(id: id) else { return }
        stopStageEdit()
        onPanelInteraction?()
        otherOpen = false
        actionBarEditing = false
        shortcutDraft = nil
        for item in shelf.items() where item.status == .confirm {
            try? shelf.patch(id: item.id) { live in
                live.status = .idle
                live.recipe = nil
            }
        }
        paneFocus = .input
        dismissFirstActionHint()
        var skipped = 0
        for item in selectedItems where item.status == .idle || item.status == .confirm || item.status == .failed || item.status == .sent {
            guard action.kindSet.contains(item.kind) else {
                skipped += 1
                continue
            }
            try? shelf.patch(id: item.id) { live in
                live.recipe = action.storedRecipe
                live.status = .confirm
            }
        }
        if skipped > 0 {
            errorText = Copy.t(
                "有 \(skipped) 项不能用「\(action.name)」",
                "\(skipped) items cannot use “\(action.name)”"
            )
        }
        aiTab = .work
        refresh()
    }

    var canConfirmShortcut: Bool {
        guard let action = shortcut(stored: confirmStoredRecipe) else { return false }
        let batch = selectedItems.filter { $0.status == .confirm }
        guard batch.isEmpty == false, hasRecipe else { return false }
        return batch.allSatisfy { action.kindSet.contains($0.kind) }
    }

    var confirmStoredRecipe: String? {
        selectedItems.first(where: { $0.status == .confirm })?.recipe
            ?? selectedItems.first?.recipe
    }

    func setActionBarEditing(_ on: Bool) {
        onPanelInteraction?()
        actionBarEditing = on
        if on { shortcutDraft = nil }
    }

    func openShortcutComposer(edit id: String? = nil) {
        onPanelInteraction?()
        actionBarEditing = false
        errorText = nil
        shortcutPoolNotice = nil
        if let id, let action = shortcut(id: id) {
            shortcutDraft = .edit(action)
        } else {
            shortcutDraft = .blank(matching: recipeBatch.map(\.kind))
        }
    }

    func closeShortcutComposer() {
        shortcutDraft = nil
    }

    func saveShortcutDraft() {
        guard var draft = shortcutDraft else { return }
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = draft.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false, prompt.isEmpty == false, draft.kinds.isEmpty == false else {
            errorText = Copy.t("请填写动作名称、适用类型和指令。", "Enter an action name, supported types, and instruction.")
            return
        }
        draft.name = name
        draft.prompt = prompt
        errorText = nil
        if let id = draft.id, let index = prefs.shortcuts.firstIndex(where: { $0.id == id }) {
            prefs.shortcuts[index].name = name
            prefs.shortcuts[index].kinds = ItemKind.allCases.filter { draft.kinds.contains($0) }
            prefs.shortcuts[index].prompt = prompt
            shortcutPoolNotice = nil
        } else {
            let action = ShortcutAction(
                name: name,
                kinds: ItemKind.allCases.filter { draft.kinds.contains($0) },
                prompt: prompt
            )
            prefs.shortcuts.append(action)
            if settingsOpen == false {
                shortcutPoolNotice = ShortcutPoolNotice(id: action.id, name: action.name)
            } else {
                shortcutPoolNotice = nil
            }
        }
        prefs.save()
        shortcutDraft = nil
        objectWillChange.send()
    }

    func pinPooledShortcutToBar() {
        guard let notice = shortcutPoolNotice else { return }
        showSlot(.shortcut(notice.id))
        shortcutPoolNotice = nil
    }

    func dismissShortcutPoolNotice() {
        shortcutPoolNotice = nil
    }

    func openActionPoolInSettings() {
        shortcutPoolNotice = nil
        settingsSection = .actions
        settingsOpen = true
    }

    func hideSlot(_ slot: ActionSlot) {
        prefs.actionOrder.removeAll { $0 == slot.id }
        prefs.save()
        objectWillChange.send()
    }

    func showSlot(_ slot: ActionSlot) {
        if prefs.actionOrder.contains(slot.id) == false {
            prefs.actionOrder.append(slot.id)
        }
        prefs.save()
        objectWillChange.send()
    }

    func beginActionDrag(id: String) {
        draggingActionID = id
    }

    func endActionDrag() {
        guard draggingActionID != nil else { return }
        draggingActionID = nil
    }

    func applyActionOrder(_ ids: [String]) {
        let visible = Set(prefs.actionOrder)
        let next = ids.filter { visible.contains($0) }
        guard next.isEmpty == false else { return }
        var seen = Set(next)
        var order = next
        for id in prefs.actionOrder where seen.contains(id) == false {
            order.append(id)
            seen.insert(id)
        }
        guard order != prefs.actionOrder else { return }
        prefs.actionOrder = order
        prefs.save()
        objectWillChange.send()
    }

    func moveSlot(id: String, by offset: Int) {
        guard let index = prefs.actionOrder.firstIndex(of: id) else { return }
        let next = index + offset
        guard prefs.actionOrder.indices.contains(next) else { return }
        prefs.actionOrder.swapAt(index, next)
        prefs.save()
        objectWillChange.send()
    }

    func moveSlot(id: String, to targetID: String) {
        guard id != targetID else { return }
        var order = prefs.actionOrder
        guard let from = order.firstIndex(of: id),
              let to = order.firstIndex(of: targetID)
        else { return }
        if from < to {
            if from + 1 == to { return }
            order.move(fromOffsets: IndexSet(integer: from), toOffset: to + 1)
        } else {
            if from == to + 1 { return }
            order.move(fromOffsets: IndexSet(integer: from), toOffset: to)
        }
        guard order != prefs.actionOrder else { return }
        prefs.actionOrder = order
        if draggingActionID == nil {
            prefs.save()
        }
        objectWillChange.send()
    }

    func deleteShortcut(id: String) {
        prefs.shortcuts.removeAll { $0.id == id }
        prefs.actionOrder.removeAll { $0 == RecipeID.storedShortcut(id: id) }
        if RecipeID.shortcutStoredID(confirmStoredRecipe) == id {
            cancelConfirm()
        }
        if shortcutPoolNotice?.id == id {
            shortcutPoolNotice = nil
        }
        prefs.save()
        objectWillChange.send()
    }

    func customJobSpec(for action: ShortcutAction, items: [Item]) -> CustomJobSpec {
        let original = items.first?.title ?? "file"
        return CustomJobSpec(
            title: action.name,
            prompt: action.prompt,
            outputFileName: JobOutputName.markdown(originalTitle: original, action: action.name),
            acceptedKinds: action.kindSet
        )
    }
}
