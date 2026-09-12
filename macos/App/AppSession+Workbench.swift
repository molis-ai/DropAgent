import AppKit
import DropAgentPasteboard
import DropAgentIngest
import DropAgentShelf

extension AppSession {
    var selectedClipboard: ClipRecord? { clipRecords.first { clipSelection.contains($0.id) } }

    var shelfQuery: String {
        spotlight.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matchesShelfQuery(_ title: String) -> Bool {
        let query = shelfQuery
        if query.isEmpty { return true }
        return title.localizedStandardContains(query)
    }

    var visibleItems: [Item] { items.filter { matchesShelfQuery($0.title) } }
    var visibleResults: [ResultRecord] { results.filter { matchesShelfQuery($0.title) } }
    var visibleClips: [ClipRecord] { clipRecords.filter { matchesShelfQuery($0.title) } }

    func selectClipboard(_ id: ClipID, extending: Bool = false) {
        onPanelInteraction?()
        resignStageEditor()
        let wasClipboard = paneFocus == .clipboard
        paneFocus = .clipboard
        comparingResult = false
        if extending && wasClipboard { toggleClipSelect(id: id, command: true) }
        else { clipSelection = [id] }
        syncConfirmDrafts()
        refresh()
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
