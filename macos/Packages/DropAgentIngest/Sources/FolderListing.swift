import Foundation

public enum FolderListing {
    public static let childLimit = 200
    public static let maxDepth = 8

    public struct Entry: Equatable, Identifiable, Sendable {
        public var url: URL
        public var name: String
        public var isDirectory: Bool

        public var id: String { url.path }

        public init(url: URL, name: String, isDirectory: Bool) {
            self.url = url
            self.name = name
            self.isDirectory = isDirectory
        }
    }

    public static func contains(_ url: URL, root: URL) -> Bool {
        let file = url.resolvingSymlinksInPath().standardizedFileURL.path
        let base = root.resolvingSymlinksInPath().standardizedFileURL.path
        if file == base { return true }
        return OwnedCopy.isInside(url, root: root)
    }

    public static func children(of url: URL, stayingInside root: URL, limit: Int = childLimit) -> [Entry] {
        guard contains(url, root: root) else { return [] }
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        let found = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []
        var entries: [Entry] = []
        for child in found {
            let name = child.lastPathComponent
            if name.hasPrefix(".") { continue }
            guard let resolved = resolve(child, stayingInside: root) else { continue }
            entries.append(Entry(url: resolved.url, name: name, isDirectory: resolved.isDirectory))
        }
        entries.sort { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && rhs.isDirectory == false }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        if entries.count > limit {
            return Array(entries.prefix(limit))
        }
        return entries
    }

    public static func firstFile(in url: URL, stayingInside root: URL, depth: Int = 4) -> URL? {
        let kids = children(of: url, stayingInside: root)
        if let file = kids.first(where: { $0.isDirectory == false }) {
            return file.url
        }
        guard depth > 0 else { return nil }
        for dir in kids where dir.isDirectory {
            if let found = firstFile(in: dir.url, stayingInside: root, depth: depth - 1) {
                return found
            }
        }
        return nil
    }

    public static func extraCount(of url: URL, stayingInside root: URL, limit: Int = childLimit) -> Int {
        guard contains(url, root: root) else { return 0 }
        let found = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        let visible = found.filter { $0.lastPathComponent.hasPrefix(".") == false }.count
        return max(0, visible - limit)
    }

    private static func resolve(_ url: URL, stayingInside root: URL) -> (url: URL, isDirectory: Bool)? {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let destination: URL
        if values?.isSymbolicLink == true {
            destination = url.resolvingSymlinksInPath()
        } else {
            destination = url
        }
        guard contains(destination, root: root) else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDir) else {
            return nil
        }
        return (destination, isDir.boolValue)
    }
}
