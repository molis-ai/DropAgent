import DropAgentCapture
import Foundation

final class CaptureLaunchBox: @unchecked Sendable {
    static let shared = CaptureLaunchBox()
    private let lock = NSLock()
    private var stored: BrowserFront?

    func freeze() {
        let value = BrowserFront.current()
        lock.lock()
        if stored == nil {
            stored = value
        }
        lock.unlock()
    }

    var frozen: BrowserFront? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

enum CaptureLaunch {
    static func freeze() { CaptureLaunchBox.shared.freeze() }
    static var frozen: BrowserFront? { CaptureLaunchBox.shared.frozen }
}
