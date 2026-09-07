import AppKit
import DropAgentIngest
import DropAgentShelf
import Foundation

extension AppSession {
    func admit(urls: [URL]) {
        follow(ingest.admit(urls: urls))
        aiTab = .work
        finishExternalDrag()
    }

    func pickFilesToAdmit() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = Copy.t("加入", "Add")
        panel.message = Copy.t("选择要放到架子上的文件或文件夹。原件不动。", "Choose files or folders to put on the shelf. Originals stay put.")
        let urls = OpenPanelHost.run(panel)
        guard urls.isEmpty == false else { return }
        admit(urls: urls)
    }

    func admitSpotlight(_ hit: SpotlightHit) {
        admit(urls: [hit.url])
        spotlight.setText("")
    }

    func admitDrop(providers: [NSItemProvider]) {
        let now = Date()
        if let last = lastInternalDropAt, now.timeIntervalSince(last) < 0.35 {
            return
        }
        lastInternalDropAt = now
        finishExternalDrag()
        Task {
            follow(await ingest.admitProviders(providers))
            aiTab = .work
        }
    }

    func admitPasteboard(_ pasteboard: NSPasteboard) {
        admitPayload(ClipboardPayload.from(pasteboard: pasteboard))
    }

    func admitPayload(_ payload: ClipboardPayload) {
        follow(ingest.admitPayload(payload))
        aiTab = .work
        finishExternalDrag()
    }

    func admitFromWheel(_ payload: ClipboardPayload, action: WheelAction) {
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
        finishExternalDrag()
        Task {
            let result = await ingest.admitProviders(providers, capturePages: false)
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
