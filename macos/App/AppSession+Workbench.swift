import AppKit
import DropAgentPasteboard
import DropAgentIngest
import DropAgentShelf

extension AppSession {
    var selectedClipboard: ClipRecord? { clipRecords.first { clipSelection.contains($0.id) } }

    func selectClipboard(_ id: ClipID, extending: Bool = false) {
        onPanelInteraction?()
        stopStageEdit()
        NSApp.keyWindow?.makeFirstResponder(nil)
        let wasClipboard = paneFocus == .clipboard
        paneFocus = .clipboard
        comparingResult = false
        if extending && wasClipboard { toggleClipSelect(id: id, command: true) }
        else { clipSelection = [id] }
    }

    func admitSelectedClips() {
        let records = clipRecords.filter { clipSelection.contains($0.id) }
        guard !records.isEmpty else { return }
        var admitted: [Item] = []
        var admissionFailure: String?
        for record in records {
            guard let payload = clipboardPayload(for: record) else {
                admissionFailure = Copy.t("「\(record.title)」的文件或图片已经不在了。", "The file or image for “\(record.title)” is no longer available.")
                continue
            }
            let result = ingest.admitPayload(payload)
            follow(result)
            if !result.failures.isEmpty { admissionFailure = errorText }
            admitted.append(contentsOf: result.admitted)
        }
        if !admitted.isEmpty {
            stopStageEdit()
            shelf.setSelection(Set(admitted.map(\.id)))
            paneFocus = .input
            aiTab = .work
            comparingResult = false
            refresh()
        }
        if let admissionFailure { errorText = admissionFailure }
    }

    var comparisonSources: [Item] { selectedResult?.sourceItemIDs.compactMap { shelf.item(id: $0) } ?? [] }
    var comparisonSource: Item? { comparisonSources.first { $0.id == comparisonSourceID } ?? comparisonSources.first }

    func toggleComparison() {
        stopStageEdit()
        comparingResult.toggle()
        if comparisonSourceID == nil { comparisonSourceID = comparisonSources.first?.id }
    }
}
