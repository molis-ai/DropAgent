import DropAgentJob
import DropAgentShelf
import Foundation

extension AppSession {
    var selectedItems: [Item] { shelf.selectedItems() }
    var hasAgent: Bool { presence.executable != nil }
    var canSendToTUI: Bool {
        guard hasAgent, isCapturing == false else { return false }
        if selectedItems.contains(where: { $0.status == .running || $0.status == .confirm }) {
            return false
        }
        if paneFocus == .result {
            return selectedResult?.output != nil
        }
        return true
    }
    var composerPlaceholder: String {
        if hasAgent == false { return Copy.t("未发现终端 Agent", "No terminal agent found") }
        if isCapturing { return Copy.t("正在抓当前页", "Capturing the current page") }
        if selectedItems.contains(where: { $0.status == .running }) {
            return Copy.t("等任务结束，或点取消", "Wait for the job to finish, or cancel")
        }
        if selectedItems.contains(where: { $0.status == .confirm }) {
            return Copy.t("先运行或取消这次动作", "Run or cancel this action first")
        }
        return Copy.t("写给 \(tuiTitle)，回车发送", "Write to \(tuiTitle), press Return to send")
    }
    var hasRecipe: Bool {
        let key = presence.runtimeKey
        return key.isEmpty == false && key == recipePresence.runtimeKey
    }
    var tuiTitle: String { presence.shortTitle }
    var showsSetupCard: Bool {
        SetupCardPolicy.shouldShowCard(
            dismissed: prefs.setupCardDismissed,
            captureReady: SetupCardPolicy.captureReady(setup),
            isDiagnostic: suppressSetupCard,
            panelVisible: true
        )
    }
    var gearNeedsAttention: Bool {
        SetupCardPolicy.gearNeedsAttention(hasAgent: hasAgent, setup: setup)
    }
    var recipeActorLine: String {
        HotKeyCopy.recipeActorLine(hasRecipe: hasRecipe, hasAgent: hasAgent, tuiTitle: tuiTitle)
    }
    var recipeIsolationFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        return agent.isolationCopy(for: recipePresence)
    }
    var recipeWriteFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        if recipePresence.isolation == .workspace { return Copy.t("仅任务目录", "Job folder only") }
        return Copy.t("未确认仅任务目录", "Job-folder limit unconfirmed")
    }
    var recipeNetworkFact: String {
        guard hasRecipe else { return Copy.t("无执行入口", "No exec entry") }
        if recipePresence.isolation != .workspace { return Copy.t("未确认", "Unconfirmed") }
        let wants = confirmRecipeID.map { RecipeCatalog.spec($0).needsNetwork } ?? false
        return wants ? Copy.t("开", "On") : Copy.t("关", "Off")
    }
    var confirmRecipeID: RecipeID? {
        let title = selectedItems.first(where: { $0.status == .confirm })?.recipe
            ?? selectedItems.first?.recipe
        return RecipeID.allCases.first { $0.fullTitle == title }
    }
    var shortcutFooter: String {
        let keys = HotKeyCopy.hotkeyLine(hasAgent: hasAgent, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK, filesOK: hotKeyFilesOK)
        if isCapturing {
            return "正在抓当前页，完成前先不发送。\n" + keys
        }
        if selectedItems.contains(where: { $0.status == .confirm || $0.status == .running }) {
            return keys
        }
        return HotKeyCopy.footer(hasAgent: hasAgent, tuiTitle: tuiTitle, toggleOK: hotKeyToggleOK, captureOK: hotKeyCaptureOK, filesOK: hotKeyFilesOK)
    }

    var recipeBatch: [Item] {
        selectedItems.filter { $0.status == .idle || $0.status == .confirm || $0.status == .failed || $0.status == .sent }
    }

    func recipeFitsSelection(_ recipe: RecipeID) -> Bool {
        let spec = RecipeCatalog.spec(recipe)
        let batch = recipeBatch
        guard batch.count >= recipe.minimumCount else { return false }
        return batch.allSatisfy { spec.acceptedKinds.contains($0.kind) }
    }

    func recipeHelp(_ recipe: RecipeID) -> String {
        if hasRecipe == false {
            return hasAgent ? HotKeyCopy.missingJobLine(tuiTitle: tuiTitle) : "未发现终端 Agent"
        }
        if recipeFitsSelection(recipe) { return Copy.recipeFull(recipe) }
        if recipeBatch.count < recipe.minimumCount {
            return Copy.t(
                "「\(Copy.recipeShort(recipe))」至少要两份材料",
                "“\(Copy.recipeShort(recipe))” needs at least two items"
            )
        }
        return Copy.t(
            "选中的材料不能用「\(Copy.recipeShort(recipe))」",
            "The selected items cannot use “\(Copy.recipeShort(recipe))”"
        )
    }

    var recipeChooserHint: String {
        if hasAgent == false {
            return "安装终端 Agent 后可发送。现在只能暂存，或点右上角选择已装的 TUI。"
        }
        if hasRecipe == false {
            return "\(tuiTitle) 没有无界面执行入口，动作不能跑。下面可以发给 \(tuiTitle)。"
        }
        if RecipeID.allCases.contains(where: recipeFitsSelection) {
            return "或在下面写一句话，发送到 \(tuiTitle) 终端。"
        }
        if recipeBatch.contains(where: { $0.kind == .file }) && recipeBatch.count < RecipeID.brief.minimumCount {
            return "这类文件不能总结或翻译。发给 \(tuiTitle)，或再选一份做「新交付」。"
        }
        return "选中的材料不能跑这些动作。发给 \(tuiTitle)。"
    }

    var selectedFailureReason: String? {
        selectedItems.first(where: { $0.status == .failed })?.failureReason
    }

    var failedRetryLine: String? {
        guard selectedFailureReason != nil, hasRecipe else { return nil }
        return "再点一个动作可以重试。"
    }

    var isDoneTakeaway: Bool {
        let batch = selectedItems
        return batch.isEmpty == false && batch.allSatisfy { $0.status == .done }
    }

    var isFailedOutputTakeaway: Bool {
        let batch = selectedItems
        return batch.isEmpty == false && batch.allSatisfy { $0.status == .failed && $0.output != nil }
    }

    var isResultTakeaway: Bool {
        isDoneTakeaway || isFailedOutputTakeaway
    }

    var failedOutputRetryRecipe: RecipeID? {
        guard isFailedOutputTakeaway, hasRecipe else { return nil }
        guard let title = selectedItems.first?.recipe else { return nil }
        return RecipeID.allCases.first { $0.fullTitle == title }
    }

    var doneActionHint: String {
        if hasAgent {
            return "点右边结果拿走，或发给 \(tuiTitle)。"
        }
        return "点右边结果拿走。没有终端也能拖出或复制。"
    }

    var canOpenTerminalTab: Bool {
        tuiSessionDirectory != nil || ttyLines.isEmpty == false
    }

    var resultIsolationLine: String? {
        currentResult()?.isolationShown.spokenFact
    }

    var selectedResult: ResultRecord? {
        guard let id = selectedResultID else { return nil }
        return results.first { $0.id == id } ?? shelf.result(id: id)
    }
}
