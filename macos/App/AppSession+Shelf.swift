import DropAgentIngest
import DropAgentJob
import DropAgentShelf
import Foundation

extension AppSession {
    func toggleSelect(id: ItemID, command: Bool) {
        paneFocus = .input
        shelf.toggleSelect(id: id, command: command)
        if command { return }
        if let item = shelf.item(id: id) {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = .tty }
            else { aiTab = .work }
        }
    }

    func selectResult(_ id: ResultID) {
        selectedResultID = id
        paneFocus = .result
        aiTab = .result
    }

    func removeResult(_ id: ResultID) {
        hideResult(id)
    }

    func hideResult(_ id: ResultID) {
        shelf.removeResults(ids: [id])
        if selectedResultID == id {
            selectedResultID = nil
            paneFocus = .input
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
        paneFocus = .input
        shelf.moveSelection(offset: offset)
        if let item = selectedItems.first {
            if item.status == .done || item.status == .failed { aiTab = .result }
            else if item.status == .sent { aiTab = .tty }
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
