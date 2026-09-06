import AppKit
import Foundation

final class CaptureLaunchBox: @unchecked Sendable {
    static let shared = CaptureLaunchBox()
    private let lock = NSLock()
    private var stored: BrowserFront?

    func freeze() {
        let pinned = BrowserFront.pinned(
            environmentPID: ProcessInfo.processInfo.environment["DROPAGENT_CAPTURE_PID"]
        ) { pid in
            NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
        }
        let value = pinned ?? BrowserFront.current()
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

public enum CaptureLaunch {
    public static func freeze() { CaptureLaunchBox.shared.freeze() }
    public static var frozen: BrowserFront? { CaptureLaunchBox.shared.frozen }
}
