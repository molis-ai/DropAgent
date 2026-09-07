import Foundation

enum MaterialCopy {
    static func stripSymlinks(at url: URL) throws {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values.isSymbolicLink == true {
            try FileManager.default.removeItem(at: url)
            return
        }
        guard isDir.boolValue else { return }
        let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        for child in children {
            try stripSymlinks(at: child)
        }
    }
}
