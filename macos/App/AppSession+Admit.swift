import AppKit
import DropAgentIngest
import DropAgentPasteboard
import DropAgentShelf
import Foundation

extension AppSession {
    func admit(urls: [URL]) {
        follow(ingest.admit(urls: urls))
        aiTab = .work
        finishExternalDrag()
    }

    func pickFilesToAdmit() {
        onPanelInteraction?()
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = Copy.t("加入", "Add")
        panel.message = Copy.t("选择要放到架子上的文件或文件夹。原件不动。", "Choose files or folders to put on the shelf. Originals stay put.")
        let urls = OpenPanelHost.run(panel)
        onPanelInteraction?()
        guard urls.isEmpty == false else { return }
        admit(urls: urls)
    }

    func admitSpotlight(_ hit: SpotlightHit) {
        admit(urls: [hit.url])
        spotlight.setText("")
    }

    func beginShelfDrag(ids: [ItemID]) {
        flushStageEdit()
        shelfDragIDs = ids
        PasteboardService.markShelfDrag()
    }

    func endShelfDrag() {
        PasteboardService.clearShelfDrag()
        DispatchQueue.main.async { [weak self] in
            self?.shelfDragIDs = []
            PasteboardService.clearShelfDrag()
        }
    }

    var isShelfDrag: Bool {
        shelfDragIDs.isEmpty == false
    }

    func admitDrop(providers: [NSItemProvider]) {
        if draggingActionID != nil {
            finishExternalDrag()
            return
        }
        if isShelfDrag || PasteboardService.isShelfDrag() {
            finishExternalDrag()
            return
        }
        let fallback = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
        Task {
            var result = await ingest.admitProviders(providers)
            if result.admitted.isEmpty, fallback != .empty {
                result = ingest.admitPayload(fallback)
            }
            follow(result)
            aiTab = .work
            finishExternalDrag()
        }
    }

    func admitPasteboard(_ pasteboard: NSPasteboard) {
        if isShelfDrag || PasteboardService.isShelfDrag(pasteboard) {
            finishExternalDrag()
            return
        }
        admitPayload(ClipboardPayload.from(pasteboard: pasteboard))
    }

    func admitPayload(_ payload: ClipboardPayload) {
        follow(ingest.admitPayload(payload))
        aiTab = .work
        finishExternalDrag()
    }

    func admitFromWheel(_ payload: ClipboardPayload, action: WheelAction) {
        if isShelfDrag {
            let ids = shelfDragIDs
            finishExternalDrag()
            guard ids.isEmpty == false else { return }
            switch action {
            case .shelf:
                return
            case .send:
                if hasAgent {
                    sendToTUI(itemIDs: ids)
                }
            case .recipe(let recipe):
                Task { await startWheelRecipe(ids: ids, recipe: recipe) }
            }
            return
        }
        let capturePages = action != .send
        let result = ingest.admitPayload(payload, capturePages: capturePages)
        follow(result)
        let ids = result.admitted.map(\.id)
        finishExternalDrag()
        guard ids.isEmpty == false else { return }
        shelf.setSelection(Set(ids))
        switch action {
        case .shelf:
            aiTab = .work
        case .send:
            if hasAgent {
                sendToTUI(itemIDs: ids)
            } else {
                errorText = Copy.t("未发现终端 Agent。文件已留在架子上。", "No terminal agent found. Files stayed on the shelf.")
                aiTab = .work
            }
        case .recipe(let recipe):
            Task { await startWheelRecipe(ids: ids, recipe: recipe) }
        }
    }

    func admitToTUI(providers: [NSItemProvider]) {
        if isShelfDrag {
            let ids = shelfDragIDs
            finishExternalDrag()
            guard ids.isEmpty == false else { return }
            if hasAgent {
                sendToTUI(itemIDs: ids)
            }
            return
        }
        let fallback = ClipboardPayload.from(pasteboard: NSPasteboard(name: .drag))
        Task {
            var result = await ingest.admitProviders(providers, capturePages: false)
            if result.admitted.isEmpty, fallback != .empty {
                result = ingest.admitPayload(fallback, capturePages: false)
            }
            follow(result)
            let ids = result.admitted.map(\.id)
            shelf.setSelection(Set(ids))
            finishExternalDrag()
            if ids.isEmpty { return }
            if hasAgent {
                sendToTUI(itemIDs: ids)
            } else {
                errorText = Copy.t("未发现终端 Agent。文件已留在架子上。", "No terminal agent found. Files stayed on the shelf.")
                aiTab = .work
            }
        }
    }

    func admitToTUI(urls: [URL]) {
        let result = ingest.admit(urls: urls, capturePages: false)
        follow(result)
        let ids = result.admitted.map(\.id)
        shelf.setSelection(Set(ids))
        if hasAgent {
            sendToTUI(itemIDs: ids)
        } else {
            errorText = Copy.t("未发现终端 Agent。文件已留在架子上。", "No terminal agent found. Files stayed on the shelf.")
            aiTab = .work
        }
    }

    func pasteFromClipboard(_ clipboard: any ClipboardReading = SystemClipboard()) {
        let payload = clipboard.read()
        if case .empty = payload {
            errorText = human(IngestError.emptyClipboard)
            return
        }
        let result = ingest.admitPayload(payload)
        if result.admitted.isEmpty {
            errorText = human(result.failures.first?.error ?? IngestError.unsupported)
            return
        }
        follow(result)
        aiTab = .work
    }

    func follow(_ result: AdmitResult) {
        if result.admitted.isEmpty == false {
            paneFocus = .input
            errorText = nil
        }
        note(result)
        refresh()
        followPageCaptures(result)
    }

    private func followPageCaptures(_ result: AdmitResult) {
        let ids = result.pageCaptureIDs
        guard ids.isEmpty == false else { return }
        Task {
            await ingest.captureDroppedPages(ids: ids)
            refresh()
        }
    }

    private func note(_ result: AdmitResult) {
        if let failure = result.failures.first, result.admitted.isEmpty {
            errorText = human(failure.error)
        } else if !result.failures.isEmpty {
            errorText = Copy.t(
                "有 \(result.failures.count) 项没能加入",
                "\(result.failures.count) items could not be added"
            )
        }
    }
}
