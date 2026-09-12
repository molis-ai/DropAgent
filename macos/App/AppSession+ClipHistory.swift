import AppKit
import DropAgentIngest
import DropAgentPasteboard
import Foundation

extension AppSession {
    func refreshClips() {
        clipRecords = clipHistory.records()
        clipSelection.formIntersection(Set(clipRecords.map(\.id)))
        if clipHistoryOpen {
            clipMenu.relayout()
        }
    }

    func toggleClipHistory(anchor: CGRect = .zero) {
        onPanelInteraction?()
        if clipHistoryOpen {
            closeClipHistory()
            return
        }
        if spotlight.isActive {
            spotlight.setText("")
        }
        clipHistoryOpen = true
        notePasteboard()
        refreshClips()
        clipMenu.show(session: self, anchor: anchor)
    }

    func closeClipHistory() {
        clipHistoryOpen = false
        clipMultiSelect = false
        if paneFocus != .clipboard { clipSelection = [] }
        clipDragging = false
        clipMenu.hide()
    }

    func setClipMultiSelect(_ on: Bool) {
        clipMultiSelect = on
        if on == false, clipSelection.count > 1 {
            if let first = clipRecords.first(where: { clipSelection.contains($0.id) }) {
                clipSelection = [first.id]
            }
        }
    }

    func toggleClipSelect(id: ClipID, command: Bool) {
        onPanelInteraction?()
        if command || clipMultiSelect {
            if clipSelection.contains(id) {
                clipSelection.remove(id)
            } else {
                clipSelection.insert(id)
            }
        } else if clipSelection == [id] {
            clipSelection = []
        } else {
            clipSelection = [id]
        }
        if clipHistoryOpen {
            clipMenu.relayout()
        }
    }

    func deleteClip(_ id: ClipID) {
        clipSelection.remove(id)
        clipHistory.remove(id: id)
        refreshClips()
    }

    func makeClipCurrent(_ id: ClipID, on pasteboard: NSPasteboard = .general) {
        onPanelInteraction?()
        guard let record = clipRecords.first(where: { $0.id == id }) else { return }
        guard record.filesMissing == false else { return }
        guard let payload = clipboardPayload(for: record) else { return }
        pasteboard.clearContents()
        switch payload {
        case .empty:
            return
        case .text(let text):
            pasteboard.setString(text, forType: .string)
            if ClipDraft.isHTTPURL(text), let url = URL(string: text) {
                pasteboard.writeObjects([url as NSURL])
            }
        case .image(let data):
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
            pasteboard.setData(data, forType: .png)
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
            if urls.count > 1 {
                pasteboard.setPropertyList(
                    urls.map(\.path),
                    forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
                )
            }
        }
        notePasteboard(pasteboard, stageFiles: false)
        if clipSelection.contains(id) == false {
            clipSelection = [id]
        }
        if clipHistoryOpen {
            clipMenu.relayout()
        }
    }

    func clipDragGroup(starting id: ClipID) -> [ClipRecord] {
        let selected = clipRecords.filter { clipSelection.contains($0.id) && $0.filesMissing == false }
        if selected.contains(where: { $0.id == id }), selected.count > 1 {
            return selected
        }
        return clipRecords.filter { $0.id == id && $0.filesMissing == false }
    }

    func beginClipDrag(starting id: ClipID) -> NSItemProvider {
        clipDragging = true
        if clipSelection.contains(id) == false {
            clipSelection = [id]
        }
        let group = clipDragGroup(starting: id)
        if group.count > 1 {
            let urls = clipDragFileURLs(group)
            DispatchQueue.main.async {
                if urls.count > 1 {
                    PasteboardService.attachFileListToDragPasteboard(urls)
                }
            }
            if urls.count > 1 {
                return PasteboardService.itemProvider(forClipFiles: urls)
            }
        }
        guard let first = group.first else { return NSItemProvider() }
        return PasteboardService.itemProvider(forClip: first, imageURL: clipHistory.imageURL(for: first.id))
    }

    func endClipDrag() {
        clipDragging = false
    }

    private func clipDragFileURLs(_ records: [ClipRecord]) -> [URL] {
        let folder = DropAgentPaths.clipboard.appendingPathComponent("drag", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var urls: [URL] = []
        for record in records {
            switch record.kind {
            case .files:
                urls.append(
                    contentsOf: record.filePaths
                        .map { URL(fileURLWithPath: $0) }
                        .filter { FileManager.default.fileExists(atPath: $0.path) }
                )
            case .image:
                if let url = clipHistory.imageURL(for: record.id) {
                    urls.append(url)
                }
            case .text, .url:
                guard let text = record.text else { continue }
                let file = folder.appendingPathComponent("\(record.id.rawValue).txt")
                try? Data(text.utf8).write(to: file)
                urls.append(file)
            }
        }
        return urls
    }

    func startClipWatch() {
        clipWatchTask?.cancel()
        lastPasteboardChange = Int.min
        clipWatchTask = Task { @MainActor [weak self] in
            self?.notePasteboard()
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard let self else { return }
                self.notePasteboard()
            }
        }
    }

    func notePasteboard(_ pasteboard: NSPasteboard = .general, stageFiles: Bool = true) {
        let change = pasteboard.changeCount
        let isGeneral = pasteboard.name == .general
        if isGeneral {
            if change == lastPasteboardChange { return }
            lastPasteboardChange = change
        }
        if ClipPasteboard.isIgnored(pasteboard) {
            if isGeneral { currentClipFingerprint = nil }
            return
        }
        let payload = ClipboardPayload.from(pasteboard: pasteboard)
        let toStage = ClipboardStaging.filesToAdmit(
            payload: payload,
            inboxRoot: DropAgentPaths.inbox,
            jobsRoot: DropAgentPaths.jobs,
            suppress: stageFiles == false || isAdmittingFiles
        )
        if toStage.isEmpty == false {
            let result = ingest.admit(urls: toStage)
            follow(result)
            if result.admitted.isEmpty == false {
                shelf.setSelection(Set(result.admitted.map(\.id)))
            }
            if isGeneral { currentClipFingerprint = nil }
            refreshClips()
            return
        }
        if isAdmittingFiles, case .files = payload {
            if isGeneral { currentClipFingerprint = nil }
            return
        }
        guard let draft = clipDraft(from: payload) else {
            if isGeneral { currentClipFingerprint = nil }
            return
        }
        currentClipFingerprint = draft.fingerprint
        clipHistory.record(draft)
        refreshClips()
    }

    func clipDraft(from payload: ClipboardPayload) -> ClipDraft? {
        switch payload {
        case .empty:
            return nil
        case .text(let text):
            if ClipDraft.isHTTPURL(text) {
                return ClipDraft(kind: .url, title: ClipDraft.titleForURL(text), text: text)
            }
            return ClipDraft(kind: .text, title: ClipDraft.titleForText(text), text: text)
        case .image(let data):
            return ClipDraft(kind: .image, title: Copy.t("图片", "Image"), imagePNG: data)
        case .files(let urls):
            let paths = urls.map(\.path)
            return ClipDraft(kind: .files, title: ClipDraft.titleForFiles(paths), filePaths: paths)
        }
    }

    func clipboardPayload(for record: ClipRecord) -> ClipboardPayload? {
        switch record.kind {
        case .text, .url:
            guard let text = record.text, text.isEmpty == false else { return nil }
            return .text(text)
        case .image:
            guard let data = clipHistory.imageData(for: record.id) else { return nil }
            return .image(data)
        case .files:
            guard record.filesMissing == false else { return nil }
            return .files(record.filePaths.map { URL(fileURLWithPath: $0) })
        }
    }
}
