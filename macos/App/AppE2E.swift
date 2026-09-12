import AppKit
import CryptoKit
import DropAgentAgent
import DropAgentIngest
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import CoreText
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
            if CommandLine.arguments.contains("--panel-only") {
                Task { @MainActor in
                    await PanelE2E.run()
                    NSApp.terminate(nil)
                }
                return
            }
            if CommandLine.arguments.contains("--wheel-only") {
                WheelE2E.run()
                NSApp.terminate(nil)
                return
            }
            session = AppSession(jobRunner: RecipeStubAgent())

            let window = NSWindow(
                contentRect: NSRect(x: 40, y: 40, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight),
                styleMask: LivePanelChrome.styleMask,
                backing: .buffered,
                defer: false
            )
            window.title = "DropAgent Workbench QA"
            window.hasShadow = true
            let host = PaperHostView(rootView: PanelRootView(session: session, onClose: {}, onMinimize: {}))
            host.frame = NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight)
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
                if !CommandLine.arguments.contains("--workbench-review") { NSApp.terminate(nil) }
            }
        }

        @MainActor
        private func go() async {
            if CommandLine.arguments.contains("--workbench-only"), let window, let hosting {
                await WorkbenchE2E.run(session: session, window: window, host: hosting)
                return
            }
            session.setTUIPreference(.grok)
            await settle()
            await verifyOnboarding()
            if ProcessInfo.processInfo.arguments.contains("--ui-only") {
                verifyTtyTheme()
                await verifyErrorRecoveryUI()
                await verifyPanelSettings()
                verifyContentStage()
                await verifyActionBar()
                verifyFailedActionRetry()
                verifyFailedOutputTakeaway()
                verifyDoneTakeaway()
                await verifyPdfTextLoop()
                await verifyImageTextLoop()
                fputs("e2e: ui ok — onboarding, permissions recovery UI, settings, editing, actions, failure, PDF, OCR, export\n", stdout)
                return
            }
            session.systemDragActive = true
            await settle()
            snapshot("e2e-drag-empty")
            session.systemDragActive = false
            verifyEdgePlacement()
            WheelE2E.run()
            verifyLivePanelChrome()
            verifyPanelIdle()
            verifyPlusKeepsPanel()
            verifyPermissionLowersPanel()
            verifyStatusItemPinned()
            verifyFirstOpen()
            await verifySetupCard()
            await verifyPaneLayout()
            verifyShelfDragRelease()
            verifyStatusIcon()
            await verifyPanelSettings()
            verifyFrontFileHotKey()
            await verifyShelfAddSearch()
            verifyStatusHover()
            verifyResultMarkdown()
            verifyContentStage()
            verifyFileKindGlyph()
            verifyTtyTheme()
            verifyIsolationFact()
            verifyIsolationShownRecord()
            verifyOpenItem()
            verifyConfirmFacts()
            verifyEmptyWorkHint()
            verifyRecipeChooserHint()
            verifyImageRecipeGates()
            verifyPdfRecipeGates()
            await verifyActionBar()
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
            await verifyImageTextLoop()
            await verifyPdfTextLoop()
            await verifyBriefLoop()
            await verifyFolderLoop()
            await verifyZipLoop()
            await verifyClipboardLoop()
            await verifyClipHistory()
            await verifyCopyFilesToShelf()
            verifyPolishPaths()
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
            guard session.aiTab == .tty else {
                fail("did not switch to tty")
            }
            guard session.otherOpen, session.showsComposer else {
                fail("send did not open the chat float")
            }
            session.aiTab = .work
            await settle()
            guard session.recipeFitsSelection(.summarize) else {
                fail("sent item lost recipes")
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
                guard FileManager.default.fileExists(atPath: DropAgentPaths.openedFile.path) == false else {
                    fail("e2e wrote first-open marker")
                }
            } catch {
                fail("drag land \(error)")
            }
        }

        private func verifyPolishPaths() {
            let folder = DropAgentPaths.root.appendingPathComponent("polish-check", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let a = folder.appendingPathComponent("第一份材料.md")
            let b = folder.appendingPathComponent("新加入材料.md")
            try? Data("# 新材料\n发送这一份，而不是旧结果。".utf8).write(to: a)
            try? Data("# 第二份材料".utf8).write(to: b)
            session.admit(urls: [a])
            guard let first = session.selectedItems.first else { fail("polish first input missing") }
            let r1 = session.shelf.addResult(ResultRecord(sourceItemIDs: [first.id], recipe: "总结文件", title: "旧结果.md", kind: .markdown, output: a))
            let r2 = session.shelf.addResult(ResultRecord(sourceItemIDs: [first.id], recipe: "总结文件", title: "另一结果.md", kind: .markdown, output: b))
            session.refresh()
            session.selectResult(r2.id)
            session.moveSelection(offset: 1)
            guard session.selectedResultID == r1.id, session.paneFocus == .result else { fail("result arrows switched to input") }
            try? session.shelf.patch(id: first.id) { $0.status = .running }
            guard session.canSendToTUI else { fail("unrelated running input blocked result send") }
            try? session.shelf.patch(id: first.id) { $0.status = .idle }
            session.errorText = "previous failure"
            session.admit(urls: [b])
            guard let second = session.selectedItems.first, second.id != first.id,
                  session.paneFocus == .input, session.currentResult()?.id == second.id,
                  session.errorText == nil else { fail("new material retained stale result focus or error") }
            let failed = session.shelf.addResult(ResultRecord(sourceItemIDs: [first.id], recipe: "总结文件", title: "没有产出.md", kind: .markdown, status: .failed, failureReason: "准备材料失败"))
            session.refresh()
            session.selectResult(failed.id)
            guard !session.canSendToTUI else { fail("failed result without file was sendable") }
            session.reselectResultSources(failed)
            guard session.paneFocus == .input, session.aiTab == .work, session.selectedItems.first?.id == first.id else { fail("failed result did not return to source") }
            try? session.shelf.patch(id: first.id) { $0.status = .sent }
            session.resetTUISession()
            session.shelf.setSelection([])
            session.toggleSelect(id: first.id, command: false)
            guard session.aiTab == .work else { fail("old sent input opened nonexistent terminal") }
            session.toggleSelect(id: first.id, command: false)
            guard session.selectedItems.isEmpty else { fail("clicking selected item did not deselect") }
            session.selectResult(r2.id)
            session.toggleResult(r2.id)
            guard session.selectedResultID == nil, session.paneFocus == .input else {
                fail("clicking selected result did not deselect")
            }
            session.selectResult(r2.id)
            session.selectResult(r2.id)
            guard session.selectedResultID == r2.id, session.paneFocus == .result else {
                fail("programmatic selectResult toggled off")
            }
            session.toggleResult(r2.id)
            session.shelf.setSelection([first.id])
            session.selectResult(r2.id)
            session.toggleSelect(id: first.id, command: false)
            guard session.selectedItems.map(\.id) == [first.id], session.paneFocus == .input else {
                fail("clicking file from result focus deselected")
            }
            session.chooseRecipe(.summarize)
            session.toggleSelect(id: second.id, command: false)
            session.chooseRecipe(.translate)
            guard session.shelf.item(id: first.id)?.status == .idle,
                  session.shelf.item(id: second.id)?.recipe == RecipeID.translate.fullTitle else {
                fail("new confirmation retained a conflicting draft")
            }
            session.cancelConfirm()
            guard session.items.first(where: { $0.id == second.id })?.status == .idle else {
                fail("cancel confirmation did not refresh immediately")
            }
            session.otherOpen = true
            session.promptText = "Keep this draft"
            session.presentJobResult(sourceIDs: [first.id])
            guard session.aiTab == .work, session.paneFocus == .input,
                  session.selectedItems.first?.id == second.id, session.promptText == "Keep this draft" else {
                fail("completed job interrupted another material or draft")
            }
            session.otherOpen = false
            session.promptText = ""
            session.toggleSelect(id: first.id, command: false)
            session.openTab(.work)
            session.presentJobResult(sourceIDs: [first.id])
            guard session.paneFocus == .result, session.selectedResultID != nil else {
                fail("completion did not reveal a result while following the job")
            }
            session.selectResult(r2.id)
            session.openTab(.work)
            guard session.paneFocus == .input else { fail("actions retained result focus") }
            session.shelf.setSelection([])
            session.openTab(.result)
            guard session.paneFocus == .result, session.selectedResultID != nil else {
                fail("preview with no input did not open a result")
            }
            session.selectResult(r2.id)
            session.hideResult(r2.id)
            guard session.selectedResultID != nil, session.paneFocus == .result else {
                fail("hiding current result abandoned remaining results")
            }
            try? session.shelf.patch(id: first.id) { $0.status = .running }
            session.toggleSelect(id: second.id, command: false)
            session.showRunningJob()
            guard session.selectedItems.map(\.id) == [first.id], session.aiTab == .work,
                  session.paneFocus == .input else { fail("running job shortcut lost its inputs") }
            try? session.shelf.patch(id: first.id) { $0.status = .idle }
            session.hideItem(first.id)
            session.hideItem(second.id)
            for id in [r1.id, r2.id, failed.id] { session.hideResult(id) }
            session.refreshPresence()
        }

        private func verifyIsolationFact() {
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .grok(path: path, isolation: .unknown)
            let unknown = session.recipeIsolationFact
            guard unknown.contains("未确认工作区限制") else {
                fail("unknown isolation fact \(unknown)")
            }
            guard unknown.contains("Safe Copy") == false else {
                fail("unknown isolation claimed Safe Copy")
            }
            session.recipePresence = .grok(path: path, isolation: .workspace)
            let workspace = session.recipeIsolationFact
            guard workspace.contains("Workspace Sandbox") else {
                fail("workspace isolation fact \(workspace)")
            }
            guard workspace.contains("完全看不到") == false else {
                fail("workspace overclaim")
            }
            session.recipePresence = .none
            guard session.recipeIsolationFact == "无执行入口" else {
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
                live.status = .idle
            }
            let shown = session.shelf.addResult(
                ResultRecord(
                    sourceItemIDs: [id],
                    recipe: RecipeID.summarize.fullTitle,
                    title: "summary.md",
                    kind: .markdown,
                    output: note,
                    isolationShown: .unconfirmed
                )
            )
            session.refresh()
            session.selectResult(shown.id)
            guard session.resultIsolationLine == IsolationShown.unconfirmed.spokenFact else {
                fail("unconfirmed result \(session.resultIsolationLine ?? "nil")")
            }
            guard session.resultIsolationLine?.contains("Safe Copy") == false else {
                fail("unconfirmed claimed Safe Copy")
            }
            session.shelf.patchResult(id: shown.id) { live in
                live.isolationShown = .workspace
            }
            session.refresh()
            session.selectResult(shown.id)
            guard session.resultIsolationLine == IsolationShown.workspace.spokenFact else {
                fail("workspace result \(session.resultIsolationLine ?? "nil")")
            }
            session.removeResult(shown.id)
            session.remove(id: id)
            session.aiTab = .work
        }

        private func verifyOpenItem() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("open-me.md")
            try? Data("# open\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let file = session.items.first(where: { $0.title == "open-me.md" }) else {
                fail("no open-me.md")
            }
            guard let fileURL = session.openURL(for: file), fileURL.isFileURL,
                  FileManager.default.fileExists(atPath: fileURL.path) else {
                fail("file open url missing")
            }
            let link = Item(
                kind: .url,
                title: "example.com",
                sourceURL: URL(string: "https://example.com/dropagent-open")!,
                parts: [ItemPart(name: "link.txt", url: fileURL)]
            )
            guard session.openURL(for: link)?.absoluteString == "https://example.com/dropagent-open" else {
                fail("url open \(session.openURL(for: link)?.absoluteString ?? "nil")")
            }
            let result = session.shelf.addResult(
                ResultRecord(
                    sourceItemIDs: [file.id],
                    recipe: "总结文件",
                    title: "open-out.md",
                    kind: .markdown,
                    output: note
                )
            )
            session.refresh()
            guard session.openURL(for: result.takeawayItem()) == note else {
                fail("result open url \(session.openURL(for: result.takeawayItem())?.path ?? "nil")")
            }
            let missing = ResultRecord(
                sourceItemIDs: [file.id],
                recipe: "总结文件",
                title: "gone.md",
                kind: .markdown,
                output: DropAgentPaths.inbox.appendingPathComponent("does-not-exist.md")
            )
            guard session.openURL(for: missing.takeawayItem()) == nil else {
                fail("missing result file was openable")
            }
            let bad = Item(
                kind: .url,
                title: "bad",
                sourceURL: URL(string: "javascript:alert(1)")!,
                parts: [ItemPart(name: "link.txt", url: note)]
            )
            guard session.openURL(for: bad) == nil else {
                fail("javascript url was openable")
            }
            session.removeResult(result.id)
            session.remove(id: file.id)
            session.aiTab = .work
            session.errorText = nil
        }

        private func verifyConfirmFacts() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("facts.md")
            try? Data("# facts\n".utf8).write(to: note)
            session.admit(urls: [note])
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .grok(path: path, isolation: .unknown)
            session.chooseRecipe(.summarize)
            guard session.recipeWriteFact == "未确认仅任务目录" else {
                fail("unknown write fact \(session.recipeWriteFact)")
            }
            guard session.recipeNetworkFact == "未确认" else {
                fail("unknown network fact \(session.recipeNetworkFact)")
            }
            session.cancelConfirm()
            session.recipePresence = .grok(path: path, isolation: .workspace)
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
            guard session.recipeWriteFact == "无执行入口", session.recipeNetworkFact == "无执行入口" else {
                fail("no recipe write/network \(session.recipeWriteFact) \(session.recipeNetworkFact)")
            }
            if let id = session.items.first(where: { $0.title == "facts.md" })?.id {
                session.remove(id: id)
            }
            session.refreshPresence()
        }

        private func verifyEmptyWorkHint() {
            let empty = HotKeyCopy.workIdleHint(
                hasAgent: true,
                hasRecipe: true,
                tuiTitle: "Grok",
                captureOK: true,
                hasItems: false
            )
            guard empty.contains("加入架子") else {
                fail("empty work hint \(empty)")
            }
            guard empty.contains("发给 Grok") else {
                fail("empty work hint missing send \(empty)")
            }
            guard empty.contains("点列表") == false else {
                fail("empty work hint still lists files \(empty)")
            }
            let listed = HotKeyCopy.workIdleHint(
                hasAgent: true,
                hasRecipe: true,
                tuiTitle: "Grok",
                captureOK: true,
                hasItems: true
            )
            guard listed.contains("点列表里的文件") else {
                fail("listed work hint \(listed)")
            }
        }

        private func verifyRecipeChooserHint() {
            try? DropAgentPaths.ensure()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .grok(path: path, isolation: .workspace)
            let zip = DropAgentPaths.inbox.appendingPathComponent("archive.zip")
            try? Data("PK".utf8).write(to: zip)
            session.admit(urls: [zip])
            let zipHint = session.recipeChooserHint
            guard zipHint.contains("这类文件不能总结或翻译") else {
                fail("zip recipe hint \(zipHint)")
            }
            guard zipHint.contains("整合") || zipHint.contains("Combine") else {
                fail("zip hint missing combine \(zipHint)")
            }
            guard zipHint.contains("或在下面写一句话") == false else {
                fail("zip hint still generic \(zipHint)")
            }
            let pdf = DropAgentPaths.inbox.appendingPathComponent("hint.pdf")
            try? Data("%PDF-1.4 hint\n".utf8).write(to: pdf)
            session.admit(urls: [pdf])
            let pdfHint = session.recipeChooserHint
            guard pdfHint.contains("点「其他」写一句话") else {
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
            session.recipePresence = .grok(path: path, isolation: .workspace)
            let png = DropAgentPaths.inbox.appendingPathComponent("shot.png")
            try? tinyPNG().write(to: png)
            session.admit(urls: [png])
            guard session.items.contains(where: { $0.kind == .image }) else {
                fail("no image item")
            }
            guard session.recipeFitsSelection(.summarize) else {
                fail("image summarize disabled")
            }
            guard session.recipeFitsSelection(.imageText) else {
                fail("image text disabled")
            }
            session.recipePresence = .none
            guard session.canRunRecipe(.imageText) else {
                fail("image text needs agent")
            }
            guard session.canRunRecipe(.summarize) == false else {
                fail("summarize without agent")
            }
            session.recipePresence = .grok(path: path, isolation: .workspace)
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

        private func verifyPdfRecipeGates() {
            try? DropAgentPaths.ensure()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.recipePresence = .grok(path: path, isolation: .workspace)
            let pdf = DropAgentPaths.inbox.appendingPathComponent("gate.pdf")
            try? pdfWithText("gate").write(to: pdf)
            session.admit(urls: [pdf])
            guard session.items.contains(where: { $0.kind == .pdf && $0.title == "gate.pdf" }) else {
                fail("no pdf item")
            }
            guard session.recipeFitsSelection(.pdfText) else {
                fail("pdf text disabled")
            }
            guard session.recipeFitsSelection(.imageText) == false else {
                fail("pdf opened image text")
            }
            session.recipePresence = .none
            guard session.canRunRecipe(.pdfText) else {
                fail("pdf text needs agent")
            }
            guard session.canRunRecipe(.summarize) == false else {
                fail("summarize without agent")
            }
            if let id = session.items.first(where: { $0.title == "gate.pdf" })?.id {
                session.remove(id: id)
            }
            session.refreshPresence()
        }

        private func verifyActionBar() async {
            try? DropAgentPaths.ensure()
            let path = URL(fileURLWithPath: "/usr/bin/true")
            session.presence = .grok(path: path, isolation: .workspace)
            session.recipePresence = .grok(path: path, isolation: .workspace)
            let pdf = DropAgentPaths.inbox.appendingPathComponent("报价.pdf")
            try? pdfWithText("pay").write(to: pdf)
            session.admit(urls: [pdf])
            await settle()
            session.hideSlot(.recipe(.redact))
            guard session.actionSlots.contains(.recipe(.redact)) == false else {
                fail("redact still on bar")
            }
            guard session.poolSlots.contains(.recipe(.redact)) else {
                fail("redact missing from pool")
            }
            let sizes: [String: CGFloat] = [
                RecipeID.summarize.rawValue: 80,
                RecipeID.extract.rawValue: 70,
                RecipeID.translate.rawValue: 90,
            ]
            let start = [RecipeID.summarize.rawValue, RecipeID.extract.rawValue, RecipeID.translate.rawValue]
            let insert = ActionBarReorder.insertIndex(
                dragging: RecipeID.summarize.rawValue,
                center: 200,
                order: start,
                sizes: sizes
            )
            let preview = ActionBarReorder.previewOrder(
                dragging: RecipeID.summarize.rawValue,
                insert: insert,
                order: start
            )
            guard preview == [RecipeID.extract.rawValue, RecipeID.translate.rawValue, RecipeID.summarize.rawValue] else {
                fail("live reorder preview \(preview)")
            }
            session.moveSlot(id: RecipeID.summarize.rawValue, to: RecipeID.translate.rawValue)
            let order = session.actionSlots.map(\.id)
            guard let translateAt = order.firstIndex(of: RecipeID.translate.rawValue),
                  order.indices.contains(translateAt + 1),
                  order[translateAt + 1] == RecipeID.summarize.rawValue
            else {
                fail("summarize did not drag after translate \(order)")
            }
            session.moveSlot(id: RecipeID.summarize.rawValue, to: RecipeID.extract.rawValue)
            guard session.actionSlots.map(\.id).first == RecipeID.summarize.rawValue else {
                fail("summarize did not drag back to front \(session.actionSlots.map(\.id))")
            }
            session.shortcutDraft = ShortcutDraft(
                id: nil,
                name: "抽付款日",
                kinds: [.pdf],
                prompt: "抽出付款节点"
            )
            session.saveShortcutDraft()
            guard let action = session.prefs.shortcuts.first(where: { $0.name == "抽付款日" }) else {
                fail("shortcut not saved")
            }
            guard session.actionSlots.contains(.shortcut(action.id)) == false else {
                fail("shortcut auto-added to bar")
            }
            guard session.poolSlots.contains(.shortcut(action.id)) else {
                fail("shortcut missing from pool")
            }
            guard session.shortcutPoolNotice?.id == action.id else {
                fail("pool notice missing")
            }
            session.pinPooledShortcutToBar()
            guard session.barSlots(organizing: false).contains(.shortcut(action.id)) else {
                fail("shortcut missing on pdf bar \(session.barSlots(organizing: false).map(\.id))")
            }
            guard session.shortcutPoolNotice == nil else {
                fail("pool notice stayed")
            }
            session.chooseShortcut(id: action.id)
            guard session.canConfirmRun else {
                fail("shortcut confirm blocked")
            }
            await session.confirmRun()
            await settle()
            guard let result = session.results.first(where: { $0.title == "报价-抽付款日.md" }) else {
                fail("shortcut result \(session.results.map(\.title))")
            }
            guard result.recipe == "抽付款日" else {
                fail("shortcut recipe \(result.recipe)")
            }
            session.removeResult(result.id)
            if let pdfID = session.items.first(where: { $0.title == "报价.pdf" })?.id {
                session.remove(id: pdfID)
            }
            let png = DropAgentPaths.inbox.appendingPathComponent("bar.png")
            try? tinyPNG().write(to: png)
            session.admit(urls: [png])
            await settle()
            guard session.barSlots(organizing: false).contains(.shortcut(action.id)) == false else {
                fail("pdf shortcut shown for image")
            }
            if let pngID = session.items.first(where: { $0.title == "bar.png" })?.id {
                session.remove(id: pngID)
            }
            session.deleteShortcut(id: action.id)
            session.showSlot(.recipe(.redact))
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
            session.recipePresence = .grok(path: path, isolation: .workspace)
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
                fail("retry promised without job \(session.failedRetryLine ?? "")")
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
            session.recipePresence = .grok(path: path, isolation: .workspace)
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
                fail("retry without job \(String(describing: session.failedOutputRetryRecipe))")
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
            guard session.doneActionHint.contains("点下面结果区拿走") else {
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
                fail("recipe enabled without chip")
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
            session.recipePresence = .none
            await settle()
            guard session.canSendToTUI else {
                fail("send disabled with TUI")
            }
            guard session.hasRecipe == false else {
                fail("recipe enabled TUI-only")
            }
            guard session.recipeChooserHint.contains("没有无界面执行入口") else {
                fail("tui-only hint \(session.recipeChooserHint)")
            }
            guard session.recipeChooserHint.contains("Grok") else {
                fail("tui-only hint missing Grok \(session.recipeChooserHint)")
            }
            session.chooseRecipe(.summarize)
            await session.confirmRun()
            await settle()
            guard session.items.first(where: { $0.id == item.id })?.status == .confirm else {
                fail("confirmRun without job \(session.items.first(where: { $0.id == item.id })?.status.rawValue ?? "gone")")
            }
            guard session.items.contains(where: { $0.title == "summary.md" }) == false else {
                fail("stub job ran without job gate")
            }
            guard session.errorText == "Grok 没有无界面执行入口。终端仍可发送给 Grok。" else {
                fail("tui-only confirm \(session.errorText ?? "nil")")
            }
            snapshot("e2e-tui-only")
            session.cancelConfirm()
            session.dismissError()
            session.presence = .none
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            await settle()
            guard session.hasRecipe == false else {
                fail("recipe on without chip")
            }
            guard session.canSendToTUI == false else {
                fail("send enabled without TUI")
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
            session.recipePresence = .grok(path: path, isolation: .workspace)
            session.chooseRecipe(.summarize)
            await session.confirmRun()
            await settle()
            guard let source = session.items.first(where: { $0.title == "recipe-source.pdf" }) else {
                fail(session.errorText ?? "recipe source missing")
            }
            guard source.status == .idle else {
                fail("recipe status \(source.status)")
            }
            guard session.isDoneTakeaway == false else {
                fail("recipe input treated as takeaway")
            }
            guard let result = session.results.first(where: { $0.title == "summary.md" }), result.output != nil else {
                fail("recipe missing result \(session.results.map(\.title))")
            }
            guard session.paneFocus == .result, session.selectedResultID == result.id else {
                fail("recipe did not auto-open result focus=\(session.paneFocus) selected=\(String(describing: session.selectedResultID))")
            }
            guard session.stagedItem?.title == "summary.md" else {
                fail("recipe staged \(session.stagedItem?.title ?? "nil")")
            }
            guard hash(pdf) == before else {
                fail("recipe changed original")
            }
            session.selectResult(result.id)
            await settle()
            snapshot("e2e-recipe-result")
            do {
                let landed = try await land(result.takeawayItem())
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
            session.toggleSelect(id: source.id, command: false)
            session.chooseRecipe(.summarize)
            guard session.items.first(where: { $0.id == source.id })?.status == .confirm else {
                let status = session.items.first(where: { $0.id == source.id }).map { String(describing: $0.status) } ?? "missing"
                fail("could not run again on input status=\(status) selected=\(session.selectedItems.map(\.title)) error=\(session.errorText ?? "nil")")
            }
            session.cancelConfirm()
            session.removeResult(result.id)
            session.remove(id: source.id)
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
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            session.chooseRecipe(.extract)
            await session.confirmRun()
            await settle()
            guard let source = session.items.first(where: { $0.title == "extract-source.pdf" }) else {
                fail(session.errorText ?? "extract source missing")
            }
            guard source.status == .idle else {
                fail("extract status \(source.status)")
            }
            guard let result = session.results.first(where: { $0.title == "extracted.json" }) else {
                fail("extract missing result")
            }
            guard hash(pdf) == before else {
                fail("extract changed original")
            }
            session.selectResult(result.id)
            await settle()
            snapshot("e2e-extract-result")
            do {
                let landed = try await land(result.takeawayItem())
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
            session.removeResult(result.id)
            session.remove(id: source.id)
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyImageTextLoop() async {
            try? DropAgentPaths.ensure()
            let png = DropAgentPaths.inbox.appendingPathComponent("ocr-source.png")
            let marker = "DROPAGENT-OCR-OK"
            try? pngWithText(marker).write(to: png)
            let before = hash(png)
            session.admit(urls: [png])
            await settle()
            session.presence = .none
            session.recipePresence = .none
            guard session.canRunRecipe(.imageText) else {
                fail("ocr blocked without agent")
            }
            session.chooseRecipe(.imageText)
            guard session.recipeWriteFact == "仅任务目录" else {
                fail("ocr write fact \(session.recipeWriteFact)")
            }
            guard session.recipeNetworkFact == "关" else {
                fail("ocr network \(session.recipeNetworkFact)")
            }
            guard session.recipeIsolationFact.contains("本机识别") else {
                fail("ocr isolation \(session.recipeIsolationFact)")
            }
            await session.confirmRun()
            await settle()
            guard let source = session.items.first(where: { $0.title == "ocr-source.png" }) else {
                fail(session.errorText ?? "ocr source missing")
            }
            guard source.status == .idle else {
                fail("ocr status \(source.status) \(session.errorText ?? "")")
            }
            guard let result = session.results.first(where: { $0.title == "ocr.md" }), result.output != nil else {
                fail("ocr missing result \(session.results.map(\.title)) \(session.errorText ?? "")")
            }
            guard hash(png) == before else {
                fail("ocr changed original")
            }
            let body = (try? String(contentsOf: result.output!, encoding: .utf8)) ?? ""
            guard body.contains(marker) else {
                fail("ocr body \(body)")
            }
            session.selectResult(result.id)
            await settle()
            snapshot("e2e-ocr-result")
            do {
                let landed = try await land(result.takeawayItem())
                guard landed.lastPathComponent == "ocr.md" else {
                    fail("ocr landed \(landed.lastPathComponent)")
                }
            } catch {
                fail("ocr drag land \(error)")
            }
            session.removeResult(result.id)
            session.remove(id: source.id)
            session.aiTab = .work
            session.refreshPresence()
        }

        private func verifyPdfTextLoop() async {
            try? DropAgentPaths.ensure()
            let pdf = DropAgentPaths.inbox.appendingPathComponent("pdf-source.pdf")
            let marker = "DROPAGENT-PDF-OK"
            try? pdfWithText(marker).write(to: pdf)
            let before = hash(pdf)
            session.admit(urls: [pdf])
            await settle()
            session.presence = .none
            session.recipePresence = .none
            guard session.canRunRecipe(.pdfText) else {
                fail("pdf extract blocked without agent")
            }
            session.chooseRecipe(.pdfText)
            guard session.recipeWriteFact == "仅任务目录" else {
                fail("pdf write fact \(session.recipeWriteFact)")
            }
            guard session.recipeNetworkFact == "关" else {
                fail("pdf network \(session.recipeNetworkFact)")
            }
            guard session.recipeIsolationFact.contains("本机提取") else {
                fail("pdf isolation \(session.recipeIsolationFact)")
            }
            await session.confirmRun()
            await settle()
            guard let source = session.items.first(where: { $0.title == "pdf-source.pdf" }) else {
                fail(session.errorText ?? "pdf source missing")
            }
            guard source.status == .idle else {
                fail("pdf status \(source.status) \(session.errorText ?? "")")
            }
            guard let result = session.results.first(where: { $0.title == "pdf.md" }), result.output != nil else {
                fail("pdf missing result \(session.results.map(\.title)) \(session.errorText ?? "")")
            }
            guard hash(pdf) == before else {
                fail("pdf extract changed original")
            }
            let body = (try? String(contentsOf: result.output!, encoding: .utf8)) ?? ""
            guard body.contains(marker) else {
                fail("pdf body \(body)")
            }
            session.selectResult(result.id)
            await settle()
            snapshot("e2e-pdf-result")
            do {
                let landed = try await land(result.takeawayItem())
                guard landed.lastPathComponent == "pdf.md" else {
                    fail("pdf landed \(landed.lastPathComponent)")
                }
            } catch {
                fail("pdf drag land \(error)")
            }
            session.removeResult(result.id)
            session.remove(id: source.id)
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
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
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
            let kept = session.items.filter { $0.title == "brief-a.md" || $0.title == "brief-b.md" }
            guard kept.count == 2, kept.allSatisfy({ $0.status == .idle }) else {
                fail(session.errorText ?? "brief did not keep inputs \(session.items.map { "\($0.title):\($0.status.rawValue)" })")
            }
            guard let result = session.results.first(where: { $0.title == "brief.md" }) else {
                fail("brief missing result")
            }
            guard hash(first) == beforeA, hash(second) == beforeB else {
                fail("brief changed originals")
            }
            session.selectResult(result.id)
            await settle()
            snapshot("e2e-brief-result")
            do {
                let landed = try await land(result.takeawayItem())
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
            session.removeResult(result.id)
            for item in kept {
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
            session.settingsOpen = false
            session.paneFocus = .input
            session.shelf.setSelection([item.id])
            session.refresh()
            await settle()
            let copyRoot = item.parts.first?.url ?? item.sourceURL
            let listed = FolderListing.children(of: copyRoot, stayingInside: copyRoot).map(\.name)
            guard listed.contains("notes.md") else {
                fail("folder listing \(listed) root=\(copyRoot.path)")
            }
            hosting?.layoutSubtreeIfNeeded()
            window?.displayIfNeeded()
            guard let host = hosting else {
                fail("no host")
                return
            }
            guard viewContains(host, needle: "content-stage") else {
                fail("folder content stage missing")
            }
            guard viewContains(host, needle: "folder-tree") else {
                fail("folder tree missing")
            }
            guard viewContains(host, needle: "notes.md") else {
                fail("folder tree missing notes.md")
            }
            guard viewContains(host, needle: "folder-notes") else {
                fail("folder preview missing body")
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
            guard let clip = session.items.first(where: { $0.kind == .clip && $0.title == "e2e-clip-body" }) else {
                fail("clip admit missing")
            }
            guard ItemPeek.clipLines(for: clip)?.title == "e2e-clip-body" else {
                fail("clip card title \(ItemPeek.clipLines(for: clip)?.title ?? "nil")")
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
            guard var page = session.items.first(where: {
                $0.kind == .web && $0.sourceURL.absoluteString.hasPrefix("https://example.com/e2e-url")
            }) else {
                fail("url admit missing")
            }
            for _ in 0..<80 {
                if page.event != IngestService.pageCapturePendingEvent { break }
                await settle()
                page = session.items.first(where: { $0.id == page.id }) ?? page
            }
            session.aiTab = .result
            await settle()
            snapshot("e2e-url")
            let urlCopy = NSPasteboard.withUniqueName()
            session.copyItem(page, to: urlCopy)
            let urlFiles = urlCopy.readObjects(forClasses: [NSURL.self], options: [
                .urlReadingFileURLsOnly: true
            ]) as? [URL] ?? []
            guard urlFiles.isEmpty == false else {
                fail("web copy has no folder")
            }
            guard page.parts.contains(where: { $0.name == "url.txt" }) else {
                fail("web url.txt missing")
            }
            session.remove(id: page.id)
            session.aiTab = .work
        }

        private func verifyClipHistory() async {
            let one = NSPasteboard.withUniqueName()
            one.clearContents()
            guard one.setString("history-one", forType: .string) else {
                fail("history one pasteboard")
            }
            session.notePasteboard(one)
            guard let first = session.clipRecords.first, first.text == "history-one" else {
                fail("history did not record text \(session.clipRecords.first?.text ?? "nil")")
            }
            guard session.currentClipFingerprint == first.fingerprint else {
                fail("current fingerprint not on latest clip")
            }

            let two = NSPasteboard.withUniqueName()
            two.clearContents()
            guard two.setString("history-two", forType: .string) else {
                fail("history two pasteboard")
            }
            session.notePasteboard(two)
            guard session.clipRecords.count >= 2 else {
                fail("history count \(session.clipRecords.count)")
            }
            guard session.clipRecords[0].text == "history-two" else {
                fail("latest clip \(session.clipRecords[0].text ?? "nil")")
            }

            let older = session.clipRecords[1]
            guard session.currentClipFingerprint == session.clipRecords[0].fingerprint else {
                fail("current marker should stay on the latest clipboard")
            }
            let button = CGRect(x: 900, y: 700, width: 22, height: 22)
            let placed = ClipHistoryWindow.frame(
                anchor: button,
                size: CGSize(width: 280, height: 180),
                screen: CGRect(x: 0, y: 0, width: 1440, height: 900)
            )
            guard abs(placed.maxX - button.maxX) < 0.5 else {
                fail("clip menu should align to the button \(placed)")
            }
            guard abs(placed.maxY - (button.minY - 4)) < 0.5 else {
                fail("clip menu should sit below the button \(placed)")
            }

            let beforeItems = session.items.count
            session.toggleClipSelect(id: older.id, command: false)
            guard session.clipSelection == [older.id] else {
                fail("clip select \(session.clipSelection)")
            }
            session.toggleClipSelect(id: older.id, command: false)
            guard session.clipSelection.isEmpty else {
                fail("clip deselect")
            }
            session.toggleClipSelect(id: older.id, command: false)
            session.toggleClipSelect(id: session.clipRecords[0].id, command: true)
            guard session.clipSelection.count == 2 else {
                fail("clip command multi \(session.clipSelection.count)")
            }
            let switchBoard = NSPasteboard.withUniqueName()
            session.makeClipCurrent(older.id, on: switchBoard)
            guard switchBoard.string(forType: .string) == "history-one" else {
                fail("make current did not copy \(switchBoard.string(forType: .string) ?? "nil")")
            }
            guard session.currentClipFingerprint == older.fingerprint else {
                fail("double-click did not switch current")
            }
            await settle()
            guard session.items.count == beforeItems else {
                fail("selecting a clip admitted it")
            }
            let dragged = session.clipDragGroup(starting: older.id)
            guard dragged.count == 2 else {
                fail("clip drag group \(dragged.count)")
            }

            session.notePasteboard(one)
            guard session.clipRecords[0].text == "history-one" else {
                fail("duplicate did not bump \(session.clipRecords[0].text ?? "nil")")
            }
            let beforeDelete = session.clipRecords.count
            session.deleteClip(session.clipRecords[0].id)
            guard session.clipRecords.count == beforeDelete - 1 else {
                fail("delete clip \(session.clipRecords.count)")
            }

            let hidden = NSPasteboard.withUniqueName()
            hidden.clearContents()
            hidden.setString("password", forType: .string)
            hidden.setString("1", forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            let beforeHidden = session.clipRecords.count
            session.notePasteboard(hidden)
            guard session.clipRecords.count == beforeHidden else {
                fail("concealed clip was stored")
            }

            if let gone = ClipDraft(kind: .files, title: "gone", filePaths: ["/tmp/dropagent-e2e-missing.pdf"]) {
                let missing = session.clipHistory.record(gone)
                session.refreshClips()
                guard session.clipDragGroup(starting: missing.id).isEmpty else {
                    fail("missing file should not drag")
                }
                session.deleteClip(missing.id)
            } else {
                fail("missing file draft")
            }

            for item in session.items {
                let body = item.parts.first.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) } ?? ""
                if body.contains("history-one") {
                    session.remove(id: item.id)
                }
            }
            session.errorText = nil
        }

        private func verifyCopyFilesToShelf() async {
            let source = DropAgentPaths.root.appendingPathComponent("copy-stage-source.txt")
            do {
                try Data("copy-stage-body\n".utf8).write(to: source)
            } catch {
                fail("copy-stage source \(error)")
            }
            let original = (try? Data(contentsOf: source)) ?? Data()
            let board = NSPasteboard.withUniqueName()
            board.clearContents()
            guard board.writeObjects([source as NSURL]) else {
                fail("copy-stage pasteboard")
            }
            let beforeClips = session.clipRecords.count
            let beforeItems = session.items.count
            session.notePasteboard(board)
            await settle()
            guard session.items.count == beforeItems + 1 else {
                fail("copy files did not stage \(session.items.count)")
            }
            guard let item = session.items.first(where: { $0.title == "copy-stage-source.txt" }) else {
                fail("copy-stage item missing")
            }
            let copyURL = item.parts.first?.url
            let body = copyURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            guard body.contains("copy-stage-body") else {
                fail("copy-stage body \(body)")
            }
            guard (try? Data(contentsOf: source)) == original else {
                fail("copy-stage original changed")
            }
            guard session.clipRecords.count == beforeClips else {
                fail("file copy went to clip history \(session.clipRecords.count)")
            }
            guard session.selectedItems.map(\.id) == [item.id] else {
                fail("copy-stage not selected \(session.selectedItems.map(\.id))")
            }

            let ownedBoard = NSPasteboard.withUniqueName()
            ownedBoard.clearContents()
            if let copyURL {
                guard ownedBoard.writeObjects([copyURL as NSURL]) else {
                    fail("owned copy pasteboard")
                }
            } else {
                fail("copy-stage part missing")
            }
            session.notePasteboard(ownedBoard)
            await settle()
            guard session.items.filter({ $0.title == "copy-stage-source.txt" }).count == 1 else {
                fail("owned copy re-admitted")
            }

            guard let fileClip = ClipDraft(kind: .files, title: "stage-hist", filePaths: [source.path]) else {
                fail("file clip draft")
            }
            let recorded = session.clipHistory.record(fileClip)
            session.refreshClips()
            let beforeMake = session.items.count
            let currentBoard = NSPasteboard.withUniqueName()
            session.makeClipCurrent(recorded.id, on: currentBoard)
            await settle()
            guard session.items.count == beforeMake else {
                fail("make current admitted files")
            }
            session.deleteClip(recorded.id)

            session.remove(id: item.id)
            try? FileManager.default.removeItem(at: source)
            session.errorText = nil
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

        private func pdfWithText(_ text: String) -> Data {
            let data = NSMutableData()
            var box = CGRect(x: 0, y: 0, width: 612, height: 792)
            guard let consumer = CGDataConsumer(data: data as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &box, nil)
            else {
                fail("text pdf")
            }
            ctx.beginPDFPage(nil)
            let drawn = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold),
                    .foregroundColor: NSColor.black,
                ]
            )
            ctx.textPosition = CGPoint(x: 72, y: 720)
            CTLineDraw(CTLineCreateWithAttributedString(drawn), ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            return data as Data
        }

        private func pngWithText(_ text: String) -> Data {
            let image = NSImage(size: NSSize(width: 920, height: 240), flipped: false) { rect in
                NSColor.white.setFill()
                rect.fill()
                let drawn = NSAttributedString(
                    string: text,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 42, weight: .bold),
                        .foregroundColor: NSColor.black,
                    ]
                )
                let size = drawn.size()
                drawn.draw(at: NSPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2))
                return true
            }
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:])
            else {
                fail("text png")
            }
            return png
        }

        private func verifyCaptureLoop() async {
            let beforeWeb = session.items.filter { $0.kind == .web }.count
            await session.captureCurrentPage(token: .none)
            showPanelWindow()
            await settle()
            guard session.items.filter({ $0.kind == .web }).count == beforeWeb else {
                fail("capture invented web item")
            }
            guard session.errorText == PageAdmitCopy.noBrowserHotKey else {
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
            guard item.title.localizedStandardContains("Example") else {
                fail("web title \(item.title)")
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
                guard landed.lastPathComponent.localizedStandardContains("Example") else {
                    fail("web folder not Example \(landed.lastPathComponent)")
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
                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() == "com.apple.safari" {
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
            guard ResultMarkdown.blocks("3. Read\n4. Review") == [.orderedItem("3.", "Read"), .orderedItem("4.", "Review")] else {
                fail("ordered list lost its sequence in preview")
            }
            guard ResultMarkdown.blocks("#hashtag") == [.paragraph("#hashtag")] else {
                fail("hashtag became a heading")
            }
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
            guard blocks[0] == .heading(1, "Keep") else {
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
            let sub = ResultMarkdown.blocks("## Sub")
            guard sub == [.heading(2, "Sub")] else {
                fail("result markdown h2 \(sub)")
            }
            let table = ResultMarkdown.blocks("| A | B |\n| --- | --- |\n| 1 | 2 |")
            guard table == [.table(header: ["A", "B"], rows: [["1", "2"]])] else {
                fail("result markdown table \(table)")
            }
            let titled = ResultMarkdown.blocks("![示意图](<https://example.com/fig.png> \"og\")")
            guard titled == [.image(alt: "示意图", url: "https://example.com/fig.png")] else {
                fail("result markdown titled image \(titled)")
            }
            let quote = ResultMarkdown.blocks("> Note")
            guard quote == [.quote("Note")] else {
                fail("result markdown quote \(quote)")
            }
            let image = ResultMarkdown.blocks("![示意图](https://example.com/fig.png)")
            guard image == [.image(alt: "示意图", url: "https://example.com/fig.png")] else {
                fail("result markdown image \(image)")
            }
            verifyMarkdownImageBounds()
        }

        private func verifyContentStage() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("stage-me.md")
            try? Data("# Stage\n\nFull body for the content stage.\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let item = session.items.first(where: { $0.title == "stage-me.md" }) else {
                fail("no stage-me.md")
            }
            guard session.stagedItem?.id == item.id else {
                fail("stage empty after admit \(session.stagedItem?.title ?? "nil")")
            }
            session.toggleSelect(id: item.id, command: false)
            guard session.stagedItem == nil else {
                fail("stage still open after deselect")
            }
            session.toggleSelect(id: item.id, command: false)
            guard session.stagedItem?.id == item.id else {
                fail("stage empty after select")
            }
            session.remove(id: item.id)

            let source = FileManager.default.temporaryDirectory.appendingPathComponent("edit-me.md")
            try? Data("hello original\n".utf8).write(to: source)
            session.admit(urls: [source])
            guard let editable = session.items.first(where: { $0.title == "edit-me.md" }) else {
                fail("no edit-me.md")
            }
            guard let copy = StageEdit.editableURL(
                editable,
                inboxRoot: DropAgentPaths.inbox,
                jobsRoot: DropAgentPaths.jobs
            ) else {
                fail("edit-me.md not editable")
            }
            do {
                try StageEdit.write("hello edited\n", to: copy, inboxRoot: DropAgentPaths.inbox, jobsRoot: DropAgentPaths.jobs)
            } catch {
                fail("write copy \(error)")
            }
            session.flushStageEdit()
            guard (try? String(contentsOf: source, encoding: .utf8)) == "hello original\n" else {
                fail("original overwritten")
            }
            guard (try? String(contentsOf: copy, encoding: .utf8)) == "hello edited\n" else {
                fail("copy not written")
            }
            hosting?.layoutSubtreeIfNeeded()
            window?.displayIfNeeded()
            guard let host = hosting else {
                fail("no host")
                return
            }
            guard viewContains(host, needle: "content-stage-editor") == false else {
                fail("editor shown before click")
            }
            session.beginStageEdit()
            hosting?.layoutSubtreeIfNeeded()
            window?.displayIfNeeded()
            guard viewContains(host, needle: "content-stage-editor") else {
                fail("editor missing after click")
            }
            session.stopStageEdit()
            hosting?.layoutSubtreeIfNeeded()
            window?.displayIfNeeded()
            guard viewContains(host, needle: "content-stage-editor") == false else {
                fail("editor stayed after leaving edit")
            }

            let picture = DropAgentPaths.inbox.appendingPathComponent("stage-pic.png")
            try? Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: picture)
            session.admit(urls: [picture])
            guard let image = session.items.first(where: { $0.title == "stage-pic.png" }) else {
                fail("no stage-pic.png")
            }
            guard StageEdit.editableURL(image, inboxRoot: DropAgentPaths.inbox, jobsRoot: DropAgentPaths.jobs) == nil else {
                fail("image should stay read-only")
            }
            session.remove(id: editable.id)
            session.remove(id: image.id)
        }

        private func verifyFileKindGlyph() {
            guard FileKindGlyph.symbol(kind: .pdf, tag: "PDF") == "doc.richtext" else {
                fail("pdf glyph")
            }
            guard FileKindGlyph.symbol(kind: .url, tag: "URL") == "link" else {
                fail("url glyph")
            }
            guard FileKindGlyph.symbol(kind: .web, tag: "WEB") == "globe" else {
                fail("web glyph")
            }
            guard FileKindGlyph.symbol(kind: .clip, tag: "CLIP") == "doc.on.clipboard" else {
                fail("clip glyph")
            }
            guard FileKindGlyph.symbol(kind: .folder, tag: "DIR") == "folder.fill" else {
                fail("folder glyph")
            }
            guard FileKindGlyph.symbol(kind: .file, tag: "ZIP") == "archivebox" else {
                fail("zip glyph")
            }
            guard FileKindGlyph.symbol(kind: .markdown, tag: "JSON") == "curlybraces" else {
                fail("json glyph")
            }
            guard FileKindGlyph.symbol(kind: .image, tag: "PNG") == "photo" else {
                fail("image glyph")
            }
        }

        private func verifyTtyTheme() {
            session.setAppearance(.light)
            let light = Palette.ttyWellNS.usingColorSpace(.genericRGB)
            guard let light, light.redComponent > 0.9 else {
                fail("light tty well \(light?.redComponent ?? -1)")
            }
            guard Palette.ttyIdleFill.contains("#f8f7f4") else {
                fail("light tty fill \(Palette.ttyIdleFill)")
            }
            session.setAppearance(.dark)
            let dark = Palette.ttyWellNS.usingColorSpace(.genericRGB)
            guard let dark, dark.redComponent < 0.15 else {
                fail("dark tty well \(dark?.redComponent ?? -1)")
            }
            guard Palette.ttyIdleFill.contains("#222329") else {
                fail("dark tty fill \(Palette.ttyIdleFill)")
            }
            session.setAppearance(.light)
        }

        private func verifyMarkdownImageBounds() {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let inside = root.appendingPathComponent("fig.png")
            try? Data([0x89, 0x50, 0x4E, 0x47]).write(to: inside)
            let expected = inside.resolvingSymlinksInPath().standardizedFileURL
            guard MarkdownImage.localFile(url: "fig.png", baseDirectory: root) == expected else {
                fail("markdown image relative \(String(describing: MarkdownImage.localFile(url: "fig.png", baseDirectory: root)))")
            }
            guard MarkdownImage.localFile(url: "javascript:alert(1)", baseDirectory: root) == nil else {
                fail("markdown image javascript")
            }
            guard MarkdownImage.localFile(url: "data:image/png,xx", baseDirectory: root) == nil else {
                fail("markdown image data")
            }
            guard MarkdownImage.localFile(url: "https://example.com/fig.png", baseDirectory: root) == nil else {
                fail("markdown image remote as local")
            }
            guard MarkdownImage.localFile(url: "../secret.png", baseDirectory: root) == nil else {
                fail("markdown image escape")
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
            let bitmaps = image.representations.compactMap { $0 as? NSBitmapImageRep }
            let scales = Set(bitmaps.map { Int((CGFloat($0.pixelsWide) / max(image.size.width, 1)).rounded()) })
            guard scales.contains(1), scales.contains(2) else {
                fail("status icon scales \(scales)")
            }
            guard let retina = bitmaps.first(where: { $0.pixelsWide == 36 }),
                  let pixels = retina.bitmapData
            else {
                fail("status icon missing 2x bitmap")
            }
            let stride = retina.bytesPerRow
            func alpha(x: Int, y: Int) -> CGFloat {
                CGFloat(pixels[y * stride + x * 4 + 3]) / 255
            }
            guard alpha(x: 18, y: 4) < 0.1 else {
                fail("status icon top should be empty, got \(alpha(x: 18, y: 4))")
            }
            guard alpha(x: 18, y: 16) > 0.8 else {
                fail("status icon hopper should be filled, got \(alpha(x: 18, y: 16))")
            }
            guard alpha(x: 18, y: 30) > 0.8 else {
                fail("status icon shelf should be filled, got \(alpha(x: 18, y: 30))")
            }
        }

        private func verifyFrontFileHotKey() {
            guard session.prefs.filesHotKey == .filesDefault else {
                fail("files hotkey default")
            }
            session.setHotKey(.files, HotKeyChord(keyCode: 3, carbonModifiers: 4096 + 2048))
            guard session.prefs.filesHotKey.keyCode == 3 else {
                fail("set files hotkey")
            }
            session.resetHotKey(.files)
            guard session.prefs.filesHotKey == .filesDefault else {
                fail("reset files hotkey")
            }
        }

        private func verifyPanelSettings() async {
            session.setAppearance(.dark)
            guard Palette.isDark else { fail("settings dark") }
            session.setLanguage(.en)
            guard Copy.t("设置", "Settings") == "Settings" else { fail("settings english") }
            session.settingsOpen = true
            session.settingsSection = .actions
            await settle()
            guard settingsShows("settings-action-pool") else {
                fail("action pool missing \(settingsTree())")
            }
            guard settingsShows("settings-action-bar") else {
                fail("action bar column missing \(settingsTree())")
            }
            session.settingsSection = .shortcuts
            await settle()
            snapshot("e2e-settings")
            guard settingsShows("Show / Hide Panel") else {
                fail("settings shortcut rows missing \(settingsTree())")
            }
            guard settingsShows("Add Selected Files") else {
                fail("settings files shortcut missing \(settingsTree())")
            }
            session.settingsSection = .guide
            await settle()
            guard settingsShows("How It Works") else {
                fail("settings guide title not english \(settingsTree())")
            }
            guard settingsShows("Drop onto the menu bar icon") else {
                fail("settings guide body not english \(settingsTree())")
            }
            guard settingsShows("Copying local files adds them to the shelf") else {
                fail("settings english copy-files guide \(settingsTree())")
            }
            guard settingsShows("Actions use job copies"),
                  settingsShows("Actions do not overwrite originals"),
                  settingsShows("not restricted to the copy sandbox"),
                  settingsShows("copies remain in DropAgent")
            else {
                fail("settings english guide \(SettingsGuideCopy.dropIn)")
            }
            session.settingsSection = .appearance
            await settle()
            guard settingsShows("Show drop wheel") else {
                fail("settings appearance missing wheel \(settingsTree())")
            }
            guard settingsShows("settings-show-work") == false else {
                fail("settings still has work pane toggle")
            }
            guard settingsShows("settings-show-result") == false else {
                fail("settings still has result pane toggle")
            }
            session.setLanguage(.zh)
            session.settingsSection = .guide
            await settle()
            guard settingsShows("能做什么") else {
                fail("settings guide title not chinese \(settingsTree())")
            }
            guard settingsShows("轮盘") else {
                fail("settings guide body not chinese \(settingsTree())")
            }
            guard settingsShows("复制本地文件会直接加入架子") else {
                fail("settings chinese copy-files guide \(settingsTree())")
            }
            guard settingsShows("动作使用任务副本"),
                  settingsShows("快捷动作不覆盖原文件"),
                  settingsShows("不受副本沙箱限制"),
                  settingsShows("DropAgent 中的副本会保留")
            else {
                fail("settings chinese guide \(SettingsGuideCopy.dropIn)")
            }
            guard session.prefs.toggleHotKey == .toggleDefault else {
                fail("default toggle hotkey")
            }
            var applied = false
            session.onApplyHotKeys = { applied = true }
            session.setHotKey(.toggle, HotKeyChord(keyCode: 14, carbonModifiers: 4096 + 2048))
            guard applied else { fail("hotkeys not reapplied") }
            guard session.prefs.toggleHotKey.keyCode == 14 else {
                fail("set toggle hotkey")
            }
            session.setHotKey(.toggle, HotKeyChord(keyCode: 2, carbonModifiers: 0))
            guard session.prefs.toggleHotKey.keyCode == 14 else {
                fail("bare global hotkey accepted")
            }
            guard let bare = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "d",
                charactersIgnoringModifiers: "d",
                isARepeat: false,
                keyCode: 2
            ) else {
                fail("bare key event")
            }
            session.beginRecording(.toggle)
            session.applyRecordedHotKey(from: bare)
            guard session.recordingHotKey == .toggle else {
                fail("bare recording should stay")
            }
            guard session.prefs.toggleHotKey.keyCode == 14 else {
                fail("bare recording applied")
            }
            guard let chordEvent = NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.control, .option],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "e",
                charactersIgnoringModifiers: "e",
                isARepeat: false,
                keyCode: 14
            ) else {
                fail("chord key event")
            }
            session.applyRecordedHotKey(from: chordEvent)
            guard session.recordingHotKey == nil else {
                fail("recording not cleared")
            }
            guard session.prefs.toggleHotKey.keyCode == 14 else {
                fail("recorded toggle hotkey")
            }
            session.resetHotKey(.toggle)
            guard session.prefs.toggleHotKey == .toggleDefault else {
                fail("reset toggle hotkey")
            }
            session.setHotKey(.files, HotKeyChord(keyCode: 3, carbonModifiers: 4096 + 2048))
            guard session.prefs.filesHotKey.keyCode == 3 else {
                fail("set files hotkey")
            }
            session.resetHotKey(.files)
            guard session.prefs.filesHotKey == .filesDefault else {
                fail("reset files hotkey")
            }
            session.onApplyHotKeys = nil
            let custom = DropAgentPaths.root.appendingPathComponent("CustomInbox", isDirectory: true)
            session.setWorkspaceFolder(.inbox, url: custom)
            guard DropAgentPaths.inbox.standardizedFileURL.path == custom.standardizedFileURL.path else {
                fail("settings inbox \(DropAgentPaths.inbox.path)")
            }
            session.setWorkspaceFolder(.inbox, url: nil)
            guard DropAgentPaths.inbox.lastPathComponent == "Inbox" else {
                fail("settings inbox reset \(DropAgentPaths.inbox.path)")
            }
            let customJobs = DropAgentPaths.root.appendingPathComponent("CustomJobs", isDirectory: true)
            session.setWorkspaceFolder(.jobs, url: customJobs)
            guard DropAgentPaths.jobs.standardizedFileURL.path == customJobs.standardizedFileURL.path else {
                fail("settings jobs \(DropAgentPaths.jobs.path)")
            }
            session.setWorkspaceFolder(.jobs, url: nil)
            session.settingsOpen = false
            session.setLanguage(.system)
            let expected = AppLanguage.systemIsChinese ? "设置" : "Settings"
            guard Copy.t("设置", "Settings") == expected else {
                fail("settings system language \(Copy.t("设置", "Settings"))")
            }
            session.setLanguage(.zh)
            session.setAppearance(.light)
            await settle()
            guard Palette.isDark == false else { fail("settings light restore") }
            guard Copy.t("设置", "Settings") == "设置" else { fail("settings chinese restore") }
        }

        private func verifyShelfAddSearch() async {
            let extra = DropAgentPaths.inbox.appendingPathComponent("plus-add.txt")
            try? Data("plus".utf8).write(to: extra)
            session.admit(urls: [extra])
            await settle()
            guard session.items.contains(where: { $0.title == "plus-add.txt" }) else {
                fail("plus admit missing plus-add.txt")
            }
            snapshot("e2e-shelf-add")
            let query = SpotlightSearch.spotlightQuery(for: "plus-add")
            guard query.contains("plus-add") else {
                fail("spotlight query \(query)")
            }
            let box = DropAgentPaths.root.appendingPathComponent("SearchBox", isDirectory: true)
            try? FileManager.default.createDirectory(at: box, withIntermediateDirectories: true)
            let needle = box.appendingPathComponent("unique-dropagent-search-xyz.md")
            try? Data("search".utf8).write(to: needle)
            let found = SpotlightSearch.collect(query: "dropagent-search-xyz", roots: [box])
            guard found.contains(where: { $0.name.contains("dropagent-search-xyz") }) else {
                fail("folder search missed \(found.map(\.name))")
            }
            session.spotlight.setText("ab")
            guard session.spotlight.isActive else { fail("search not active") }
            await settle()
            snapshot("e2e-shelf-search")
            session.spotlight.setText("")
            guard session.spotlight.isActive == false else { fail("search stayed active") }
            if let id = session.items.first(where: { $0.title == "plus-add.txt" })?.id {
                session.remove(id: id)
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
            guard LivePanelChrome.styleMask.contains(.miniaturizable) == false else {
                fail("live panel still miniaturizable")
            }
            guard LivePanelChrome.styleMask.contains(.resizable) == false else {
                fail("live panel became resizable")
            }
            let visible = NSRect(x: 0, y: 0, width: 1440, height: 900)
            let placed = PanelPlacement.underStatusItem(
                button: NSRect(x: 1300, y: 878, width: 28, height: 22),
                visible: visible,
                size: NSSize(width: 1040, height: 400)
            )
            guard placed.width >= LivePanelChrome.shelfOnlyMin else {
                fail("default width too small \(placed.width)")
            }
            let moved = PanelPlacement.placed(
                savedX: 80,
                savedTop: 820,
                size: NSSize(width: 1040, height: 360),
                visible: visible
            )
            guard abs(moved.maxY - 820) < 0.5 else {
                fail("saved top \(moved.maxY)")
            }
            guard abs(moved.minX - 80) < 0.5 else {
                fail("saved x \(moved.minX)")
            }
            var prefs = AppPreferences.default
            prefs.savedPanelOrigin = (120, 760)
            prefs.save()
            let loaded = AppPreferences.load()
            guard let origin = loaded.savedPanelOrigin else {
                fail("panel origin did not persist")
            }
            guard abs(origin.x - 120) < 0.5, abs(origin.top - 760) < 0.5 else {
                fail("panel origin roundtrip \(origin)")
            }
            let again = PanelPlacement.placed(
                savedX: origin.x,
                savedTop: origin.top,
                size: NSSize(width: 1040, height: 400),
                visible: visible
            )
            guard abs(again.minX - 120) < 0.5, abs(again.maxY - 760) < 0.5 else {
                fail("reopen frame \(again)")
            }
            let clamped = PanelPlacement.clamp(NSRect(x: -80, y: -40, width: 1040, height: 400), visible: visible)
            guard clamped.minX >= visible.minX else {
                fail("clamp left \(clamped.minX)")
            }
            guard LivePanelChrome.panelWidth == 1040 else {
                fail("panel width \(LivePanelChrome.panelWidth)")
            }
            guard LivePanelChrome.dockGap >= 10 else {
                fail("dock gap \(LivePanelChrome.dockGap)")
            }
            guard LivePanelChrome.scrollGutter >= 12 else {
                fail("scroll gutter \(LivePanelChrome.scrollGutter)")
            }
            guard let window, window.styleMask.contains(.borderless) else {
                fail("e2e window not borderless")
            }
            guard window.styleMask.contains(.titled) == false else {
                fail("e2e window still titled")
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
            guard host.isOpaque == false else {
                fail("paper host is opaque")
            }
            guard LivePanelChrome.dockShadowPad > LivePanelChrome.paperShadowRadius + LivePanelChrome.paperShadowY else {
                fail("shadow pad clips paper shadow")
            }
        }

        private func verifyPanelIdle() {
            guard PanelIdle.toggle(visible: false, recessed: false) == .show else {
                fail("hidden toggle should show")
            }
            guard PanelIdle.toggle(visible: true, recessed: true) == .wake else {
                fail("recessed toggle should wake")
            }
            guard PanelIdle.toggle(visible: true, recessed: false) == .hide else {
                fail("active toggle should hide")
            }
            guard PanelIdle.toggle(visible: true, recessed: false, onActiveSpace: false) == .show else {
                fail("off-space active toggle should show")
            }
            guard PanelIdle.toggle(visible: true, recessed: true, onActiveSpace: false) == .show else {
                fail("off-space recessed toggle should show")
            }
            let space = PanelIdle.spaceBehavior
            guard space.contains(.moveToActiveSpace), space.contains(.fullScreenAuxiliary) else {
                fail("space behavior missing move/fullscreen")
            }
            guard space.contains(.stationary) == false, space.contains(.canJoinAllSpaces) == false else {
                fail("space behavior still sticky")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: false, exporting: false, diagnostic: false
            ) else {
                fail("idle should recess")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: true, mouseInside: false, exporting: false, diagnostic: false
            ) == false else {
                fail("key window recessed")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: true, exporting: false, diagnostic: false
            ) == false else {
                fail("mouse inside recessed")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: false, exporting: true, diagnostic: false
            ) == false else {
                fail("export recessed")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: false, exporting: false, diagnostic: true
            ) == false else {
                fail("diagnostic recessed")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: false, exporting: false, diagnostic: false, dragging: true
            ) == false else {
                fail("dragging recessed")
            }
            guard PanelIdle.shouldRecess(
                visible: true, isKey: false, mouseInside: false, exporting: false, diagnostic: false, prompting: true
            ) == false else {
                fail("picker recessed")
            }
            let frame = NSRect(x: 100, y: 100, width: 200, height: 200)
            guard PanelIdle.dragHitsPanel(mouse: NSPoint(x: 94, y: 150), frame: frame) else {
                fail("halo miss")
            }
            guard PanelIdle.dragHitsPanel(mouse: NSPoint(x: 50, y: 50), frame: frame) == false else {
                fail("far drag hit panel")
            }
            guard PanelIdle.dragApproachingPanel(mouse: NSPoint(x: 50, y: 150), frame: frame) else {
                fail("approach halo miss")
            }
            guard PanelIdle.dragApproachingPanel(mouse: NSPoint(x: 10, y: 10), frame: frame) == false else {
                fail("far drag counted as approaching")
            }
            let panel = DropAgentPanel(
                contentRect: NSRect(x: 0, y: 0, width: 40, height: 40),
                styleMask: LivePanelChrome.styleMask,
                backing: .buffered,
                defer: true
            )
            panel.level = PanelIdle.activeLevel
            panel.alphaValue = 1
            PanelIdle.applyRecess(to: panel)
            guard abs(panel.alphaValue - PanelIdle.alpha) < 0.01 else {
                fail("recess alpha \(panel.alphaValue)")
            }
            guard panel.level == PanelIdle.recessedLevel else {
                fail("recess level \(panel.level.rawValue)")
            }
            PanelIdle.applyActive(to: panel)
            guard panel.alphaValue == 1 else {
                fail("active alpha \(panel.alphaValue)")
            }
            guard panel.level == PanelIdle.activeLevel else {
                fail("active level \(panel.level.rawValue)")
            }
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            PanelIdle.attachToActiveSpace(panel)
            let attached = panel.collectionBehavior
            guard attached.contains(.moveToActiveSpace), attached.contains(.fullScreenAuxiliary) else {
                fail("attach missing move/fullscreen")
            }
            guard attached.contains(.stationary) == false, attached.contains(.canJoinAllSpaces) == false else {
                fail("attach still sticky")
            }
            panel.orderOut(nil)
            PanelIdle.attachToActiveSpace(panel)
            guard panel.isVisible == false else {
                fail("attach showed hidden panel")
            }
            panel.makeKeyAndOrderFront(nil)
            let onSpace = panel.isOnActiveSpace
            PanelIdle.attachToActiveSpace(panel)
            if onSpace {
                guard panel.isVisible else {
                    fail("attach hid on-space panel")
                }
            } else {
                guard panel.isVisible == false else {
                    fail("attach left off-space panel visible")
                }
            }
            panel.orderOut(nil)
        }

        private func verifyPlusKeepsPanel() {
            let panel = NSPanel(
                contentRect: NSRect(x: 40, y: 40, width: 80, height: 80),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.alphaValue = 1
            panel.orderFront(nil)
            StatusChrome.lowerForPicker()
            guard panel.isVisible else { fail("plus hid the panel") }
            guard panel.alphaValue > 0.99 else { fail("plus faded the panel \(panel.alphaValue)") }
            guard panel.level == .floating else { fail("plus level \(panel.level.rawValue)") }
            StatusChrome.restore()
            guard panel.isVisible else { fail("restore hid the panel") }
            guard panel.level == .statusBar else { fail("restore level \(panel.level.rawValue)") }
            panel.orderOut(nil)
        }

        private func verifyStatusItemPinned() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.autosaveName = "DropAgentStatusItemE2E"
            item.behavior = []
            item.isVisible = true
            defer {
                StatusChrome.restore()
                NSStatusBar.system.removeStatusItem(item)
            }
            guard item.isVisible else {
                fail("status item hidden after pin")
            }
            guard item.behavior.contains(.removalAllowed) == false else {
                fail("status item removable")
            }
            let extra = item.button?.window
            if let extra {
                guard StatusChrome.isMenuExtra(extra) else {
                    fail("extra window not recognized \(type(of: extra))")
                }
            }
            StatusChrome.hideForPrompt()
            guard item.isVisible else {
                fail("prompt hid status item")
            }
            if let extra {
                guard extra.alphaValue > 0.99 else {
                    fail("prompt faded extra \(extra.alphaValue)")
                }
                guard extra.isVisible else {
                    fail("prompt ordered out extra")
                }
            }
            StatusChrome.restore()
            item.behavior = []
            item.isVisible = true
            guard item.isVisible else {
                fail("restore hid status item")
            }
        }

        private func verifyPermissionLowersPanel() {
            let panel = NSPanel(
                contentRect: NSRect(x: 40, y: 40, width: 80, height: 80),
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.alphaValue = 1
            panel.orderFront(nil)
            StatusChrome.lowerForPermission()
            guard panel.isVisible else { fail("permission hid the panel") }
            guard panel.level == .normal else { fail("permission level \(panel.level.rawValue)") }
            StatusChrome.restore()
            guard panel.isVisible else { fail("permission restore hid the panel") }
            guard panel.level == .statusBar else { fail("permission restore level \(panel.level.rawValue)") }
            panel.orderOut(nil)
        }

        private func verifySetupCard() async {
            guard SetupCardPolicy.shouldShowCard(
                dismissed: false,
                captureReady: false,
                isDiagnostic: false,
                panelVisible: true,
                requested: true
            ) else {
                fail("setup card hidden when requested")
            }
            guard SetupCardPolicy.shouldShowCard(
                dismissed: false,
                captureReady: false,
                isDiagnostic: false,
                panelVisible: true,
                requested: false
            ) == false else {
                fail("setup card shown without request")
            }
            guard SetupCardPolicy.shouldShowCard(
                dismissed: true,
                captureReady: false,
                isDiagnostic: false,
                panelVisible: true,
                requested: true
            ) == false else {
                fail("dismissed setup card still shown")
            }
            guard SetupCardPolicy.shouldShowCard(
                dismissed: false,
                captureReady: false,
                isDiagnostic: true,
                panelVisible: true,
                requested: true
            ) == false else {
                fail("diagnostic setup card shown")
            }
            guard SetupCardPolicy.shouldShowCard(
                dismissed: false,
                captureReady: true,
                isDiagnostic: false,
                panelVisible: true,
                requested: true
            ) == false else {
                fail("ready setup card shown")
            }
            guard SetupCardPolicy.shouldShowCaptureBanner(
                onboarded: true,
                isEmpty: true,
                captureReady: false,
                dismissed: false,
                isDiagnostic: false,
                covering: false
            ) else {
                fail("capture banner hidden after onboarding")
            }
            guard SetupCardPolicy.shouldShowCaptureBanner(
                onboarded: false,
                isEmpty: true,
                captureReady: false,
                dismissed: false,
                isDiagnostic: false,
                covering: false
            ) == false else {
                fail("capture banner during onboarding")
            }
            guard SetupCardPolicy.shouldShowCaptureBanner(
                onboarded: true,
                isEmpty: true,
                captureReady: false,
                dismissed: true,
                isDiagnostic: false,
                covering: false
            ) == false else {
                fail("dismissed capture banner still shown")
            }
            guard SetupCardPolicy.gearNeedsAttention(hasAgent: false, setup: SetupFixtures.incomplete) else {
                fail("missing agent should mark gear")
            }
            guard SetupCardPolicy.gearNeedsAttention(hasAgent: true, setup: SetupFixtures.ready) == false else {
                fail("ready setup still marks gear")
            }
            let mixedBrowsers = PageAdmitSetup(
                accessibilityTrusted: true,
                browsers: [
                    PageAdmitBrowserRow(
                        displayName: "Safari",
                        bundleIdentifier: "com.apple.Safari",
                        running: true,
                        state: .allowed
                    ),
                    PageAdmitBrowserRow(
                        displayName: "Google Chrome",
                        bundleIdentifier: "com.google.Chrome",
                        running: true,
                        state: .notDetermined
                    ),
                ]
            )
            guard mixedBrowsers.captureReady else {
                fail("one allowed browser should be capture ready")
            }
            guard SetupCardPolicy.gearNeedsAttention(hasAgent: true, setup: mixedBrowsers) == false else {
                fail("unused browser should not mark gear")
            }
            guard SetupCardPolicy.browserAction(allowed: false, running: true) == .authorize else {
                fail("running chrome still needs a request even if probe said denied")
            }
            guard SetupCardPolicy.browserAction(allowed: false, running: false) == .openAndAuthorize else {
                fail("closed chrome should open then authorize")
            }
            guard SetupCardPolicy.browserAction(allowed: true, running: true) == .ready else {
                fail("allowed chrome should be ready")
            }
            do {
                let decoded = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
                guard decoded.setupCardDismissed == false else {
                    fail("missing setupCardDismissed should be false")
                }
                guard decoded.firstActionHintDismissed == false else {
                    fail("missing firstActionHintDismissed should be false")
                }
                guard decoded.showDropWheel else {
                    fail("missing drop wheel pref should default on")
                }
            } catch {
                fail("prefs decode empty \(error)")
            }
            guard session.suppressSetupCard else {
                fail("e2e should suppress setup card")
            }
            guard session.showsSetupCard == false else {
                fail("e2e showed setup card")
            }
            session.prefs.setupCardDismissed = false
            session.prefs.save()
            session.setupPermissionsOverride = SetupFixtures.incomplete
            session.suppressSetupCard = false
            session.refreshSetup()
            guard session.showsSetupCard == false else {
                fail("incomplete setup shown without request")
            }
            session.requestSetupCard()
            guard session.showsSetupCard else {
                fail("forced setup card hidden")
            }
            await settle()
            snapshot("e2e-setup")
            session.suppressSetupCard = true
            session.setupCardRequested = false
            session.setupPermissionsOverride = nil
            session.refreshSetup()
            guard session.showsSetupCard == false else {
                fail("setup card lingered after restore")
            }
        }

        private func verifyErrorRecoveryUI() async {
            session.errorText = "网页抓取需要授权，请授权后重试。"
            session.offerPrivacySettings = true
            session.offerCaptureRetry = true
            await settle()
            guard let host = hosting,
                  viewContains(host, needle: "error-banner"),
                  viewContains(host, needle: "error-authorize"),
                  viewContains(host, needle: "error-retry") else {
                fail("capture recovery actions are hidden")
            }
            session.dismissError()
            await settle()
            guard session.errorText == nil, !session.offerPrivacySettings, !session.offerCaptureRetry,
                  !viewContains(host, needle: "error-banner") else {
                fail("error dismissal did not clear the recovery UI and state")
            }
        }

        private func verifyOnboarding() async {
            guard Onboarding.shouldShow(markerExists: false, isEmpty: true) else {
                fail("onboarding hidden when empty")
            }
            guard Onboarding.shouldShow(markerExists: true, isEmpty: true) == false else {
                fail("onboarding after marker")
            }
            guard Onboarding.shouldShow(markerExists: false, isEmpty: false) == false else {
                fail("onboarding with items")
            }
            guard Onboarding.shouldShowCoach(dismissed: false, hasSelection: true, isBusy: false) else {
                fail("coach hidden on first item")
            }
            guard Onboarding.shouldShowCoach(dismissed: true, hasSelection: true, isBusy: false) == false else {
                fail("dismissed coach still shown")
            }
            guard Onboarding.shouldShowCoach(dismissed: false, hasSelection: true, isBusy: true) == false else {
                fail("coach during confirm")
            }
            guard session.showsOnboarding else { fail("session missing onboarding") }
            snapshot("e2e-onboard")
            session.dismissOnboarding()
            guard !session.showsOnboarding, !session.showsCaptureBanner else {
                fail("skip did not leave a quiet shelf")
            }
            session.presence = .none
            session.recipePresence = .none
            session.tryOnboardingSample()
            guard let sample = session.items.first(where: OnboardingSample.contains),
                  sample.kind == .pdf, sample.status == .idle, session.results.isEmpty else {
                fail("sample must be a real idle PDF; admission must not run a job")
            }
            let before = hash(sample.sourceURL)
            guard !session.showsOnboarding, session.showsFirstActionHint, session.guidedSample?.id == sample.id else {
                fail("sample missing its next action")
            }
            session.chooseRecipe(.pdfText)
            session.cancelConfirm()
            guard session.shelf.item(id: sample.id)?.status == .idle, session.guidedSample != nil else {
                fail("cancel did not return to the sample guide")
            }
            session.chooseRecipe(.pdfText)
            guard session.canConfirmRun, session.recipeNetworkFact == "关", !session.hasAgent else {
                fail("sample extraction must work without agent or network")
            }
            await session.confirmRun()
            guard let result = session.selectedResult, let output = result.output,
                  result.title == "pdf.md", result.sourceItemIDs.contains(sample.id) else {
                fail(session.errorText ?? "sample extraction did not present a result")
            }
            let body = (try? String(contentsOf: output, encoding: .utf8)) ?? ""
            guard body.contains(Copy.t("季度报告", "quarterly report")),
                  body.contains(Copy.t("客户反馈", "customer feedback")) else {
                fail("sample did not extract its actual content")
            }
            guard hash(sample.sourceURL) == before, session.guidedSample?.id == sample.id, session.showsActionBar else {
                fail("sample source changed or completion guidance disappeared")
            }
            do {
                let landed = try await land(result.takeawayItem())
                guard try String(contentsOf: landed, encoding: .utf8) == body else {
                    fail("sample exported content differs from result")
                }
            } catch { fail("sample export: \(error)") }
            session.dismissFirstActionHint()
            guard session.guidedSample == nil, AppPreferences.load().firstActionHintDismissed else {
                fail("sample guide dismissal was not persisted")
            }
            session.removeResult(result.id)
            session.remove(id: sample.id)
            session.refresh()
            guard !session.showsOnboarding,
                  FileManager.default.fileExists(atPath: DropAgentPaths.onboardedFile.path) else {
                fail("onboarding returned after clearing the sample")
            }
            session.refreshPresence()
            guard FileManager.default.fileExists(atPath: DropAgentPaths.openedFile.path) == false else {
                fail("onboarding wrote opened")
            }
        }

        private func verifyFirstOpen() {
            guard FirstOpen.shouldReveal(markerExists: false, isDiagnostic: false) else {
                fail("first open hidden")
            }
            guard FirstOpen.shouldReveal(markerExists: true, isDiagnostic: false) == false else {
                fail("repeat launch would pop")
            }
            guard FirstOpen.shouldReveal(markerExists: false, isDiagnostic: true) == false else {
                fail("diagnostic would pop")
            }
            guard FileManager.default.fileExists(atPath: DropAgentPaths.openedFile.path) == false else {
                fail("e2e wrote first-open marker")
            }
        }

        private func verifyEdgePlacement() {
            guard let screen = NSScreen.main ?? NSScreen.screens.first else {
                fail("no screen for edge")
            }
            let visible = screen.visibleFrame
            let top = NSPoint(x: visible.midX, y: screen.frame.maxY - 8)
            if EdgePlacement.inTabSafeZone(mouse: top, screen: screen) == false {
                fail("tab zone missed")
            }
            let middle = NSPoint(x: visible.midX, y: visible.midY)
            if EdgePlacement.inTabSafeZone(mouse: middle, screen: screen) {
                fail("middle treated as tab zone")
            }
            if EdgePlacement.band(mouse: middle, center: middle) != .hole {
                fail("center is not a hole")
            }
            let up = NSPoint(x: middle.x, y: middle.y + (EdgePlacement.innerRadius + EdgePlacement.outerRadius) / 2)
            if EdgePlacement.band(mouse: up, center: middle) != .slice(0) {
                fail("top slice is not shelf")
            }
            let far = NSPoint(x: middle.x, y: middle.y + EdgePlacement.outerRadius + EdgePlacement.leaveSlop + 8)
            if EdgePlacement.leftRange(mouse: far, center: middle) == false {
                fail("leave range missed")
            }
            if EdgePlacement.leftRange(mouse: up, center: middle) {
                fail("slice counted as left")
            }
            let frame = EdgePlacement.windowFrame(center: middle)
            if abs(frame.midX - middle.x) > 0.5 || abs(frame.midY - middle.y) > 0.5 {
                fail("window not centered")
            }
            if WheelLayout.slices(hasAgent: true, hasRecipe: true).count != 6 {
                fail("wheel slice count")
            }
            let dummyBoard = NSPasteboard.withUniqueName()
            dummyBoard.clearContents()
            dummyBoard.declareTypes(
                [NSPasteboard.PasteboardType("org.chromium.drag-dummy-type")],
                owner: nil
            )
            if ClipboardPayload.hasDragCargo(dummyBoard) {
                fail("dummy drag counted as cargo")
            }
            dummyBoard.clearContents()
            dummyBoard.setString("https://example.com", forType: .string)
            if ClipboardPayload.hasDragCargo(dummyBoard) == false {
                fail("url text not cargo")
            }
            let sample = URL(fileURLWithPath: "/tmp/dropagent-wheel.pdf")
            let snap = ClipboardPayload.files([sample])
            guard WheelRelease.admitPayload(live: .empty, snapshot: snap) == snap else {
                fail("empty live should use wheel snapshot")
            }
            guard WheelRelease.admitPayload(live: .text("https://example.com"), snapshot: snap) == .text("https://example.com") else {
                fail("live payload should beat snapshot")
            }
            guard WheelRelease.panelTakesDrop(overPanel: true) else {
                fail("panel drop should beat the wheel")
            }
            guard WheelRelease.panelTakesDrop(overPanel: false) == false else {
                fail("wheel should take drops off the panel")
            }
            let consumed = EdgePlacement.consumeDragPasteboard(clearCargo: true)
            if EdgePlacement.dragPasteboardHasPayload(consumedChangeCount: consumed) {
                fail("consumed drag still live")
            }
            session.systemDragActive = true
            session.finishExternalDrag()
            guard session.systemDragActive == false else {
                fail("external drag stayed active")
            }
            let types = IncomingDrop.draggedTypes
            if types.contains(NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType")) == false {
                fail("edge missing web titles type")
            }
            if types.contains(NSPasteboard.PasteboardType("public.item")) == false {
                fail("edge missing public.item")
            }
        }

        private func verifyPaneLayout() async {
            guard session.prefs.showDropWheel else {
                fail("drop wheel should default on")
            }
            guard abs(LivePanelChrome.panelWidth - 1040) < 0.5 else {
                fail("full panel width \(LivePanelChrome.panelWidth)")
            }
            guard settingsShows("shelf-column") else {
                fail("shelf missing \(settingsTree())")
            }
            guard settingsShows("pane-menu") == false else {
                fail("pane menu still in header")
            }
            let note = DropAgentPaths.inbox.appendingPathComponent("pane-layout.md")
            try? Data("# pane\n".utf8).write(to: note)
            let record = session.shelf.addResult(
                ResultRecord(
                    sourceItemIDs: [],
                    recipe: "layout",
                    title: "pane-layout.md",
                    kind: .markdown,
                    output: note
                )
            )
            session.adoptNewestResult()
            await settle()
            guard settingsShows("result-stack") else {
                fail("result strip missing after job \(settingsTree())")
            }
            guard settingsShows("import-result") else {
                fail("import action missing \(settingsTree())")
            }
            session.hideResult(record.id)
            session.setShowDropWheel(false)
            guard session.prefs.showDropWheel == false else {
                fail("drop wheel did not turn off")
            }
            guard let data = try? Data(contentsOf: DropAgentPaths.prefsFile),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["showDropWheel"] as? Bool == false
            else {
                fail("prefs.json missing showDropWheel")
            }
            session.setShowDropWheel(true)
            session.setMultiSelect(true)
            guard session.multiSelect else {
                fail("multi-select did not turn on")
            }
            session.setMultiSelect(false)
        }

        private func verifyShelfDragRelease() {
            try? DropAgentPaths.ensure()
            let note = DropAgentPaths.inbox.appendingPathComponent("shelf-drag.md")
            try? Data("# drag\n".utf8).write(to: note)
            session.admit(urls: [note])
            guard let id = session.items.first(where: { $0.title == "shelf-drag.md" })?.id else {
                fail("no shelf-drag.md")
            }
            let count = session.items.count
            session.beginShelfDrag(ids: [id])
            session.admitDrop(providers: [])
            guard session.items.count == count else {
                fail("dropping a shelf item back onto the shelf copied it")
            }
            session.shelfDragIDs = []
            PasteboardService.clearShelfDrag()
            session.admit(urls: [note])
            guard session.items.filter({ $0.title == "shelf-drag.md" }).count == 2 else {
                fail("dropping the original again should still add")
            }
            for item in session.items.filter({ $0.title == "shelf-drag.md" }) {
                session.remove(id: item.id)
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

        private func settingsShows(_ needle: String) -> Bool {
            guard let hosting else { return false }
            hosting.layoutSubtreeIfNeeded()
            window?.displayIfNeeded()
            return viewContains(hosting, needle: needle)
        }

        private func viewContains(_ view: NSView, needle: String) -> Bool {
            if let field = view as? NSTextField, field.stringValue.contains(needle) { return true }
            if let text = view as? NSTextView, text.string.contains(needle) { return true }
            if (view.accessibilityLabel() ?? "").contains(needle) { return true }
            if view.accessibilityIdentifier().contains(needle) { return true }
            return view.subviews.contains { viewContains($0, needle: needle) }
        }

        private func settingsTree() -> String {
            guard let hosting else { return "no-host" }
            return viewDump(hosting)
        }

        private func viewDump(_ view: NSView, indent: String = "") -> String {
            var line = "\(indent)\(type(of: view))"
            let identifier = view.accessibilityIdentifier()
            if identifier.isEmpty == false { line += " id=\(identifier)" }
            if let field = view as? NSTextField { line += " tf=\(field.stringValue)" }
            let label = view.accessibilityLabel() ?? ""
            if label.isEmpty == false { line += " label=\(label)" }
            let children = view.subviews.map { viewDump($0, indent: indent + "  ") }
            return ([line] + children).joined(separator: "\n")
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
