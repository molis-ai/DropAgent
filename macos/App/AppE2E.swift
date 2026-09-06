import AppKit
import CryptoKit
import DropAgentAgent
import DropAgentCapture
import DropAgentIngest
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AppE2E {
    @MainActor
    static func run() {
        if ProcessInfo.processInfo.environment["DROPAGENT_ROOT"] == nil {
            setenv("DROPAGENT_ROOT", "/tmp/dropagent-e2e-live", 1)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate()
        app.delegate = delegate
        app.run()
    }

    @MainActor
    final class Delegate: NSObject, NSApplicationDelegate {
        var session: AppSession!
        private var window: NSWindow?
        private var hosting: PaperHostView<PanelRootView>?
        private let uiOut = DropAgentPaths.root.appendingPathComponent("ui", isDirectory: true)
        private var deferredCaptureFailure: String?

        func applicationDidFinishLaunching(_ notification: Notification) {
            Self.forceRemove(DropAgentPaths.root)
            try? DropAgentPaths.ensure()
            try? FileManager.default.createDirectory(at: uiOut, withIntermediateDirectories: true)
            session = AppSession(jobRunner: RecipeStubAgent())

            let window = NSWindow(
                contentRect: NSRect(x: 40, y: 40, width: 400, height: 620),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "DropAgent E2E"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            let host = PaperHostView(rootView: PanelRootView(session: session, onClose: {}))
            host.frame = NSRect(x: 0, y: 0, width: 400, height: 620)
            window.contentView = host
            Palette.applyPaperChrome(to: window, host: host)
            window.makeKeyAndOrderFront(nil)
            self.window = window
            self.hosting = host

            DispatchQueue.main.asyncAfter(deadline: .now() + 240) {
                fputs("e2e: timeout\n", stderr)
                NSApp.terminate(nil)
            }
            Task { @MainActor [weak self] in
                await self?.go()
                NSApp.terminate(nil)
            }
        }

        @MainActor
        private func go() async {
            session.setTUIPreference(.grok)
            await settle()
            session.systemDragActive = true
            await settle()
            snapshot("e2e-drag-empty")
            session.systemDragActive = false
            verifyEdgePlacement()
            verifyLivePanelChrome()
            verifyListHeightFit()
            verifyStatusIcon()
            verifyStatusHover()
            verifyResultMarkdown()
            verifyIsolationFact()
            verifyIsolationShownRecord()
            verifyConfirmFacts()
            verifyRecipeChooserHint()
            verifyImageRecipeGates()
            verifyFailedActionRetry()
            verifyFailedOutputTakeaway()
            verifyDoneTakeaway()
            verifySourceLink()
            verifyResultJSON()
            verifyStagedPreview()
            await verifyResultTakeawayPinned()
            await verifyPresenceGates()
            await verifyRecipeLoop()
            await verifyExtractLoop()
            await verifyBriefLoop()
            await verifyFolderLoop()
            await verifyZipLoop()
            await verifyClipboardLoop()
            await verifyCaptureLoop()
            if let deferredCaptureFailure {
                fputs("e2e: capture deferred \(deferredCaptureFailure)\n", stdout)
                fflush(stdout)
            }
            guard session.presence.engine == .grok else {
                fail("no Grok")
            }
            let pdf = sourcePDF()
            let before = hash(pdf)
            let board = NSPasteboard.withUniqueName()
            board.clearContents()
            guard board.writeObjects([pdf as NSURL]) else {
                fail("pasteboard write")
            }
            session.admitPasteboard(board)
            await settle()
            snapshot("e2e-idle")
            guard session.items.first?.status == .idle else {
                fail("admit did not stay idle")
            }
            guard session.canOpenTerminalTab == false else {
                fail("tty open before send")
            }
            session.promptText = "读一下这份材料"
            guard let id = session.items.first?.id else {
                fail("no item to send")
            }
            session.sendToTUI(itemIDs: [id])
            await settle()
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            snapshot("e2e-tty")

            let after = hash(pdf)
            guard after == before else {
                fail("original hash changed \(before) -> \(after)")
            }
            guard let item = session.items.first, item.status == .sent else {
                fail(session.errorText ?? "item not sent")
            }
            guard session.tuiProcessRunning else {
                fail("tui process not running")
            }
            guard session.tuiTitle == "Grok" else {
                fail("tui is \(session.tuiTitle), not Grok")
            }
            guard let cwd = session.tuiSessionDirectory else {
                fail("tui session missing")
            }
            guard session.canOpenTerminalTab else {
                fail("tty closed after send")
            }
            session.aiTab = .result
            await settle()
            guard session.currentResult()?.status == .sent else {
                fail("sent result missing")
            }
            snapshot("e2e-sent-result")
            session.aiTab = .tty
            await settle()
            let copy = cwd.appendingPathComponent(pdf.lastPathComponent)
            guard FileManager.default.fileExists(atPath: copy.path) else {
                fail("tui did not copy file")
            }
            do {
                let landed = try await land(item)
                guard landed.lastPathComponent == pdf.lastPathComponent else {
                    fail("landed \(landed.lastPathComponent)")
                }
                fputs("e2e: ok hash=\(before) landed=\(landed.path) tui=\(cwd.path) engine=Grok\n", stdout)
                fflush(stdout)
                if let deferredCaptureFailure {
                    fail(deferredCaptureFailure)
                }
            } catch {
                fail("drag land \(error)")
            }
        }

        private func verifyIsolationFact() {
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .unknown)
            let unknown = session.recipeIsolationFact
            guard unknown.contains("未确认工作区限制") else {
                fail("unknown isolation fact \(unknown)")
            }
            guard unknown.contains("Safe Copy") == false else {
                fail("unknown isolation claimed Safe Copy")
            }
            session.recipePresence = .codex(path: path, isolation: .workspace)
            let workspace = session.recipeIsolationFact
            guard workspace.contains("Workspace Sandbox") else {
                fail("workspace isolation fact \(workspace)")
            }
            guard workspace.contains("完全看不到") == false else {
                fail("workspace overclaim")
            }
            session.recipePresence = .none
            guard session.recipeIsolationFact == "无 Codex" else {
                fail("no recipe isolation fact \(session.recipeIsolationFact)")
            }
            session.refreshPresence()
        }

        private func verifyIsolationShownRecord() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("shown.md")
            try? Data("# shown\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let id = session.items.first(where: { $0.title == "shown.md" })?.id else {
                fail("no shown.md")
            }
            try? session.shelf.patch(id: id) { live in
                live.status = .done
                live.output = note
                live.isolationShown = .unconfirmed
            }
            session.refresh()
            session.aiTab = .result
            guard session.resultIsolationLine == IsolationShown.unconfirmed.spokenFact else {
                fail("unconfirmed result \(session.resultIsolationLine ?? "nil")")
            }
            guard session.resultIsolationLine?.contains("Safe Copy") == false else {
                fail("unconfirmed claimed Safe Copy")
            }
            try? session.shelf.patch(id: id) { live in
                live.isolationShown = .workspace
            }
            session.refresh()
            guard session.resultIsolationLine == IsolationShown.workspace.spokenFact else {
                fail("workspace result \(session.resultIsolationLine ?? "nil")")
            }
            session.remove(id: id)
            session.aiTab = .work
        }

        private func verifyConfirmFacts() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("facts.md")
            try? Data("# facts\n".utf8).write(to: note)
            session.admit(urls: [note])
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .unknown)
            session.chooseRecipe(.summarize)
            guard session.recipeWriteFact == "未确认仅任务目录" else {
                fail("unknown write fact \(session.recipeWriteFact)")
            }
            guard session.recipeNetworkFact == "未确认" else {
                fail("unknown network fact \(session.recipeNetworkFact)")
            }
            session.cancelConfirm()
            session.recipePresence = .codex(path: path, isolation: .workspace)
            session.chooseRecipe(.summarize)
            guard session.recipeWriteFact == "仅任务目录" else {
                fail("workspace write fact \(session.recipeWriteFact)")
            }
            guard session.recipeNetworkFact == "关" else {
                fail("summarize network \(session.recipeNetworkFact)")
            }
            session.cancelConfirm()
            session.chooseRecipe(.translate)
            guard session.recipeNetworkFact == "开" else {
                fail("translate network \(session.recipeNetworkFact)")
            }
            session.cancelConfirm()
            session.recipePresence = .none
            guard session.recipeWriteFact == "无 Codex", session.recipeNetworkFact == "无 Codex" else {
                fail("no recipe write/network \(session.recipeWriteFact) \(session.recipeNetworkFact)")
            }
            if let id = session.items.first(where: { $0.title == "facts.md" })?.id {
                session.remove(id: id)
            }
            session.refreshPresence()
        }

        private func verifyRecipeChooserHint() {
            try? DropAgentPaths.ensure()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .workspace)
            let zip = DropAgentPaths.inbox.appendingPathComponent("archive.zip")
            try? Data("PK".utf8).write(to: zip)
            session.admit(urls: [zip])
            let zipHint = session.recipeChooserHint
            guard zipHint.contains("这类文件不能总结或翻译") else {
                fail("zip recipe hint \(zipHint)")
            }
            guard zipHint.contains("新交付") else {
                fail("zip hint missing brief \(zipHint)")
            }
            guard zipHint.contains("或在下面写一句话") == false else {
                fail("zip hint still generic \(zipHint)")
            }
            let pdf = DropAgentPaths.inbox.appendingPathComponent("hint.pdf")
            try? Data("%PDF-1.4 hint\n".utf8).write(to: pdf)
            session.admit(urls: [pdf])
            let pdfHint = session.recipeChooserHint
            guard pdfHint.contains("或在下面写一句话") else {
                fail("pdf recipe hint \(pdfHint)")
            }
            for title in ["archive.zip", "hint.pdf"] {
                if let id = session.items.first(where: { $0.title == title })?.id {
                    session.remove(id: id)
                }
            }
            session.refreshPresence()
        }

        private func verifyImageRecipeGates() {
            try? DropAgentPaths.ensure()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .workspace)
            let png = DropAgentPaths.inbox.appendingPathComponent("shot.png")
            try? tinyPNG().write(to: png)
            session.admit(urls: [png])
            guard session.items.contains(where: { $0.kind == .image }) else {
                fail("no image item")
            }
            guard session.recipeFitsSelection(.summarize) else {
                fail("image summarize disabled")
            }
            guard session.recipeFitsSelection(.translate) == false else {
                fail("image translate enabled")
            }
            guard session.recipeFitsSelection(.redact) == false else {
                fail("image redact enabled")
            }
            guard session.recipeFitsSelection(.brief) == false else {
                fail("image brief enabled")
            }
            if let id = session.items.first(where: { $0.title == "shot.png" })?.id {
                session.remove(id: id)
            }
            session.refreshPresence()
        }

        private func verifyFailedActionRetry() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("fail.md")
            try? Data("# fail\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let id = session.items.first(where: { $0.title == "fail.md" })?.id else {
                fail("no fail.md")
            }
            try? session.shelf.patch(id: id) { live in
                live.status = .failed
                live.failureReason = "任务失败"
            }
            session.refresh()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .workspace)
            guard session.isFailedOutputTakeaway == false else {
                fail("no-output failure marked takeaway")
            }
            guard session.selectedFailureReason == "任务失败" else {
                fail("failed reason \(session.selectedFailureReason ?? "nil")")
            }
            guard session.failedRetryLine == "再点一个动作可以重试。" else {
                fail("retry line \(session.failedRetryLine ?? "nil")")
            }
            session.recipePresence = .none
            guard session.selectedFailureReason == "任务失败" else {
                fail("failed reason without recipe \(session.selectedFailureReason ?? "nil")")
            }
            guard session.failedRetryLine == nil else {
                fail("retry promised without Codex \(session.failedRetryLine ?? "")")
            }
            session.remove(id: id)
            session.refreshPresence()
        }

        private func verifyFailedOutputTakeaway() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("hash-out.md")
            try? Data("# hash out\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let id = session.items.first(where: { $0.title == "hash-out.md" })?.id else {
                fail("no hash-out.md")
            }
            guard session.isFailedOutputTakeaway == false else {
                fail("idle marked failed-output takeaway")
            }
            try? session.shelf.patch(id: id) { live in
                live.status = .failed
                live.failureReason = "原件中途变了，结果按副本做的"
                live.output = note
                live.recipe = RecipeID.summarize.fullTitle
            }
            session.refresh()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .workspace)
            guard session.isFailedOutputTakeaway else {
                fail("failed output not takeaway")
            }
            guard session.isDoneTakeaway == false else {
                fail("failed output counted as done")
            }
            guard session.isResultTakeaway else {
                fail("failed output not result takeaway")
            }
            guard session.failedOutputRetryRecipe == .summarize else {
                fail("retry recipe \(String(describing: session.failedOutputRetryRecipe))")
            }
            session.recipePresence = .none
            guard session.failedOutputRetryRecipe == nil else {
                fail("retry without Codex \(String(describing: session.failedOutputRetryRecipe))")
            }
            session.remove(id: id)
            session.refreshPresence()
        }

        private func verifyDoneTakeaway() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("done.md")
            try? Data("# done\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard session.isDoneTakeaway == false else {
                fail("idle marked takeaway")
            }
            guard let id = session.items.first(where: { $0.title == "done.md" })?.id else {
                fail("no done.md")
            }
            try? session.shelf.patch(id: id) { live in
                live.status = .done
                live.output = note
            }
            session.refresh()
            guard session.isDoneTakeaway else {
                fail("done not takeaway")
            }
            guard session.doneActionHint.contains("点「结果」拿走") else {
                fail("done hint \(session.doneActionHint)")
            }
            guard session.doneActionHint.contains("不能跑这些动作") == false else {
                fail("done hint still rejection \(session.doneActionHint)")
            }
            session.remove(id: id)
        }

        private func verifySourceLink() {
            guard SourceLink.isOpenable(URL(string: "https://example.com")!) else {
                fail("https should open")
            }
            guard SourceLink.isOpenable(URL(string: "http://example.com")!) else {
                fail("http should open")
            }
            guard SourceLink.isOpenable(URL(fileURLWithPath: "/tmp/note.md")) == false else {
                fail("file url opened")
            }
            guard SourceLink.isOpenable(URL(string: "javascript:alert(1)")!) == false else {
                fail("javascript opened")
            }
        }

        private func verifyResultJSON() {
            let pretty = ResultJSON.pretty("{\"b\":1,\"a\":2}")
            guard let pretty, pretty.contains("\n") else {
                fail("json pretty \(pretty ?? "nil")")
            }
            guard let a = pretty.range(of: "\"a\""), let b = pretty.range(of: "\"b\""), a.lowerBound < b.lowerBound else {
                fail("json keys not sorted \(pretty)")
            }
            guard ResultJSON.pretty("# heading") == nil else {
                fail("markdown pretty-printed as json")
            }
        }

        private func verifyStagedPreview() {
            guard StagedPreview.mode(title: "note.md", body: "# Keep") == .markdown else {
                fail("md should stay markdown")
            }
            guard StagedPreview.mode(title: "data.json", body: "{\"a\":1}") == .json else {
                fail("json should pretty")
            }
            guard StagedPreview.mode(title: "main.swift", body: "let x = *star*") == .code else {
                fail("swift should be code")
            }
            guard StagedPreview.mode(title: "config.yaml", body: "name: drop") == .code else {
                fail("yaml should be code")
            }
        }

        private func verifyResultTakeawayPinned() async {
            try? DropAgentPaths.ensure()
            let pdf = DropAgentPaths.inbox.appendingPathComponent("takeaway.pdf")
            try? Data("%PDF-1.4 takeaway\n".utf8).write(to: pdf)
            session.admit(urls: [pdf])
            session.aiTab = .result
            await settle()
            guard session.currentResult()?.kind == .pdf else {
                fail("result empty after admit")
            }
            snapshot("e2e-result")
            if let id = session.items.first(where: { $0.title == "takeaway.pdf" })?.id {
                session.remove(id: id)
            }
            session.aiTab = .work
        }

        private func verifyPresenceGates() async {
            try? DropAgentPaths.ensure()
            let pdf = DropAgentPaths.inbox.appendingPathComponent("gates.pdf")
            try? Data("%PDF-1.4 gates-e2e\n".utf8).write(to: pdf)
            session.presence = .none
            session.recipePresence = .none
            session.admitToTUI(urls: [pdf])
            await settle()
            guard let item = session.items.first(where: { $0.title == "gates.pdf" }) else {
                fail("no-tui admit missing")
            }
            guard item.status == .idle else {
                fail("no-tui status \(item.status)")
            }
            guard session.canSendToTUI == false else {
                fail("send enabled without TUI")
            }
            guard session.hasRecipe == false else {
                fail("recipe enabled without Codex")
            }
            guard session.composerPlaceholder == "未发现终端 Agent" else {
                fail("placeholder \(session.composerPlaceholder)")
            }
            guard session.errorText == "未发现终端 Agent。文件已留在架子上。" else {
                fail("no-tui error \(session.errorText ?? "nil")")
            }
            session.sendToTUI(itemIDs: [item.id])
            await settle()
            guard session.items.first(where: { $0.id == item.id })?.status == .idle else {
                fail("send without TUI mutated")
            }
            snapshot("e2e-no-tui")

            session.dismissError()
            session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
            await settle()
            guard session.canSendToTUI else {
                fail("send disabled with TUI")
            }
            guard session.hasRecipe == false else {
                fail("recipe enabled TUI-only")
            }
            guard session.recipeChooserHint.contains("动作需要 Codex") else {
                fail("tui-only hint \(session.recipeChooserHint)")
            }
            guard session.recipeChooserHint.contains("Grok") else {
                fail("tui-only hint missing Grok \(session.recipeChooserHint)")
            }
            session.chooseRecipe(.summarize)
            await session.confirmRun()
            await settle()
            guard session.items.first(where: { $0.id == item.id })?.status == .confirm else {
                fail("confirmRun without Codex \(session.items.first(where: { $0.id == item.id })?.status.rawValue ?? "gone")")
            }
            guard session.items.contains(where: { $0.title == "summary.md" }) == false else {
                fail("stub job ran without Codex gate")
            }
            guard session.errorText == "动作需要 Codex。终端仍可发送给 Grok。" else {
                fail("tui-only confirm \(session.errorText ?? "nil")")
            }
            snapshot("e2e-tui-only")
            session.cancelConfirm()
            session.dismissError()
            session.presence = .none
            session.recipePresence = .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            await settle()
            guard session.hasRecipe else {
                fail("recipe off without TUI")
            }
            guard session.canSendToTUI == false else {
                fail("send enabled without TUI but with Codex")
            }
            guard session.recipeFitsSelection(.summarize) else {
                fail("summarize unfit with Codex-only")
            }
            snapshot("e2e-recipe-only")
            session.dismissError()
            session.remove(id: item.id)
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyRecipeLoop() async {
            try? DropAgentPaths.ensure()
            let pdf = DropAgentPaths.inbox.appendingPathComponent("recipe-source.pdf")
            try? Data("%PDF-1.4 recipe-e2e\n".utf8).write(to: pdf)
            let before = hash(pdf)
            session.admit(urls: [pdf])
            await settle()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .codex(path: path, isolation: .workspace)
            session.chooseRecipe(.summarize)
            await session.confirmRun()
            await settle()
            guard let item = session.items.first(where: { $0.title == "summary.md" }) else {
                fail(session.errorText ?? "recipe did not finish")
            }
            guard item.status == .done else {
                fail("recipe status \(item.status)")
            }
            guard item.output != nil else {
                fail("recipe missing output")
            }
            guard hash(pdf) == before else {
                fail("recipe changed original")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-recipe-result")
            do {
                let landed = try await land(item)
                guard landed.lastPathComponent == "summary.md" else {
                    fail("recipe landed \(landed.lastPathComponent)")
                }
                let body = (try? String(contentsOf: landed, encoding: .utf8)) ?? ""
                guard body.contains(RecipeStubAgent.summaryBody) else {
                    fail("recipe body \(body)")
                }
            } catch {
                fail("recipe drag land \(error)")
            }
            session.remove(id: item.id)
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyExtractLoop() async {
            try? DropAgentPaths.ensure()
            let pdf = DropAgentPaths.inbox.appendingPathComponent("extract-source.pdf")
            try? Data("%PDF-1.4 extract-e2e\n".utf8).write(to: pdf)
            let before = hash(pdf)
            session.admit(urls: [pdf])
            await settle()
            session.recipePresence = .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            session.chooseRecipe(.extract)
            await session.confirmRun()
            await settle()
            guard let item = session.items.first(where: { $0.title == "extracted.json" }) else {
                fail(session.errorText ?? "extract did not finish")
            }
            guard item.status == .done else {
                fail("extract status \(item.status)")
            }
            guard hash(pdf) == before else {
                fail("extract changed original")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-extract-result")
            do {
                let landed = try await land(item)
                guard landed.lastPathComponent == "extracted.json" else {
                    fail("extract landed \(landed.lastPathComponent)")
                }
                let body = (try? String(contentsOf: landed, encoding: .utf8)) ?? ""
                guard body.contains(RecipeStubAgent.jsonBody) else {
                    fail("extract body \(body)")
                }
                guard (try? JSONSerialization.jsonObject(with: Data(body.utf8))) != nil else {
                    fail("extract not json \(body)")
                }
            } catch {
                fail("extract drag land \(error)")
            }
            session.remove(id: item.id)
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyBriefLoop() async {
            try? DropAgentPaths.ensure()
            let first = DropAgentPaths.inbox.appendingPathComponent("brief-a.md")
            let second = DropAgentPaths.inbox.appendingPathComponent("brief-b.md")
            try? Data("# A\n".utf8).write(to: first)
            try? Data("# B\n".utf8).write(to: second)
            let beforeA = hash(first)
            let beforeB = hash(second)
            session.admit(urls: [first])
            await settle()
            session.recipePresence = .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            guard session.recipeFitsSelection(.brief) == false else {
                fail("brief accepted one item")
            }
            session.admit(urls: [second])
            await settle()
            guard let idA = session.items.first(where: { $0.title == "brief-a.md" })?.id else {
                fail("no brief-a")
            }
            session.toggleSelect(id: idA, command: true)
            guard session.recipeFitsSelection(.brief) else {
                fail("brief unfit \(session.selectedItems.map(\.title))")
            }
            session.chooseRecipe(.brief)
            await session.confirmRun()
            await settle()
            let briefs = session.items.filter { $0.title == "brief.md" }
            guard briefs.count == 2, briefs.allSatisfy({ $0.status == .done }) else {
                fail(session.errorText ?? "brief did not finish \(session.items.map { "\($0.title):\($0.status.rawValue)" })")
            }
            guard hash(first) == beforeA, hash(second) == beforeB else {
                fail("brief changed originals")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-brief-result")
            do {
                let landed = try await land(briefs[0])
                guard landed.lastPathComponent == "brief.md" else {
                    fail("brief landed \(landed.lastPathComponent)")
                }
                let body = (try? String(contentsOf: landed, encoding: .utf8)) ?? ""
                guard body.contains(RecipeStubAgent.summaryBody) else {
                    fail("brief body \(body)")
                }
            } catch {
                fail("brief drag land \(error)")
            }
            for item in briefs {
                session.remove(id: item.id)
            }
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyFolderLoop() async {
            try? DropAgentPaths.ensure()
            let original = DropAgentPaths.root.appendingPathComponent("e2e-folder", isDirectory: true)
            try? FileManager.default.removeItem(at: original)
            try? FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
            let notes = original.appendingPathComponent("notes.md")
            try? Data("folder-notes\n".utf8).write(to: notes)
            let before = hash(notes)
            session.admit(urls: [original])
            await settle()
            guard let item = session.items.first(where: { $0.kind == .folder && $0.title == "e2e-folder" }) else {
                fail("folder admit missing \(session.items.map { "\($0.kind.tag):\($0.title)" })")
            }
            guard item.displayTag == "DIR" else {
                fail("folder tag \(item.displayTag)")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-folder")
            do {
                let landed = try await land(item)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: landed.path, isDirectory: &isDir), isDir.boolValue else {
                    fail("folder land not directory \(landed.lastPathComponent)")
                }
                guard landed.lastPathComponent == "e2e-folder" else {
                    fail("folder name \(landed.lastPathComponent)")
                }
                let landedNotes = (try? String(contentsOf: landed.appendingPathComponent("notes.md"), encoding: .utf8)) ?? ""
                guard landedNotes.contains("folder-notes") else {
                    fail("folder notes \(landedNotes)")
                }
            } catch {
                fail("folder drag land \(error)")
            }
            guard hash(notes) == before else {
                fail("folder changed original")
            }
            session.remove(id: item.id)
            session.aiTab = .work
        }

        private func verifyZipLoop() async {
            try? DropAgentPaths.ensure()
            let zip = DropAgentPaths.root.appendingPathComponent("archive.zip")
            try? Data("PK\u{03}\u{04}e2e-zip\n".utf8).write(to: zip)
            let before = hash(zip)
            session.admit(urls: [zip])
            await settle()
            guard let item = session.items.first(where: { $0.title == "archive.zip" }) else {
                fail("zip admit missing")
            }
            guard item.kind == .file, item.displayTag == "ZIP" else {
                fail("zip kind \(item.kind.rawValue) tag \(item.displayTag)")
            }
            guard session.recipeFitsSelection(.summarize) == false else {
                fail("zip summarize enabled")
            }
            guard session.recipeFitsSelection(.translate) == false else {
                fail("zip translate enabled")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-zip")
            do {
                let landed = try await land(item)
                guard landed.lastPathComponent == "archive.zip" else {
                    fail("zip landed \(landed.lastPathComponent)")
                }
                guard hash(landed) == before else {
                    fail("zip land bytes changed")
                }
            } catch {
                fail("zip drag land \(error)")
            }
            guard hash(zip) == before else {
                fail("zip changed original")
            }
            session.remove(id: item.id)
            session.aiTab = .work
        }

        private func verifyClipboardLoop() async {
            let textBoard = NSPasteboard.withUniqueName()
            textBoard.clearContents()
            guard textBoard.setString("e2e-clip-body", forType: .string) else {
                fail("clip text pasteboard")
            }
            session.pasteFromClipboard(PasteboardClipboard(textBoard))
            await settle()
            guard let clip = session.items.first(where: { $0.kind == .clip && $0.title == "剪贴板" }) else {
                fail("clip admit missing")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-clip")
            let clipCopy = NSPasteboard.withUniqueName()
            session.copyItem(clip, to: clipCopy)
            await settle()
            guard clipCopy.string(forType: .string)?.contains("e2e-clip-body") == true else {
                fail("clip copy \(clipCopy.string(forType: .string) ?? "nil")")
            }
            guard session.copiedID == clip.id else {
                fail("clip copiedID")
            }
            snapshot("e2e-clip-copied")
            do {
                let landed = try await land(clip)
                guard landed.lastPathComponent == "clip.txt" else {
                    fail("clip landed \(landed.lastPathComponent)")
                }
                let body = (try? String(contentsOf: landed, encoding: .utf8)) ?? ""
                guard body.contains("e2e-clip-body") else {
                    fail("clip body \(body)")
                }
            } catch {
                fail("clip drag land \(error)")
            }
            session.remove(id: clip.id)

            let rtfBoard = NSPasteboard.withUniqueName()
            rtfBoard.clearContents()
            let rich = NSAttributedString(string: "e2e-rtf-clip")
            guard let rtf = try? rich.data(
                from: NSRange(location: 0, length: rich.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ), rtfBoard.setData(rtf, forType: .rtf) else {
                fail("clip rtf pasteboard")
            }
            session.pasteFromClipboard(PasteboardClipboard(rtfBoard))
            await settle()
            guard let rtfItem = session.items.first(where: { $0.kind == .clip }) else {
                fail("rtf clip missing")
            }
            let rtfBody = rtfItem.parts.first.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) } ?? ""
            guard rtfBody.contains("e2e-rtf-clip") else {
                fail("rtf clip body \(rtfBody)")
            }
            session.remove(id: rtfItem.id)

            let imageBoard = NSPasteboard.withUniqueName()
            imageBoard.clearContents()
            let png = tinyPNG()
            guard let nsImage = NSImage(data: png) else {
                fail("clip png image")
            }
            imageBoard.writeObjects([nsImage])
            session.pasteFromClipboard(PasteboardClipboard(imageBoard))
            await settle()
            guard let image = session.items.first(where: { $0.kind == .image }) else {
                fail("clip image missing")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-clip-image")
            let imageCopy = NSPasteboard.withUniqueName()
            session.copyItem(image, to: imageCopy)
            let copiedImages = imageCopy.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] ?? []
            guard copiedImages.isEmpty == false else {
                fail("clip image copy empty")
            }
            do {
                let landed = try await land(image)
                guard landed.lastPathComponent == "clipboard.png" else {
                    fail("clip image landed \(landed.lastPathComponent)")
                }
                let bytes = (try? Data(contentsOf: landed)) ?? Data()
                guard bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
                    fail("clip image not png")
                }
            } catch {
                fail("clip image drag land \(error)")
            }
            session.remove(id: image.id)

            let urlBoard = NSPasteboard.withUniqueName()
            urlBoard.clearContents()
            guard urlBoard.setString("https://example.com/e2e-url", forType: .string) else {
                fail("url pasteboard")
            }
            session.pasteFromClipboard(PasteboardClipboard(urlBoard))
            await settle()
            guard let link = session.items.first(where: { $0.kind == .url }) else {
                fail("url admit missing")
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-url")
            let urlCopy = NSPasteboard.withUniqueName()
            session.copyItem(link, to: urlCopy)
            let urlFiles = urlCopy.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] ?? []
            guard urlFiles.isEmpty else {
                fail("url copy has file \(urlFiles)")
            }
            guard urlCopy.string(forType: .string) == "https://example.com/e2e-url" else {
                fail("url copy \(urlCopy.string(forType: .string) ?? "nil")")
            }
            session.remove(id: link.id)
            session.aiTab = .work
        }

        private func tinyPNG() -> Data {
            let image = NSImage(size: NSSize(width: 2, height: 2), flipped: false) { rect in
                NSColor.red.setFill()
                rect.fill()
                return true
            }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:])
            else {
                fail("tiny png")
            }
            return png
        }

        private func verifyCaptureLoop() async {
            let beforeWeb = session.items.filter { $0.kind == .web }.count
            await session.captureCurrentPage(frozen: nil)
            showPanelWindow()
            await settle()
            guard session.items.filter({ $0.kind == .web }).count == beforeWeb else {
                fail("capture invented web item")
            }
            guard session.errorText == CaptureRecovery.noBrowserHotKey else {
                fail("capture fail copy \(session.errorText ?? "nil")")
            }
            guard session.offerCaptureRetry else {
                fail("capture fail missing retry")
            }
            guard session.offerPrivacySettings == false else {
                fail("no-browser offered privacy")
            }
            snapshot("e2e-capture-fail")
            session.dismissError()

            guard await bringSafariExample() else {
                deferredCaptureFailure = "safari not front \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil")"
                return
            }
            await session.captureCurrentPage()
            showPanelWindow()
            await settle()
            guard let item = session.items.first(where: {
                $0.kind == .web && ($0.sourceURL.host == "example.com" || $0.sourceURL.host == "www.example.com")
            }) else {
                fail(session.errorText ?? "safari capture missing WEB")
            }
            guard item.status == .idle else {
                fail("web status \(item.status)")
            }
            guard item.parts.contains(where: { $0.name == "url.txt" }) else {
                fail("web missing url.txt")
            }
            guard item.parts.contains(where: { $0.name == "page.md" }) else {
                fail("web missing page.md")
            }
            guard item.parts.contains(where: { $0.name == "snapshot.png" }) else {
                fail("web missing snapshot.png")
            }
            snapshot("e2e-capture-web")
            session.aiTab = .result
            showPanelWindow()
            await settle()
            snapshot("e2e-capture-web-result")
            do {
                let landed = try await land(item)
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: landed.path, isDirectory: &isDir), isDir.boolValue else {
                    fail("web land not folder \(landed.lastPathComponent)")
                }
                guard landed.lastPathComponent == item.title else {
                    fail("web folder name \(landed.lastPathComponent)")
                }
                for name in ["url.txt", "page.md", "snapshot.png"] {
                    guard FileManager.default.fileExists(atPath: landed.appendingPathComponent(name).path) else {
                        fail("web folder missing \(name)")
                    }
                }
            } catch {
                fail("web drag land \(error)")
            }
            session.remove(id: item.id)
            session.dismissError()
            session.aiTab = .work
        }

        private func bringSafariExample() async -> Bool {
            let opener = Process()
            opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            opener.arguments = ["-a", "Safari", "https://example.com/"]
            do {
                try opener.run()
                opener.waitUntilExit()
            } catch {
                fail("open safari \(error)")
            }
            for _ in 0..<30 {
                activateSafari()
                try? await Task.sleep(nanoseconds: 200_000_000)
                if BrowserFront.current()?.kind == .safari {
                    return true
                }
            }
            return false
        }

        private func activateSafari() {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            proc.arguments = ["-e", "tell application \"Safari\" to activate"]
            try? proc.run()
            proc.waitUntilExit()
        }

        private func showPanelWindow() {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        private func verifyResultMarkdown() {
            let blocks = ResultMarkdown.blocks("""
            # Keep

            ```
            npm i
            ```

            after
            """)
            guard blocks.count == 3 else {
                fail("result markdown count \(blocks.count)")
            }
            guard blocks[0] == .heading("Keep") else {
                fail("result markdown heading \(blocks[0])")
            }
            guard blocks[1] == .code("npm i") else {
                fail("result markdown code \(blocks[1])")
            }
            guard blocks[2] == .paragraph("after") else {
                fail("result markdown paragraph \(blocks[2])")
            }
            let language = ResultMarkdown.blocks("```swift\nlet x = 1\n```")
            guard language == [.code("let x = 1")] else {
                fail("result markdown language \(language)")
            }
            let table = ResultMarkdown.blocks("| A | B |\n| --- | --- |\n| 1 | 2 |")
            guard table == [.code("| A | B |\n| --- | --- |\n| 1 | 2 |")] else {
                fail("result markdown table \(table)")
            }
            let quote = ResultMarkdown.blocks("> Note")
            guard quote == [.quote("Note")] else {
                fail("result markdown quote \(quote)")
            }
            let image = ResultMarkdown.blocks("![示意图](https://example.com/fig.png)")
            guard image == [.image(alt: "示意图", url: "https://example.com/fig.png")] else {
                fail("result markdown image \(image)")
            }
        }

        private func verifyStatusIcon() {
            let image = StatusIcon.image()
            guard abs(image.size.width - 18) < 0.5, abs(image.size.height - 18) < 0.5 else {
                fail("status icon size \(image.size)")
            }
            guard image.isTemplate else {
                fail("status icon not template")
            }
            let scales = Set(image.representations.compactMap { rep -> Int? in
                guard let bitmap = rep as? NSBitmapImageRep else { return nil }
                return Int((CGFloat(bitmap.pixelsWide) / max(image.size.width, 1)).rounded())
            })
            guard scales.contains(1), scales.contains(2) else {
                fail("status icon scales \(scales)")
            }
        }

        private func verifyStatusHover() {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
            let drop = StatusDropView(frame: button.bounds)
            var panelOpen = false
            drop.panelVisible = { panelOpen }
            button.addSubview(drop)
            drop.updateTrackingAreas()
            guard drop.trackingAreas.contains(where: { $0.options.contains(.mouseEnteredAndExited) }) else {
                fail("status hover tracking")
            }
            drop.applyHover(true)
            guard button.isHighlighted else {
                fail("status hover did not highlight")
            }
            drop.applyHover(false)
            guard button.isHighlighted == false else {
                fail("status hover stuck")
            }
            panelOpen = true
            drop.applyHover(false)
            guard button.isHighlighted else {
                fail("status open lost highlight")
            }
        }

        private func verifyLivePanelChrome() {
            guard LivePanelChrome.styleMask.contains(.borderless) else {
                fail("live panel not borderless")
            }
            guard LivePanelChrome.styleMask.contains(.titled) == false else {
                fail("live panel still titled")
            }
            let panel = DropAgentPanel(
                contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
                styleMask: LivePanelChrome.styleMask,
                backing: .buffered,
                defer: true
            )
            guard panel.canBecomeKey else {
                fail("borderless panel cannot become key")
            }
            let host = PaperHostView(rootView: Color.clear.frame(width: 40, height: 40))
            guard host.acceptsFirstMouse(for: nil) else {
                fail("paper host rejects first mouse")
            }
        }

        private func verifyEdgePlacement() {
            guard let screen = NSScreen.main ?? NSScreen.screens.first else {
                fail("no screen for edge")
            }
            let visible = screen.visibleFrame
            let inBand = NSPoint(x: visible.minX + 24, y: visible.maxY - 4)
            guard let frame = EdgePlacement.frame(mouse: inBand, screens: NSScreen.screens) else {
                fail("edge band missed")
            }
            let expectedWidth = max(160, visible.width - 16)
            guard abs(frame.width - expectedWidth) < 0.5 else {
                fail("edge width \(frame.width) != \(expectedWidth)")
            }
            guard abs(frame.origin.x - (visible.minX + 8)) < 0.5 else {
                fail("edge x \(frame.origin.x)")
            }
            guard abs(frame.height - 36) < 0.5 else {
                fail("edge height \(frame.height)")
            }
            let middle = NSPoint(x: visible.midX, y: visible.midY)
            if EdgePlacement.frame(mouse: middle, screens: NSScreen.screens) != nil {
                fail("edge lit in screen middle")
            }
        }

        private func verifyListHeightFit() {
            for item in session.items {
                session.remove(id: item.id)
            }
            guard abs(session.displayListHeight - 140) < 0.5 else {
                fail("empty list height \(session.displayListHeight)")
            }
            try? DropAgentPaths.ensure()
            let first = DropAgentPaths.inbox.appendingPathComponent("fit-a.pdf")
            try? Data("%PDF-1.4 fit-a\n".utf8).write(to: first)
            session.admit(urls: [first])
            guard abs(session.displayListHeight - 56) < 0.5 else {
                fail("one row height \(session.displayListHeight)")
            }
            let second = DropAgentPaths.inbox.appendingPathComponent("fit-b.pdf")
            try? Data("%PDF-1.4 fit-b\n".utf8).write(to: second)
            session.admit(urls: [second])
            guard abs(session.displayListHeight - 112) < 0.5 else {
                fail("two row height \(session.displayListHeight)")
            }
            for item in session.items {
                session.remove(id: item.id)
            }
            session.refresh()
            guard abs(session.displayListHeight - 140) < 0.5 else {
                fail("cleared list height \(session.displayListHeight) items=\(session.items.count)")
            }
        }

        private func sourcePDF() -> URL {
            let args = CommandLine.arguments
            if let idx = args.firstIndex(of: "--pdf"), args.indices.contains(idx + 1) {
                return URL(fileURLWithPath: args[idx + 1])
            }
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(
                "da-e2e-src-\(UUID().uuidString)",
                isDirectory: true
            )
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let pdf = dir.appendingPathComponent("sample.pdf")
            try? Data("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\ne2e-summarize\n".utf8).write(to: pdf)
            return pdf
        }

        private func land(_ item: Item) async throws -> URL {
            let desktop: URL
            if let idx = CommandLine.arguments.firstIndex(of: "--out"), CommandLine.arguments.indices.contains(idx + 1) {
                desktop = URL(fileURLWithPath: CommandLine.arguments[idx + 1], isDirectory: true)
            } else {
                desktop = DropAgentPaths.root.appendingPathComponent("Desktop", isDirectory: true)
            }
            try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
            let provider = PasteboardService.itemProvider(for: item)
            let source = try await loadFileURL(provider)
            let landed = desktop.appendingPathComponent(source.lastPathComponent)
            if FileManager.default.fileExists(atPath: landed.path) {
                try FileManager.default.removeItem(at: landed)
            }
            try FileManager.default.copyItem(at: source, to: landed)
            return landed
        }

        private func loadFileURL(_ provider: NSItemProvider) async throws -> URL {
            try await withCheckedThrowingContinuation { continuation in
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        if let url { continuation.resume(returning: url) }
                        else { continuation.resume(throwing: error ?? NSError(domain: "DropAgentE2E", code: 1)) }
                    }
                    return
                }
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                    } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        continuation.resume(returning: url)
                    } else {
                        continuation.resume(throwing: error ?? NSError(domain: "DropAgentE2E", code: 2))
                    }
                }
            }
        }

        private func hash(_ url: URL) -> String {
            guard let data = try? Data(contentsOf: url), data.isEmpty == false else {
                fail("cannot read original \(url.path)")
            }
            return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }

        private func settle() async {
            window?.displayIfNeeded()
            hosting?.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 250_000_000)
            window?.displayIfNeeded()
        }

        private func snapshot(_ name: String) {
            guard let view = hosting else { return }
            view.layoutSubtreeIfNeeded()
            let bounds = view.bounds
            guard bounds.width > 1, bounds.height > 1,
                  let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else { return }
            view.cacheDisplay(in: bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: uiOut.appendingPathComponent("\(name).png"))
        }

        private func fail(_ message: String) -> Never {
            fputs("e2e: fail \(message)\n", stderr)
            exit(1)
        }

        private static func forceRemove(_ url: URL) {
            let fm = FileManager.default
            func unlock(_ url: URL) {
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
                try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
                if isDir.boolValue, let children = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                    for child in children { unlock(child) }
                }
            }
            unlock(url)
            try? fm.removeItem(at: url)
        }
    }
}

private final class RecipeStubAgent: AgentRunning, @unchecked Sendable {
    static let summaryBody = "e2e-recipe-summary"
    static let jsonBody = "{\"e2e\":true}"
    var settings = AgentSettings()

    func discover(settings: AgentSettings) -> AgentPresence {
        .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
    }

    func isolationCopy(for presence: AgentPresence) -> String {
        IsolationShown.workspace.spokenFact ?? "Workspace Sandbox：Agent 只能写任务工作区"
    }

    func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        try FileManager.default.createDirectory(
            at: request.outputFile.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let body = request.outputFile.pathExtension.lowercased() == "json" ? Self.jsonBody : Self.summaryBody
        try body.write(to: request.outputFile, atomically: true, encoding: .utf8)
        onEvent?(AgentEvent(message: "写入 output/"))
        return AgentRunResult(
            exitCode: 0,
            events: [AgentEvent(message: "写入 output/")],
            lastMessage: body
        )
    }

    func ensureInteractiveSession() throws -> SessionHandle {
        throw AgentError.notFound
    }

    func cancelCurrent() {}
}
