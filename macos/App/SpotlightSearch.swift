import AppKit
import Foundation

struct SpotlightHit: Identifiable, Equatable {
    var id: String { path }
    var url: URL
    var name: String
    var path: String
    var folder: Bool
}

@MainActor
final class SpotlightSearch: ObservableObject {
    @Published var text = ""
    @Published var hits: [SpotlightHit] = []
    @Published var gathering = false

    private var debounce: Task<Void, Never>?
    private var generation = 0

    var isActive: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    func setText(_ value: String) {
        text = value
        debounce?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            generation += 1
            hits = []
            gathering = false
            return
        }
        debounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard Task.isCancelled == false else { return }
            start(trimmed)
        }
    }

    func stop() {
        debounce?.cancel()
        debounce = nil
        generation += 1
        hits = []
        gathering = false
    }

    nonisolated static func spotlightQuery(for raw: String) -> String {
        let escaped = raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "kMDItemDisplayName == \"*\(escaped)*\"cd || kMDItemFSName == \"*\(escaped)*\"cd"
    }

    nonisolated static func collect(query: String, roots: [URL], limit: Int = 24) -> [SpotlightHit] {
        var byPath: [String: SpotlightHit] = [:]
        for path in mdfindPaths(query: query) {
            if let hit = hit(fromPath: path) {
                byPath[hit.path] = hit
            }
            if byPath.count >= limit { break }
        }
        if byPath.count < limit {
            for hit in walk(query: query, roots: roots, limit: limit) {
                byPath[hit.path] = hit
                if byPath.count >= limit { break }
            }
        }
        let needle = normalize(query)
        return byPath.values.sorted { lhs, rhs in
            let lName = normalize(lhs.name)
            let rName = normalize(rhs.name)
            let lStart = lName.hasPrefix(needle)
            let rStart = rName.hasPrefix(needle)
            if lStart != rStart { return lStart && !rStart }
            if lhs.name.count != rhs.name.count { return lhs.name.count < rhs.name.count }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func start(_ raw: String) {
        generation += 1
        let gen = generation
        gathering = true
        let roots = Self.defaultRoots()
        Task.detached(priority: .userInitiated) {
            let found = SpotlightSearch.collect(query: raw, roots: roots)
            await MainActor.run {
                guard self.generation == gen else { return }
                self.hits = found
                self.gathering = false
            }
        }
    }

    nonisolated static func defaultRoots() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var roots = ["Desktop", "Documents", "Downloads", "Pictures", "Movies"].map {
            home.appendingPathComponent($0, isDirectory: true)
        }
        let iCloud = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        roots.append(iCloud)
        return roots.filter { fm.fileExists(atPath: $0.path) }
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    nonisolated private static func mdfindPaths(query: String) -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", home, spotlightQuery(for: query)]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return []
        }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return [] }
        return String(data: data, encoding: .utf8)?
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { $0.isEmpty == false } ?? []
    }

    nonisolated private static let skipNames: Set<String> = [
        "Library", "node_modules", ".git", ".build", "DerivedData",
        "Pods", ".Trash", "Application Support", "Containers",
    ]

    nonisolated private static func walk(query: String, roots: [URL], limit: Int) -> [SpotlightHit] {
        let fm = FileManager.default
        let needle = normalize(query)
        var hits: [SpotlightHit] = []
        for root in roots {
            guard hits.count < limit else { break }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            let rootCount = root.pathComponents.count
            while let url = enumerator.nextObject() as? URL {
                if hits.count >= limit { break }
                let name = url.lastPathComponent
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                let isDir = values?.isDirectory == true
                if isDir, skipNames.contains(name) {
                    enumerator.skipDescendants()
                    continue
                }
                let depth = url.pathComponents.count - rootCount
                if depth > 6 {
                    if isDir { enumerator.skipDescendants() }
                    continue
                }
                if normalize(name).contains(needle) {
                    hits.append(
                        SpotlightHit(url: url, name: name, path: url.path, folder: isDir)
                    )
                }
            }
        }
        return hits
    }

    nonisolated static func hit(fromPath path: String) -> SpotlightHit? {
        if path.contains("/.Trash/") || path.contains("/.Trashes/") { return nil }
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
        return SpotlightHit(url: url, name: name, path: path, folder: isDir.boolValue)
    }
}
