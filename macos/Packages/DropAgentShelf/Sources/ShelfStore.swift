import Foundation

public enum ShelfError: Error, Equatable, Sendable {
    case emptyParts
    case missingItem
    case runningLocked
}

private struct ShelfDocument: Codable {
    var items: [Item]
    var results: [ResultRecord]
}

public final class ShelfStore: @unchecked Sendable {
    private let lock = NSLock()
    private var ordered: [Item] = []
    private var artifacts: [ResultRecord] = []
    private var selectionIDs: Set<ItemID> = []
    private let fileURL: URL
    public var onChange: (@Sendable () -> Void)?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func items() -> [Item] {
        lock.lock()
        defer { lock.unlock() }
        return ordered
    }

    public func results() -> [ResultRecord] {
        lock.lock()
        defer { lock.unlock() }
        return artifacts
    }

    public func result(id: ResultID) -> ResultRecord? {
        lock.lock()
        defer { lock.unlock() }
        return artifacts.first { $0.id == id }
    }

    public func item(id: ItemID) -> Item? {
        lock.lock()
        defer { lock.unlock() }
        return ordered.first { $0.id == id }
    }

    public var selection: Set<ItemID> {
        lock.lock()
        defer { lock.unlock() }
        return selectionIDs
    }

    public func selectedItems() -> [Item] {
        lock.lock()
        defer { lock.unlock() }
        return ordered.filter { selectionIDs.contains($0.id) }
    }

    @discardableResult
    public func add(_ item: Item) throws -> Item {
        guard !item.parts.isEmpty else { throw ShelfError.emptyParts }
        lock.lock()
        ordered.insert(item, at: 0)
        selectionIDs = [item.id]
        lock.unlock()
        persist()
        notify()
        return item
    }

    public func remove(ids: [ItemID]) throws {
        lock.lock()
        for id in ids {
            if let existing = ordered.first(where: { $0.id == id }), existing.status == .running {
                lock.unlock()
                throw ShelfError.runningLocked
            }
        }
        ordered.removeAll { ids.contains($0.id) }
        selectionIDs.subtract(ids)
        lock.unlock()
        persist()
        notify()
    }

    @discardableResult
    public func addResult(_ record: ResultRecord) -> ResultRecord {
        lock.lock()
        artifacts.insert(record, at: 0)
        lock.unlock()
        persist()
        notify()
        return record
    }

    public func removeResults(ids: [ResultID]) {
        lock.lock()
        artifacts.removeAll { ids.contains($0.id) }
        lock.unlock()
        persist()
        notify()
    }

    public func patchResult(id: ResultID, mutate: (inout ResultRecord) -> Void) {
        lock.lock()
        guard let index = artifacts.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            return
        }
        mutate(&artifacts[index])
        lock.unlock()
        persist()
        notify()
    }

    public func patch(id: ItemID, mutate: (inout Item) -> Void) throws {
        lock.lock()
        guard let index = ordered.firstIndex(where: { $0.id == id }) else {
            lock.unlock()
            throw ShelfError.missingItem
        }
        mutate(&ordered[index])
        lock.unlock()
        persist()
        notify()
    }

    public func toggleSelect(id: ItemID, command: Bool) {
        lock.lock()
        if command {
            if selectionIDs.contains(id) {
                selectionIDs.remove(id)
            } else {
                selectionIDs.insert(id)
            }
        } else if selectionIDs.count == 1, selectionIDs.contains(id) {
            selectionIDs = []
        } else {
            selectionIDs = [id]
        }
        lock.unlock()
        notify()
    }

    public func setSelection(_ ids: Set<ItemID>) {
        lock.lock()
        selectionIDs = ids
        lock.unlock()
        notify()
    }

    public func moveSelection(offset: Int) {
        lock.lock()
        defer {
            lock.unlock()
            notify()
        }
        guard !ordered.isEmpty else {
            selectionIDs = []
            return
        }
        let current = ordered.firstIndex { selectionIDs.contains($0.id) } ?? (offset > 0 ? -1 : ordered.count)
        let next = min(max(current + offset, 0), ordered.count - 1)
        selectionIDs = [ordered[next].id]
    }

    public func load() {
        lock.lock()
        defer { lock.unlock() }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            ordered = []
            artifacts = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            if let document = try? JSONDecoder().decode(ShelfDocument.self, from: data) {
                ordered = document.items
                artifacts = document.results
            } else {
                ordered = try JSONDecoder().decode([Item].self, from: data)
                artifacts = []
            }
        } catch {
            ordered = []
            artifacts = []
        }
        selectionIDs = []
    }

    public func persist() {
        lock.lock()
        let document = ShelfDocument(items: ordered, results: artifacts)
        let url = fileURL
        lock.unlock()
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(document)
            try data.write(to: url, options: .atomic)
        } catch {
            // Persistence is best-effort; the in-memory shelf remains the source of truth.
        }
    }

    private func notify() {
        onChange?()
    }
}
