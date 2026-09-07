import DropAgentShelf
import Foundation

public enum OwnedCopy {
    public static func isInside(_ url: URL, root: URL) -> Bool {
        let file = url.resolvingSymlinksInPath().standardizedFileURL.path
        let base = root.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return file.hasPrefix(prefix)
    }

    public static func removeIfInside(_ url: URL, root: URL) {
        guard isInside(url, root: root) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public static func deleteInboxCopy(_ item: Item, inboxRoot: URL) {
        removeIfInside(inboxRoot.appendingPathComponent(item.id.rawValue, isDirectory: true), root: inboxRoot)
        for part in item.parts {
            removeIfInside(part.url, root: inboxRoot)
            removeIfInside(part.url.deletingLastPathComponent(), root: inboxRoot)
        }
    }
}
