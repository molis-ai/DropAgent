import DropAgentCapture
import DropAgentShelf
import Foundation

struct PageAdmitOutcome {
    var item: Item
    var needsPageCapture: Bool
}

extension IngestService {
    public func captureDroppedPages(ids: [ItemID]) async {
        for id in ids {
            await fillDroppedPage(id: id)
        }
    }

    public func admitCurrentPage(token: PageAdmitToken? = nil) async throws -> Item {
        let captured: PageCapture
        do {
            captured = try await capture.captureFrontBrowser(target: token?.browser)
        } catch CaptureError.unsupportedBrowser {
            throw IngestError.captureFailed
        } catch {
            throw IngestError.captureFailed
        }
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        let parts = try writeCapturedPage(folder: folder, captured: captured)
        let item = Item(
            id: id,
            kind: .web,
            title: captured.title,
            sourceURL: captured.url,
            parts: parts,
            event: captured.failures.map(\.rawValue).joined(separator: " · ")
        )
        return try shelf.add(item)
    }

    func admitPageStub(url: URL) throws -> Item {
        let id = ItemID()
        let folder = inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent("url.txt")
        try writeTextFile(dest, url.absoluteString)
        let item = Item(
            id: id,
            kind: .web,
            title: url.host ?? url.absoluteString,
            sourceURL: url,
            parts: [ItemPart(name: "url.txt", url: dest)],
            event: Self.pageCapturePendingEvent
        )
        return try shelf.add(item)
    }

    func fillDroppedPage(id: ItemID) async {
        guard let item = shelf.item(id: id), item.kind == .web, Self.isHTTP(item.sourceURL) else { return }
        let captured = await capture.captureURL(item.sourceURL)
        guard shelf.item(id: id) != nil else { return }
        let folder = item.parts.first?.url.deletingLastPathComponent()
            ?? inboxRoot.appendingPathComponent(id.rawValue, isDirectory: true)
        do {
            let parts = try writeCapturedPage(folder: folder, captured: captured)
            try shelf.patch(id: id) { live in
                live.title = captured.title
                live.sourceURL = captured.url
                live.parts = parts
                live.event = captured.failures.map(\.rawValue).joined(separator: " · ")
            }
        } catch {
            try? shelf.patch(id: id) { live in
                if live.event == Self.pageCapturePendingEvent {
                    live.event = CaptureFailure.network.rawValue
                }
            }
        }
    }

    func writeCapturedPage(folder: URL, captured: PageCapture) throws -> [ItemPart] {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var parts: [ItemPart] = []
        let urlFile = folder.appendingPathComponent("url.txt")
        try writeTextFile(urlFile, captured.url.absoluteString)
        parts.append(ItemPart(name: "url.txt", url: urlFile))
        if let markdown = captured.markdown {
            let file = folder.appendingPathComponent("page.md")
            try writeTextFile(file, markdown)
            parts.append(ItemPart(name: "page.md", url: file))
        }
        if let png = captured.snapshotPNG {
            let file = folder.appendingPathComponent("snapshot.png")
            try png.write(to: file)
            parts.append(ItemPart(name: "snapshot.png", url: file))
        }
        return parts
    }

    func writeTextFile(_ url: URL, _ text: String) throws {
        try writeTextFile(url, Data(text.utf8))
    }

    func writeTextFile(_ url: URL, _ data: Data) throws {
        var data = data
        if data.isEmpty == false, data.last != 0x0A {
            data.append(0x0A)
        }
        try data.write(to: url)
    }
}
