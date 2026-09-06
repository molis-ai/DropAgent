import AppKit
import Foundation

enum SourceLink {
    static func isOpenable(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        return scheme == "http" || scheme == "https"
    }

    static func open(_ url: URL) {
        guard isOpenable(url) else { return }
        NSWorkspace.shared.open(url)
    }
}
