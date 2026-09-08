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
        if !prefs.showWork { setShowWork(true) }
        refresh()
    }

    func toggleSelect(id: ItemID, command: Bool) {
        onPanelInteraction?()
        NSApp.keyWindow?.makeFirstResponder(nil)
        paneFocus = .input
        shelf.toggleSelect(id: id, command: command)
        if command { return }
        if let item = shelf.item(id: id) {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = canOpenTerminalTab ? .tty : .work }
            else { aiTab = .work }
        }
    }

    func selectResult(_ id: ResultID) {
        onPanelInteraction?()
        NSApp.keyWindow?.makeFirstResponder(nil)
        selectedResultID = id
        paneFocus = .result
        aiTab = .result
        if prefs.showWork == false {
            setShowWork(true)
        }
    }

    func reselectResultSources(_ record: ResultRecord) {
        let ids = Set(record.sourceItemIDs.filter { shelf.item(id: $0) != nil })
        guard !ids.isEmpty else {
            errorText = Copy.t("原材料已不在架子上，请重新添加。", "The source materials are no longer on the shelf. Add them again.")
            return
        }
        shelf.setSelection(ids)
        paneFocus = .input
        aiTab = .work
        if !prefs.showWork { setShowWork(true) }
        errorText = nil
        refresh()
    }

    func removeResult(_ id: ResultID) {
        hideResult(id)
    }

    func hideResult(_ id: ResultID) {
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
        guard let item = shelf.item(id: id), item.status != .running else { return }
        try? shelf.remove(ids: [id])
        refresh()
    }

    func deleteItem(_ id: ItemID) {
        guard let item = shelf.item(id: id), item.status != .running else { return }
        try? ingest.deleteOwnedCopy(item)
        refresh()
    }

    func removeSelected() {
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
        if paneFocus == .result, results.isEmpty == false {
            let current = results.firstIndex(where: { $0.id == selectedResultID }) ?? (offset > 0 ? -1 : results.count)
            let index = min(results.count - 1, max(0, current + offset))
            selectResult(results[index].id)
            return
        }
        paneFocus = .input
        shelf.moveSelection(offset: offset)
        if let item = selectedItems.first {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = canOpenTerminalTab ? .tty : .work }
            else { aiTab = .work }
        }
    }

    func currentResult() -> Item? {
        if paneFocus == .result, let record = selectedResult {
            return record.takeawayItem()
        }
        return selectedItems.first { $0.status == .done || $0.status == .failed }
            ?? selectedItems.first { $0.status == .sent }
            ?? selectedItems.first
    }
}
