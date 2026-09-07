import AppKit
import Foundation
import ScreenCaptureKit

public struct FrontWindowSnapshot: WindowSnapshotting {
    public init() {}

    public func snapshotFrontWindow(of pid: pid_t) async throws -> Data? {
        if let png = await screenCaptureKitPNG(pid: pid) {
            return png
        }
        return try legacyCGImage(pid: pid)
    }

    private func screenCaptureKitPNG(pid: pid_t) async -> Data? {
        guard pid != 0 else { return nil }
        return await withTaskGroup(of: Data?.self) { group in
            group.addTask {
                await Self.captureWithScreenCaptureKit(pid: pid)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first ?? nil
        }
    }

    private static func captureWithScreenCaptureKit(pid: pid_t) async -> Data? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let candidates = content.windows.filter {
                $0.owningApplication?.processID == pid
                    && $0.isOnScreen
                    && $0.frame.width > 40
                    && $0.frame.height > 40
            }
            guard let window = candidates.max(by: {
                ($0.frame.width * $0.frame.height) < ($1.frame.width * $1.frame.height)
            }) else {
                return nil
            }
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.showsCursor = false
            let scale = CGFloat(2)
            config.width = max(1, Int(window.frame.width * scale))
            config.height = max(1, Int(window.frame.height * scale))
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let rep = NSBitmapImageRep(cgImage: image)
            return rep.representation(using: .png, properties: [:])
        } catch {
            return nil
        }
    }

    public static func preferredWindowNumber(from windows: [[String: Any]], pid: pid_t) -> CGWindowID? {
        let matches = windows.filter { info in
            CGWindowInfo.processID(info) == pid && CGWindowInfo.layer(info) == 0
        }
        let best = matches.max { a, b in CGWindowInfo.area(a) < CGWindowInfo.area(b) }
        return best.flatMap(CGWindowInfo.windowNumber)
    }

    private func legacyCGImage(pid: pid_t) throws -> Data? {
        guard let window = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let frontPID = pid == 0 ? (BrowserFront.current()?.pid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0) : pid
        guard let number = Self.preferredWindowNumber(from: window, pid: frontPID) else {
            return nil
        }
        guard let image = CGWindowListCreateImage(
            .null,
            [.optionIncludingWindow],
            number,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }
}
