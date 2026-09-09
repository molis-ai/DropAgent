import AppKit
import DropAgentIngest
import DropAgentPasteboard
import DropAgentShelf
import Foundation

extension AppSession {
    func copySelected() {
        if paneFocus == .result, let record = selectedResult {
            guard record.output != nil else { return }
            copyItem(record.takeawayItem())
            return
        }
        let group = selectedItems.filter { $0.status != .running }
        guard group.isEmpty == false else { return }
        if group.count == 1 {
            copyItem(group[0])
            return
        }
        PasteboardService.copy(group)
        notePasteboard()
        copiedID = group[0].id
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedID == group[0].id { copiedID = nil }
        }
    }

    func copyItem(_ item: Item, to pasteboard: NSPasteboard = .general) {
        PasteboardService.copy(item, to: pasteboard)
        if pasteboard.name == .general {
            notePasteboard(pasteboard)
        }
        copiedID = item.id
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedID == item.id { copiedID = nil }
        }
    }

    func importSelectedResults() {
        onPanelInteraction?()
        let urls: [URL]
        if paneFocus == .result, let file = selectedResult?.output {
            urls = [file]
        } else {
            urls = results.compactMap { record in
                record.id == selectedResultID ? record.output : nil
            }
        }
        guard urls.isEmpty == false else { return }
        follow(ingest.admit(urls: urls, capturePages: false))
        paneFocus = .input
        aiTab = .work
    }
}
