import DropAgentAgent
import DropAgentJob
import DropAgentShelf
import Foundation

extension AppSession {
    func chooseRecipe(_ recipe: RecipeID) {
        onPanelInteraction?()
        otherOpen = false
        // A new confirmation replaces the previous draft, even after switching inputs.
        // Otherwise a later multi-selection can silently run two different drafts as one.
        for item in shelf.items() where item.status == .confirm {
            try? shelf.patch(id: item.id) { live in
                live.status = .idle
                live.recipe = nil
            }
        }
        paneFocus = .input
        let spec = RecipeCatalog.spec(recipe)
        var skipped = 0
        for item in selectedItems where item.status == .idle || item.status == .confirm || item.status == .failed || item.status == .sent {
            guard spec.acceptedKinds.contains(item.kind) else {
                skipped += 1
                continue
            }
            try? shelf.patch(id: item.id) { live in
                live.recipe = recipe.fullTitle
                live.status = .confirm
            }
        }
        if skipped > 0 {
            errorText = Copy.t(
                "有 \(skipped) 项不能用「\(recipe.shortTitle)」",
                "\(skipped) items cannot use “\(recipe.shortTitle)”"
            )
        }
        aiTab = .work
        refresh()
    }

    func cancelConfirm() {
        onPanelInteraction?()
        for item in selectedItems where item.status == .confirm {
            try? shelf.patch(id: item.id) { live in
                live.status = .idle
                live.recipe = nil
            }
        }
        refresh()
    }

    func confirmRun() async {
        guard hasRecipe else {
            errorText = hasAgent
                ? Copy.t(
                    "\(tuiTitle) 没有无界面执行入口。终端仍可发送给 \(tuiTitle)。",
                    "\(tuiTitle) has no headless entry. You can still send to \(tuiTitle) in the terminal."
                )
                : Copy.t("未发现终端 Agent。", "No terminal agent found.")
            return
        }
        let batch = selectedItems.filter { $0.status == .confirm }
        guard let first = batch.first, let recipe = RecipeID.fromStored(first.recipe) else {
            return
        }
        guard runningItems.isEmpty, batch.count >= recipe.minimumCount,
              batch.allSatisfy({ $0.recipe == first.recipe }) else {
            errorText = Copy.t("材料或任务状态已变化，请返回动作重新选择。", "The selection or job state changed. Go back and choose an action again.")
            return
        }
        let previousResults = Set(shelf.results().map(\.id))
        errorText = nil
        do {
            _ = try await job.start(itemIDs: batch.map(\.id), recipe: recipe, optionID: choiceID(for: recipe))
            presentJobResult(sourceIDs: Set(batch.map(\.id)))
        } catch AgentError.cancelled {
            if paneFocus == .input, Set(selectedItems.map(\.id)) == Set(batch.map(\.id)) { aiTab = .work }
        } catch {
            errorText = human(error)
            if shelf.results().contains(where: { !previousResults.contains($0.id) }) {
                presentJobResult(sourceIDs: Set(batch.map(\.id)))
            }
        }
    }

    func cancelRun() {
        job.cancel()
    }

    func startWheelRecipe(ids: [ItemID], recipe: RecipeID) async {
        guard hasRecipe else {
            errorText = hasAgent
                ? HotKeyCopy.missingJobLine(tuiTitle: tuiTitle)
                : Copy.t("未发现终端 Agent。文件已留在架子上。", "No terminal agent found. Files stayed on the shelf.")
            return
        }
        let spec = RecipeCatalog.spec(recipe)
        let fitted = ids.filter { id in
            guard let item = shelf.item(id: id) else { return false }
            return spec.acceptedKinds.contains(item.kind)
        }
        if fitted.isEmpty {
            errorText = Copy.t(
                "这份材料不能用「\(recipe.shortTitle)」",
                "This item cannot use “\(recipe.shortTitle)”"
            )
            return
        }
        let previousResults = Set(shelf.results().map(\.id))
        errorText = nil
        do {
            _ = try await job.start(itemIDs: fitted, recipe: recipe, optionID: choiceID(for: recipe))
            presentJobResult(sourceIDs: Set(fitted))
        } catch AgentError.cancelled {
            return
        } catch {
            errorText = human(error)
            if shelf.results().contains(where: { !previousResults.contains($0.id) }) {
                presentJobResult(sourceIDs: Set(fitted))
            }
        }
    }

    func presentJobResult(sourceIDs: Set<ItemID>) {
        // Completion must not replace another material, preview, or an open draft.
        let followsJob = paneFocus == .input && aiTab == .work && !otherOpen
            && Set(selectedItems.map(\.id)) == sourceIDs
        refresh()
        if followsJob {
            adoptNewestResult()
            aiTab = .work
        }
    }

    func adoptNewestResult() {
        refresh()
        guard let newest = results.first else { return }
        selectedResultID = newest.id
        paneFocus = .result
    }
}
