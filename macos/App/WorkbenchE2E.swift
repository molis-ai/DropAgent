import AppKit
import DropAgentAgent
import DropAgentIngest
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import SwiftTerm
import SwiftUI

@MainActor
enum WorkbenchE2E {
    static func run(session: AppSession, window: NSWindow, host: NSView) async {
        let out = DropAgentPaths.root.appendingPathComponent("ui")
        session.setLanguage(.zh)
        session.setAppearance(.light)
        session.tryOnboardingSample()
        session.dismissFirstActionHint()
        session.presence = .none
        session.recipePresence = .none
        guard let sample = session.selectedItems.first else { fail("sample not admitted") }
        let original = try? Data(contentsOf: sample.sourceURL)
        let size = NSSize(width: session.panelWidth, height: session.panelHeight)
        window.setContentSize(size)
        host.frame.size = size
        let stableHeight = session.panelHeight
        let board = NSPasteboard.withUniqueName()
        board.setString("访谈记录\n\n用户希望随时看见输入材料，以及每次操作生成的新文件。\n\n下一步：整理意见，验证首次使用流程。", forType: .string)
        session.notePasteboard(board, stageFiles: false)
        board.clearContents()
        board.setString("https://linear.app", forType: .string)
        session.notePasteboard(board, stageFiles: false)
        board.clearContents()
        board.setString("本周待办：完善文件预览与结果对照。", forType: .string)
        session.notePasteboard(board, stageFiles: false)
        await shot("01-material", host, out)
        require(contains(host, "shelf-search") && contains(host, "shelf-add"), "search field or add button missing")
        require(contains(host, "item-copy") && contains(host, "hide-item") && contains(host, "delete-item"), "material row actions missing")
        require(contains(host, "shelf-search-toggle") == false, "search toggle still present")
        session.materialsExpanded = false
        await settle(host)
        require(contains(host, "item-copy") == false, "collapsed materials still listed files")
        session.materialsExpanded = true
        session.selectMaterial(sample.id)
        session.selectMaterial(sample.id)
        require(session.selectedItems.map(\.id) == [sample.id], "repeated selection cleared preview")
        session.chooseRecipe(.pdfText)
        require(session.stagedItem?.id == sample.id && session.showsActionBar && session.canConfirmRun, "confirmation lost preview or controls")
        await shot("02-confirm", host, out)
        await session.confirmRun()
        guard let result = session.selectedResult, let output = result.output else { fail("PDF result missing") }
        let body = (try? String(contentsOf: output, encoding: .utf8)) ?? ""
        require(body.contains("季度报告") && body.contains("客户反馈"), "PDF extraction did not preserve actual content")
        require((try? Data(contentsOf: sample.sourceURL)) == original, "original modified")
        require(session.panelHeight == stableHeight, "window changed size")
        await shot("03-result", host, out)
        session.toggleComparison()
        require(session.comparisonSource?.id == sample.id, "wrong comparison source")
        await shot("04-compare", host, out)
        session.setAppearance(.dark)
        await shot("05-compare-dark", host, out)
        session.setAppearance(.light)
        if CommandLine.arguments.contains("--workbench-review") { return }
        let clipboardCount = NSPasteboard.general.changeCount
        let materialCount = session.items.count
        guard let clip = session.clipRecords.first else { fail("history missing") }
        session.selectClipboard(clip.id)
        await settle(host)
        require(contains(host, "clip-row-copy") && contains(host, "clip-row-admit") && contains(host, "clip-row-delete"), "clipboard row actions missing")
        require(NSPasteboard.general.changeCount == clipboardCount && session.items.count == materialCount, "clipboard preview mutated state")
        require(session.stagedItem == nil && !session.canRunSlot(.recipe(.pdfText)) && !session.canSendToTUI, "clipboard used stale material selection")
        session.presentJobResult(sourceIDs: [sample.id])
        require(session.paneFocus == .clipboard, "result stole clipboard focus")
        await shot("06-clipboard", host, out)
        session.admitSelectedClips()
        guard let admittedClip = session.selectedItems.first, let copy = admittedClip.parts.first?.url else { fail("clipboard not admitted") }
        require((try? String(contentsOf: copy, encoding: .utf8)) == clip.text, "clipboard copy content differs")
        session.selectClipboard(clip.id)
        session.moveSelection(offset: 1)
        require(session.selectedClipboard?.id != clip.id && session.paneFocus == .clipboard, "clipboard arrow moved materials")
        session.selectClipboard(clip.id)
        session.removeSelected()
        require(!session.clipRecords.contains { $0.id == clip.id } && session.shelf.item(id: sample.id) != nil, "clipboard delete removed material")
        let missing = DropAgentPaths.root.appendingPathComponent("missing.txt")
        if let draft = ClipDraft(kind: .files, title: "missing.txt", filePaths: [missing.path]) { session.clipHistory.record(draft) }
        session.refreshClips()
        guard let missingClip = session.clipRecords.first(where: { $0.title == "missing.txt" }) else { fail("missing clip not recorded") }
        session.selectClipboard(missingClip.id)
        let beforeMissing = session.items.count
        session.admitSelectedClips()
        require(session.items.count == beforeMissing && session.errorText != nil, "missing clipboard silently admitted")
        guard let validClip = session.clipRecords.first(where: { $0.kind == .text }) else { fail("valid clip missing") }
        session.selectClipboard(validClip.id, extending: true)
        session.admitSelectedClips()
        require(session.items.count == beforeMissing + 1 && session.errorText?.contains("missing.txt") == true,
                "partial clipboard admission discarded success or hid failure")
        guard let partialCopy = session.selectedItems.first?.parts.first?.url else { fail("partial clipboard admission missing copy") }
        require((try? String(contentsOf: partialCopy, encoding: .utf8)) == validClip.text, "partial clipboard admission copied wrong content")
        session.errorText = nil
        session.deleteClip(missingClip.id)
        session.selectResult(result.id)
        session.copyItem(result.takeawayItem(), to: board)
        let copiedFiles = PasteboardService.fileURLs(for: [result.takeawayItem()])
        require(copiedFiles.contains(output), "result export missing output")
        session.importSelectedResults()
        guard let imported = session.selectedItems.first, let importedURL = imported.parts.first?.url else { fail("result import missing") }
        require(importedURL != output && (try? String(contentsOf: importedURL, encoding: .utf8)) == body, "result was not copied into materials")
        let folder = DropAgentPaths.root.appendingPathComponent("项目资料", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let note = folder.appendingPathComponent("会议纪要.md")
        try? Data("# 工作台改版\n\n材料始终可见。指令固定在下方。\n\n- 选择文件即可预览\n- 结果按需对照原文\n- 剪贴板历史默认展开\n".utf8).write(to: note)
        session.admit(urls: [folder])
        guard let folderItem = session.items.first(where: { $0.kind == .folder }), let folderRoot = folderItem.parts.first?.url else { fail("folder missing") }
        session.selectMaterial(folderItem.id)
        session.folderPreviewURL = FolderListing.firstFile(in: folderRoot, stayingInside: folderRoot)
        session.refreshPresence()
        await shot("07-folder", host, out)
        session.setAppearance(.dark)
        await shot("07-folder-dark", host, out)
        session.setAppearance(.light)
        session.selectMaterial(sample.id)
        try? session.shelf.patch(id: sample.id) { $0.status = .running; $0.event = "正在整理文字…" }
        session.refresh()
        require(session.stagedItem?.id == sample.id && !session.canRunSlot(.recipe(.pdfText)), "running state lost preview or accepted action")
        await shot("08-running", host, out)
        try? session.shelf.patch(id: sample.id) { $0.status = .failed; $0.failureReason = "处理被取消，可以重新运行。" }
        session.refresh()
        await shot("09-retry", host, out)
        session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
        session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
        session.otherOpen = true
        session.aiTab = .tty
        session.tuiSessionDirectory = DropAgentPaths.tuiInbox
        session.selectResult(result.id)
        session.comparingResult = false
        await shot("10-chat", host, out)
        let terminal = findTerminal(host)
        session.otherOpen = false
        await settle(host)
        session.settingsOpen = true
        await settle(host)
        session.settingsOpen = false
        session.otherOpen = true
        await settle(host)
        require(terminal != nil && terminal === findTerminal(host), "terminal instance recreated")
        session.otherOpen = false
        session.setLanguage(.en)
        session.comparingResult = true
        window.setContentSize(NSSize(width: 800, height: session.panelHeight))
        host.frame.size = NSSize(width: 800, height: session.panelHeight)
        await shot("11-narrow-en", host, out)
        window.setContentSize(size)
        host.frame.size = size
        session.setLanguage(.zh)
        session.selectResult(result.id)
        session.shelf.patchResult(id: result.id) { $0.sourceItemIDs.append(folderItem.id) }
        session.refresh()
        session.comparisonSourceID = folderItem.id
        require(session.comparisonSource?.id == folderItem.id, "multiple source choice ignored")
        session.hideItem(sample.id)
        session.hideItem(folderItem.id)
        require(session.comparisonSources.isEmpty, "missing sources not removed")
        await shot("12-missing-source", host, out)
        session.hideResult(result.id)
        require(session.selectedResultID == nil && session.paneFocus == .input, "deleted result left dead selection")
        for item in session.items { session.hideItem(item.id) }
        let memo = DropAgentPaths.root.appendingPathComponent("周五工作备忘.md")
        try? Data("""
        # 周五工作备忘

        下周一把季度复盘发给团队。正文先讲清本季度完成的工作，再整理待决事项。

        ## 需要整理的材料

        把现有记录合成一页摘要，保留关键结论和下一步。截图里的信息另列，不直接混进正文。

        ## 交付要求

        请生成一份新的 Markdown 文件，方便继续编辑和分享。
        """.utf8).write(to: memo)
        session.admit(urls: [memo, folder])
        guard let memoItem = session.items.first(where: { $0.title == memo.lastPathComponent }) else { fail("visual document not admitted") }
        session.selectMaterial(memoItem.id)
        session.refreshPresence()
        board.clearContents()
        board.setString("复盘里先写结论和下一步。\n\n下周一之前确认交付范围，再把访谈记录中的意见整理进正文。", forType: .string)
        session.notePasteboard(board, stageFiles: false)
        session.setAppearance(.dark)
        await shot("13-material-dark", host, out)
        session.setAppearance(.light)
        await shot("14-material-light", host, out)
        session.setAppearance(.dark)
        if let savedClip = session.clipRecords.first { session.selectClipboard(savedClip.id) }
        await shot("15-clipboard-dark", host, out)
        for dark in [false, true] {
            Palette.isDark = dark
            let wheel = EdgeDropView()
            wheel.apply(slices: WheelLayout.slices(hasAgent: true, hasRecipe: true), hot: 2)
            wheel.layoutSubtreeIfNeeded()
            save(wheel, out.appendingPathComponent(dark ? "wheel-dark.png" : "wheel-light.png"))
        }
        WheelE2E.run()
        fputs("e2e: workbench ok — PDF extraction/export, selection, clipboard admission/focus/missing, comparison, stable window, terminal identity, wheel regression\n", stdout)
        fputs("screenshots: \(out.path)\n", stdout)
    }

    private static func shot(_ name: String, _ host: NSView, _ out: URL) async {
        await settle(host)
        save(host, out.appendingPathComponent("\(name).png"))
    }
    private static func settle(_ host: NSView) async {
        host.layoutSubtreeIfNeeded()
        host.window?.displayIfNeeded()
        try? await Task.sleep(for: .milliseconds(250))
        host.layoutSubtreeIfNeeded()
        host.window?.displayIfNeeded()
    }
    private static func save(_ view: NSView, _ url: URL) {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fail("snapshot unavailable") }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        do { try bitmap.representation(using: .png, properties: [:])?.write(to: url) }
        catch { fail("snapshot write: \(error)") }
    }
    private static func findTerminal(_ view: NSView) -> LocalProcessTerminalView? {
        if let terminal = view as? LocalProcessTerminalView { return terminal }
        return view.subviews.lazy.compactMap { findTerminal($0) }.first
    }
    private static func contains(_ view: NSView, _ needle: String) -> Bool {
        if view.accessibilityIdentifier().contains(needle) { return true }
        if (view.accessibilityLabel() ?? "").contains(needle) { return true }
        return view.subviews.contains { contains($0, needle) }
    }
    private static func require(_ condition: Bool, _ message: String) { if !condition { fail(message) } }
    private static func fail(_ message: String) -> Never { fputs("e2e: fail \(message)\n", stderr); exit(1) }
}
