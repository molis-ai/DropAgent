import AppKit
import DropAgentAgent
import DropAgentJob
import DropAgentShelf
import SwiftUI

enum PanelPreview {
    @MainActor
    static func run() {
        let root = URL(fileURLWithPath: "/tmp/dropagent-preview-root", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        setenv("DROPAGENT_ROOT", root.path, 1)
        try? DropAgentPaths.ensure()

        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate()
        app.delegate = delegate
        app.run()
    }

    final class Delegate: NSObject, NSApplicationDelegate {
        var session: AppSession!
        private var window: NSWindow?
        private var hosting: PaperHostView<PanelRootView>?
        private let out = URL(fileURLWithPath: "/tmp/dropagent-preview", isDirectory: true)

        func applicationDidFinishLaunching(_ notification: Notification) {
            session = AppSession()
            try? FileManager.default.removeItem(at: out)
            try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

            let window = NSWindow(
                contentRect: NSRect(x: 80, y: 80, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight),
                styleMask: LivePanelChrome.styleMask,
                backing: .buffered,
                defer: false
            )
            window.hasShadow = true
            let host = PaperHostView(rootView: PanelRootView(session: session, onClose: {}, onMinimize: {}))
            host.frame = NSRect(x: 0, y: 0, width: LivePanelChrome.panelWidth, height: LivePanelChrome.panelHeight)
            window.contentView = host
            Palette.applyPaperChrome(to: window, host: host)
            window.makeKeyAndOrderFront(nil)
            self.window = window
            self.hosting = host

            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.captureSequence(host: host)
                NSApp.terminate(nil)
            }
        }

        @MainActor
        private func captureSequence(host: PaperHostView<PanelRootView>) async {
            await settle()
            snapshot(host, name: "01-empty")
            session.systemDragActive = true
            await settle()
            snapshot(host, name: "01-drag")
            session.systemDragActive = false

            let hadAgent = session.hasAgent
            session.presence = .none
            session.recipePresence = .none
            await settle()
            snapshot(host, name: "02-no-agent")
            if hadAgent { session.refreshPresence() }

            let pdf = DropAgentPaths.root.appendingPathComponent("sample.pdf")
            try? Data("%PDF-1.4 sample".utf8).write(to: pdf)
            session.admit(urls: [pdf])
            await settle()
            snapshot(host, name: "03-idle")
            session.systemDragActive = true
            await settle()
            snapshot(host, name: "03-drag")
            session.systemDragActive = false
            session.aiTab = .result
            await settle()
            snapshot(host, name: "03d-pdf-result")
            session.aiTab = .work

            session.presence = .none
            session.recipePresence = .none
            await settle()
            snapshot(host, name: "03b-no-agent-item")
            session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
            session.recipePresence = .none
            await settle()
            snapshot(host, name: "03c-tui-only")
            if hadAgent { session.refreshPresence() }
            await settle()

            session.chooseRecipe(.summarize)
            await settle()
            snapshot(host, name: "04-confirm")

            let confirmedPresence = session.recipePresence
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .unknown)
            await settle()
            snapshot(host, name: "04b-unconfirmed")
            session.recipePresence = confirmedPresence
            await settle()

            session.cancelConfirm()
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            session.chooseRecipe(.translate)
            await settle()
            snapshot(host, name: "04c-translate")
            session.cancelConfirm()
            session.recipePresence = confirmedPresence
            session.chooseRecipe(.summarize)
            await settle()

            if let id = session.items.first?.id {
                try? session.shelf.patch(id: id) { live in
                    live.status = .running
                    live.event = "工具调用"
                }
                session.aiTab = .work
                await settle()
                snapshot(host, name: "05-running")

                try? session.shelf.patch(id: id) { live in
                    live.event = "等待授权"
                }
                await settle()
                snapshot(host, name: "05b-waiting")

                let output = DropAgentPaths.jobs.appendingPathComponent("preview/output/summary.md")
                try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? Data("""
                # 总结

                渠道折扣 9%。

                ## 要点

                | 项 | 值 |
                | --- | --- |
                | 折扣 | 9% |
                | 原件 | 不变 |

                - 只放在副本里做成的总结
                - 原件 Hash 不变
                """.utf8).write(to: output)
                try? session.shelf.patch(id: id) { live in
                    live.status = .idle
                    live.event = ""
                    live.recipe = nil
                    live.failureReason = nil
                    live.output = nil
                    live.isolationShown = .none
                }
                let summary = session.shelf.addResult(
                    ResultRecord(
                        sourceItemIDs: [id],
                        recipe: RecipeID.summarize.fullTitle,
                        title: "summary.md",
                        kind: .markdown,
                        output: output,
                        isolationShown: .workspace
                    )
                )
                session.refresh()
                session.selectResult(summary.id)
                await settle()
                snapshot(host, name: "06-result")
                session.shelf.patchResult(id: summary.id) { live in
                    live.isolationShown = .unconfirmed
                }
                session.refresh()
                await settle()
                snapshot(host, name: "06c-unconfirmed-result")
                session.shelf.patchResult(id: summary.id) { live in
                    live.isolationShown = .workspace
                }
                session.refresh()
                session.toggleSelect(id: id, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "06b-done-work")
                session.selectResult(summary.id)

                let jsonOut = DropAgentPaths.jobs.appendingPathComponent("preview/output/extracted.json")
                try? Data("{\"discount\":\"9%\",\"note\":\"副本\"}".utf8).write(to: jsonOut)
                let extracted = session.shelf.addResult(
                    ResultRecord(
                        sourceItemIDs: [id],
                        recipe: RecipeID.extract.fullTitle,
                        title: "extracted.json",
                        kind: .markdown,
                        output: jsonOut,
                        isolationShown: .workspace
                    )
                )
                session.refresh()
                session.selectResult(extracted.id)
                await settle()
                snapshot(host, name: "06-json")
                session.selectResult(summary.id)
            }

            let webFolder = DropAgentPaths.inbox.appendingPathComponent("preview-web", isDirectory: true)
            try? FileManager.default.createDirectory(at: webFolder, withIntermediateDirectories: true)
            let urlFile = webFolder.appendingPathComponent("url.txt")
            try? Data("https://example.com\n".utf8).write(to: urlFile)
            let mdFile = webFolder.appendingPathComponent("page.md")
            try? Data("Example Domain\n\nThis domain is for use in illustrative examples in documents.\n\n> For illustration only.\n\n![example.com](https://example.com/og.png)\n\n| Command | Use |\n| --- | --- |\n| curl | fetch |\n\n```\ncurl https://example.com\n```\n".utf8).write(to: mdFile)
            let pngFile = webFolder.appendingPathComponent("snapshot.png")
            let shot = NSImage(size: NSSize(width: 320, height: 72), flipped: false) { rect in
                NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
                rect.fill()
                let text = NSAttributedString(
                    string: "example.com",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                        .foregroundColor: NSColor.white,
                    ]
                )
                text.draw(at: NSPoint(x: 12, y: 28))
                return true
            }
            if let tiff = shot.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: pngFile)
            }
            if let web = try? session.shelf.add(Item(
                kind: .web,
                title: "Example Domain",
                sourceURL: URL(string: "https://example.com")!,
                parts: [
                    ItemPart(name: "url.txt", url: urlFile),
                    ItemPart(name: "page.md", url: mdFile),
                    ItemPart(name: "snapshot.png", url: pngFile),
                ],
                event: ""
            )) {
                session.toggleSelect(id: web.id, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "07-web")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "07b-web-result")
                session.aiTab = .work
            }

            let shotFile = DropAgentPaths.inbox.appendingPathComponent("preview-shot.png")
            let shotImage = NSImage(size: NSSize(width: 280, height: 96), flipped: false) { rect in
                NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
                rect.fill()
                let text = NSAttributedString(
                    string: "截图 09-05",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 15, weight: .medium),
                        .foregroundColor: NSColor.white,
                    ]
                )
                text.draw(at: NSPoint(x: 16, y: 40))
                return true
            }
            if let tiff = shotImage.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: shotFile)
            }
            session.admit(urls: [shotFile])
            await settle()
            session.aiTab = .work
            await settle()
            snapshot(host, name: "14-image")
            session.aiTab = .result
            await settle()
            snapshot(host, name: "14b-image-result")
            if let shotID = session.items.first(where: { $0.kind == .image })?.id {
                session.remove(id: shotID)
            }
            session.aiTab = .work

            let clipFile = DropAgentPaths.inbox.appendingPathComponent("clip.txt")
            try? Data("渠道折扣从 14% 收到 9%，不要对外讲具体数字。".utf8).write(to: clipFile)
            if let clip = try? session.shelf.add(Item(
                kind: .clip,
                title: "剪贴板",
                sourceURL: clipFile,
                parts: [ItemPart(name: "clip.txt", url: clipFile)]
            )) {
                session.toggleSelect(id: clip.id, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "15-clip")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "15b-clip-result")
                session.remove(id: clip.id)
            }

            let linkFile = DropAgentPaths.inbox.appendingPathComponent("link.txt")
            try? Data("https://dropoverapp.com\n".utf8).write(to: linkFile)
            if let link = try? session.shelf.add(Item(
                kind: .url,
                title: "dropoverapp.com",
                sourceURL: URL(string: "https://dropoverapp.com")!,
                parts: [ItemPart(name: "link.txt", url: linkFile)]
            )) {
                session.toggleSelect(id: link.id, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "16-url")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "16b-url-result")
                session.remove(id: link.id)
            }

            let bundle = DropAgentPaths.root.appendingPathComponent("bundle", isDirectory: true)
            try? FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
            try? Data("会议纪要".utf8).write(to: bundle.appendingPathComponent("notes.md"))
            try? Data("报价表".utf8).write(to: bundle.appendingPathComponent("quote.txt"))
            session.admit(urls: [bundle])
            await settle()
            if let folderID = session.items.first(where: { $0.kind == .folder })?.id {
                session.toggleSelect(id: folderID, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "17-folder")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "17b-folder-result")
                session.remove(id: folderID)
            }

            let zip = DropAgentPaths.root.appendingPathComponent("archive.zip")
            try? Data("PK".utf8).write(to: zip)
            session.admit(urls: [zip])
            await settle()
            if let zipID = session.items.first(where: { $0.kind == .file })?.id {
                session.toggleSelect(id: zipID, command: false)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "18-file")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "18b-file-result")
                session.remove(id: zipID)
            }

            let jsonFile = DropAgentPaths.root.appendingPathComponent("data.json")
            try? Data("{\"note\":\"副本\",\"discount\":\"9%\"}".utf8).write(to: jsonFile)
            session.admit(urls: [jsonFile])
            await settle()
            if let jsonID = session.items.first(where: { $0.title == "data.json" })?.id {
                session.toggleSelect(id: jsonID, command: false)
                session.aiTab = .result
                await settle()
                snapshot(host, name: "19-json-staged")
                session.remove(id: jsonID)
            }

            let swiftFile = DropAgentPaths.root.appendingPathComponent("main.swift")
            try? Data("let star = *not italic*\n".utf8).write(to: swiftFile)
            session.admit(urls: [swiftFile])
            await settle()
            if let swiftID = session.items.first(where: { $0.title == "main.swift" })?.id {
                session.toggleSelect(id: swiftID, command: false)
                session.aiTab = .result
                await settle()
                snapshot(host, name: "20-source")
                session.remove(id: swiftID)
            }
            session.aiTab = .work

            let notes = DropAgentPaths.root.appendingPathComponent("notes.md")
            try? Data("第二份材料".utf8).write(to: notes)
            session.admit(urls: [notes])
            await settle()
            if let webID = session.items.first(where: { $0.kind == .web })?.id,
               let noteID = session.items.first(where: { $0.title == "notes.md" })?.id
            {
                session.toggleSelect(id: webID, command: false)
                session.toggleSelect(id: noteID, command: true)
                session.setMultiSelect(true)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "13-multi")
                if let doneID = session.items.first(where: { $0.title == "summary.md" })?.id {
                    session.toggleSelect(id: doneID, command: true)
                    await settle()
                    snapshot(host, name: "13c-keep-tab")
                }
                session.chooseRecipe(.brief)
                await settle()
                snapshot(host, name: "13b-brief")
                session.cancelConfirm()
                session.remove(id: noteID)
                session.setMultiSelect(false)
            }

            if let sentID = session.items.first(where: { $0.kind == .web })?.id {
                try? session.shelf.patch(id: sentID) { live in
                    live.status = .sent
                    live.isolationShown = .tui
                }
                session.ttyLines = [
                    TTYLine(kind: "sys", text: "Grok  ·  本机会话"),
                    TTYLine(kind: "file", text: "材料  Example Domain"),
                    TTYLine(kind: "in", text: "›  读一下这页"),
                ]
                session.tuiSessionDirectory = DropAgentPaths.tuiInbox
                session.tuiProcessRunning = true
                session.ptyLive = false
                session.toggleSelect(id: sentID, command: false)
                session.aiTab = .tty
                await settle()
                snapshot(host, name: "08c-opening")
                session.ptyLive = true
                await settle()
                snapshot(host, name: "08-sent")
                session.aiTab = .result
                await settle()
                snapshot(host, name: "08b-sent-result")
            }

            session.errorText = AppSession.captureFailedCopy
            session.offerPrivacySettings = true
            session.offerCaptureRetry = true
            session.aiTab = .work
            await settle()
            snapshot(host, name: "09-error")

            session.dismissError()
            session.prepareCapture()
            await settle()
            snapshot(host, name: "10-capturing")

            session.isCapturing = false
            if let failed = session.results.first(where: { $0.title == "summary.md" }) {
                session.shelf.patchResult(id: failed.id) { live in
                    live.status = .failed
                    live.failureReason = "原件中途变了，结果按副本做的"
                }
                session.refresh()
                session.selectResult(failed.id)
                await settle()
                snapshot(host, name: "11-hash")
                session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
                session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "11b-failed-work")
            }

            let retryNote = DropAgentPaths.inbox.appendingPathComponent("retry-fail.md")
            try? Data("# retry fail\n".utf8).write(to: retryNote)
            session.admit(urls: [retryNote])
            await settle()
            if let retryID = session.items.first(where: { $0.title == "retry-fail.md" })?.id {
                try? session.shelf.patch(id: retryID) { live in
                    live.status = .failed
                    live.failureReason = "任务失败"
                    live.event = "任务失败"
                }
                session.toggleSelect(id: retryID, command: false)
                session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
                session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
                session.aiTab = .work
                await settle()
                snapshot(host, name: "11c-failed-retry")
                session.remove(id: retryID)
            }

            session.hotKeyToggleOK = false
            session.hotKeyCaptureOK = false
            session.presence = .none
            session.recipePresence = .none
            session.dismissError()
            session.aiTab = .work
            await settle()
            snapshot(host, name: "12-hotkeys")

            session.hotKeyToggleOK = true
            session.hotKeyCaptureOK = true
            session.presence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)
            session.recipePresence = .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)
            session.prefs.setupCardDismissed = false
            session.suppressSetupCard = false
            session.setupPermissionsOverride = SetupFixtures.incomplete
            session.settingsOpen = false
            session.refreshSetup()
            await settle()
            snapshot(host, name: "13-setup")
            session.settingsOpen = true
            await settle()
            snapshot(host, name: "13-settings-setup")
            session.settingsOpen = false
            session.suppressSetupCard = true
            session.setupPermissionsOverride = nil
            session.refreshSetup()

            fputs("preview written to \(out.path)\n", stdout)
        }

        @MainActor
        private func settle() async {
            window?.displayIfNeeded()
            hosting?.layoutSubtreeIfNeeded()
            try? await Task.sleep(nanoseconds: 250_000_000)
            window?.displayIfNeeded()
        }

        @MainActor
        private func snapshot(_ view: NSView, name: String) {
            view.layoutSubtreeIfNeeded()
            let bounds = view.bounds
            guard bounds.width > 1, bounds.height > 1,
                  let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
                fputs("preview skip \(name)\n", stderr)
                return
            }
            view.cacheDisplay(in: bounds, to: rep)
            let url = out.appendingPathComponent("\(name).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
}
