import DropAgentAgent
import DropAgentShelf
import Foundation

enum JobWorkspace {
    static func copyRegular(from source: URL, to dest: URL) throws {
        try FileManager.default.copyItem(at: source, to: dest)
        try stripSymlinks(at: dest)
    }

    static func stripSymlinks(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if (try url.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
            return
        }
        guard isDir.boolValue else { return }
        for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey]) {
            try stripSymlinks(at: child)
        }
    }

    static func freezeReadOnly(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        if isDir.boolValue {
            for child in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try freezeReadOnly(at: child)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: url.path)
        } else {
            try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: url.path)
        }
    }

    static func forceRemove(_ url: URL) {
        thaw(url)
        try? FileManager.default.removeItem(at: url)
    }

    private static func thaw(_ url: URL) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        try? FileManager.default.setAttributes(
            [.posixPermissions: isDir.boolValue ? 0o755 : 0o644],
            ofItemAtPath: url.path
        )
        guard isDir.boolValue else { return }
        let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []
        for child in children {
            thaw(child)
        }
    }

    static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        var dest = directory.appendingPathComponent(preferredName)
        var i = 2
        let base = dest.deletingPathExtension().lastPathComponent
        let ext = dest.pathExtension
        while FileManager.default.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base)-\(i)" : "\(base)-\(i).\(ext)"
            dest = directory.appendingPathComponent(name)
            i += 1
        }
        return dest
    }

    static func appendEvent(dir: URL, message: String) throws {
        let file = dir.appendingPathComponent("events.jsonl")
        let line = "{\"message\":\(jsonString(message))}\n"
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(line.utf8))
        } else {
            try Data(line.utf8).write(to: file)
        }
    }

    static func writeManifest(
        dir: URL,
        jobID: JobID,
        recipe: RecipeID,
        agent: String,
        isolation: IsolationGrade,
        items: [Item]
    ) throws {
        let listed: [[String: Any]] = items.map { item in
            var row: [String: Any] = [
                "id": item.id.rawValue,
                "title": item.title,
            ]
            if let checksum = item.sourceChecksum {
                row["checksum"] = checksum
            }
            return row
        }
        let payload: [String: Any] = [
            "id": jobID.rawValue,
            "recipe": recipe.rawValue,
            "agent": agent,
            "isolation": isolation.rawValue,
            "items": listed,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        try data.write(to: dir.appendingPathComponent("manifest.json"))
    }

    private static func jsonString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
