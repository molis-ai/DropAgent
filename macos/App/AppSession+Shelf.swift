import DropAgentIngest
import DropAgentJob
import DropAgentShelf
import Foundation
import AppKit

extension AppSession {
    var runningItems: [Item] { shelf.items().filter { $0.status == .running } }

    func openTab(_ tab: AITab) {
        onPanelInteraction?()
        NSApp.keyWindow?.makeFirstResponder(nil)
        if tab == .work { paneFocus = .input }
        if tab == .result, currentResult() == nil, let first = results.first {
            selectResult(first.id)
            return
        }
        aiTab = tab
    }

    func showRunningJob() {
        onPanelInteraction?()
        let ids = Set(runningItems.map(\.id))
        guard !ids.isEmpty else { return }
        shelf.setSelection(ids)
        paneFocus = .input
        aiTab = .work
        refresh()
    }

    func selectMaterial(_ id: ItemID, extending: Bool = false) {
        onPanelInteraction?()
        stopStageEdit()
        NSApp.keyWindow?.makeFirstResponder(nil)
        let wasInput = paneFocus == .input
        paneFocus = .input
        comparingResult = false
        folderPreviewURL = nil
        if extending && wasInput { shelf.toggleSelect(id: id, command: true) }
        else { shelf.setSelection([id]) }
        aiTab = .work
        refresh()
    }

    func toggleSelect(id: ItemID, command: Bool) {
        comparingResult = false
        folderPreviewURL = nil
        onPanelInteraction?()
        stopStageEdit()
        NSApp.keyWindow?.makeFirstResponder(nil)
        if command {
            paneFocus = .input
            shelf.toggleSelect(id: id, command: true)
            return
        }
        if paneFocus != .input {
            paneFocus = .input
            shelf.setSelection([id])
        } else {
            paneFocus = .input
            shelf.toggleSelect(id: id, command: false)
            if selectedItems.isEmpty { return }
        }
        if let item = shelf.item(id: id) {
            if item.status == .done || item.status == .failed { aiTab = .work }
            else if item.status == .sent {
                aiTab = canOpenTerminalTab ? .tty : .work
                if canOpenTerminalTab { otherOpen = true }
            } else { aiTab = .work }
        }
    }

    func selectResult(_ id: ResultID) {
        onPanelInteraction?()
        stopStageEdit()
        NSApp.keyWindow?.makeFirstResponder(nil)
        if selectedResultID != id { comparisonSourceID = nil }
        selectedResultID = id
        paneFocus = .result
        aiTab = .work
    }

    func toggleResult(_ id: ResultID) {
        onPanelInteraction?()
        stopStageEdit()
        NSApp.keyWindow?.makeFirstResponder(nil)
        if paneFocus == .result, selectedResultID == id {
            selectedResultID = nil
            paneFocus = .input
            return
        }
        if selectedResultID != id { comparisonSourceID = nil }
        selectedResultID = id
        paneFocus = .result
        aiTab = .work
    }

    func openItem(_ item: Item) {
        onPanelInteraction?()
        guard let url = openURL(for: item) else {
            errorText = Copy.t("打不开这个文件。", "This file cannot be opened.")
            return
        }
        if NSWorkspace.shared.open(url) == false {
            errorText = Copy.t("打不开这个文件。", "This file cannot be opened.")
        }
    }

    func openURL(for item: Item) -> URL? {
        if let output = item.output {
            return existingFile(output)
        }
        if item.kind == .url || item.kind == .web {
            return SourceLink.isOpenable(item.sourceURL) ? item.sourceURL : nil
        }
        if let part = item.parts.first, let file = existingFile(part.url) {
            return file
        }
        if let file = existingFile(item.sourceURL) {
            return file
        }
        return SourceLink.isOpenable(item.sourceURL) ? item.sourceURL : nil
    }

    private func existingFile(_ url: URL) -> URL? {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    func reselectResultSources(_ record: ResultRecord) {
        stopStageEdit()
        comparingResult = false
        folderPreviewURL = nil
        let ids = Set(record.sourceItemIDs.filter { shelf.item(id: $0) != nil })
        guard !ids.isEmpty else {
            errorText = Copy.t("原材料已不在架子上，请重新添加。", "The source materials are no longer on the shelf. Add them again.")
            return
        }
        shelf.setSelection(ids)
        paneFocus = .input
        aiTab = .work
        errorText = nil
        refresh()
    }

    func removeResult(_ id: ResultID) {
        hideResult(id)
    }

    func hideResult(_ id: ResultID) {
        stopStageEdit()
        comparisonSourceID = nil
        let index = results.firstIndex(where: { $0.id == id }) ?? 0
        shelf.removeResults(ids: [id])
        if selectedResultID == id {
            let remaining = shelf.results()
            if !remaining.isEmpty {
                selectedResultID = remaining[min(index, remaining.count - 1)].id
            } else {
                selectedResultID = nil
                if paneFocus == .result {
                    paneFocus = .input
                    aiTab = .work
                }
            }
        }
        refresh()
    }

    func deleteResult(_ id: ResultID) {
        if let record = shelf.result(id: id) {
            job.deleteOwnedOutput(record)
        }
        hideResult(id)
    }

    func remove(id: ItemID) {
        hideItem(id)
    }

    func hideItem(_ id: ItemID) {
        flushStageEdit()
        guard let item = shelf.item(id: id), item.status != .running else { return }
        try? shelf.remove(ids: [id])
        refresh()
    }

    func deleteItem(_ id: ItemID) {
        flushStageEdit()
        guard let item = shelf.item(id: id), item.status != .running else { return }
        try? ingest.deleteOwnedCopy(item)
        refresh()
    }

    func removeSelected() {
        if paneFocus == .clipboard {
            for id in clipSelection { deleteClip(id) }
            return
        }
        if paneFocus == .result, let id = selectedResultID {
            removeResult(id)
            return
        }
        let ids = selectedItems.filter { $0.status != .running }.map(\.id)
        guard !ids.isEmpty else { return }
        try? shelf.remove(ids: ids)
        refresh()
    }

    func moveSelection(offset: Int) {
        stopStageEdit()
        if paneFocus == .clipboard {
            guard !clipRecords.isEmpty else { return }
            let current = clipRecords.firstIndex { clipSelection.contains($0.id) } ?? -1
            selectClipboard(clipRecords[min(clipRecords.count - 1, max(0, current + offset))].id)
            return
        }
        if paneFocus == .result, results.isEmpty == false {
            let current = results.firstIndex(where: { $0.id == selectedResultID }) ?? (offset > 0 ? -1 : results.count)
            let index = min(results.count - 1, max(0, current + offset))
            selectResult(results[index].id)
            return
        }
        paneFocus = .input
        comparingResult = false
        folderPreviewURL = nil
        shelf.moveSelection(offset: offset)
        if let item = selectedItems.first {
            if item.status == .sent, canOpenTerminalTab {
                aiTab = .tty
                otherOpen = true
            } else {
                aiTab = .work
            }
        }
    }

    func currentResult() -> Item? {
        guard paneFocus != .clipboard else { return nil }
        if paneFocus == .result, let record = selectedResult {
            return record.takeawayItem()
        }
        return selectedItems.first { $0.status == .done || $0.status == .failed }
            ?? selectedItems.first { $0.status == .sent }
            ?? selectedItems.first
    }
}
