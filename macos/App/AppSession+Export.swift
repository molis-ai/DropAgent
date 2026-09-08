import AppKit
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
        guard let item = selectedItems.first, item.status != .running else { return }
        copyItem(item)
    }

    func copyItem(_ item: Item, to pasteboard: NSPasteboard = .general) {
        PasteboardService.copy(item, to: pasteboard)
        copiedID = item.id
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedID == item.id { copiedID = nil }
        }
    }
}
