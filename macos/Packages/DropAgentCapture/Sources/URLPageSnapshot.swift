import AppKit
import Foundation
import WebKit

public protocol PageSnapshotting: Sendable {
    func snapshotPage(url: URL) async -> Data?
}

public struct NullPageSnapshot: PageSnapshotting {
    public init() {}
    public func snapshotPage(url: URL) async -> Data? { nil }
}

public struct URLPageSnapshot: PageSnapshotting {
    public init() {}

    public func snapshotPage(url: URL) async -> Data? {
        await SnapshotHost.capture(url: url)
    }
}

@MainActor
private enum SnapshotHost {
    static func capture(url: URL) async -> Data? {
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 640))
        let window = NSWindow(
            contentRect: view.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
        window.contentView = view
        window.orderBack(nil)
        defer {
            window.orderOut(nil)
            window.contentView = nil
        }

        let waiter = LoadWaiter()
        view.navigationDelegate = waiter
        view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8))
        await waiter.wait(timeoutNanoseconds: 8_000_000_000)
        try? await Task.sleep(nanoseconds: 250_000_000)

        return await withCheckedContinuation { continuation in
            let once = SnapshotOnce()
            view.takeSnapshot(with: nil) { image, _ in
                guard let image,
                      let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                else {
                    once.finish(nil, continuation)
                    return
                }
                once.finish(png, continuation)
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                once.finish(nil, continuation)
            }
        }
    }
}

@MainActor
private final class SnapshotOnce {
    private var done = false

    func finish(_ data: Data?, _ continuation: CheckedContinuation<Data?, Never>) {
        guard done == false else { return }
        done = true
        continuation.resume(returning: data)
    }
}

@MainActor
private final class LoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait(timeoutNanoseconds: UInt64) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            continuation = cont
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self.finish()
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finish()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}
