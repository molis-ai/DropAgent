import AppKit
import Foundation
import ScreenCaptureKit

public struct AppleScriptBrowser: FrontBrowserReading {
    public var allowAppleScript: Bool

    public init(allowAppleScript: Bool = true) {
        self.allowAppleScript = allowAppleScript
    }

    public func frontPage(of target: BrowserFront?) throws -> (url: URL, title: String) {
        guard let target = target ?? BrowserFront.current() else {
            throw CaptureError.unsupportedBrowser
        }
        if let ax = AccessibilityPage.read(pid: target.pid) {
            return ax
        }
        guard allowAppleScript else {
            throw CaptureError.noURL
        }
        let running = Self.runningBundleIDs()
        guard Self.shouldUseAppleScript(kind: target.kind, targetPID: target.pid, runningBundleIDs: running) else {
            throw CaptureError.noURL
        }
        let bundleID = running[target.pid]
            ?? NSRunningApplication(processIdentifier: target.pid)?.bundleIdentifier
            ?? target.kind.primaryBundleIdentifier
        guard AutomationAccess.isAllowed(bundleIdentifier: bundleID) else {
            throw CaptureError.noURL
        }
        let script: String
        switch target.kind {
        case .safari:
            script = timedBrowserScript(
                """
                tell application "Safari"
                  if (count of windows) is 0 then error "no window"
                  set theURL to URL of current tab of front window
                  set theName to name of current tab of front window
                  return theURL & "\n" & theName
                end tell
                """
            )
        case .chrome:
            script = chromeTabScript(application: "Google Chrome")
        case .edge:
            script = chromeTabScript(application: "Microsoft Edge")
        case .brave:
            script = chromeTabScript(application: "Brave Browser")
        case .arc, .firefox:
            throw CaptureError.noURL
        }

        let text = try runAppleScript(script)
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, let url = URL(string: String(first)), url.scheme == "http" || url.scheme == "https" else {
            throw CaptureError.noURL
        }
        let title = parts.count > 1 ? String(parts[1]) : url.absoluteString
        return (url, title)
    }

    public static func shouldUseAppleScript(
        kind: BrowserFront.Kind,
        targetPID: pid_t,
        runningBundleIDs: [pid_t: String]
    ) -> Bool {
        guard kind.usesAppleScript else { return false }
        let targetBundle = runningBundleIDs[targetPID] ?? kind.primaryBundleIdentifier
        let peers = runningBundleIDs.values.filter { $0.caseInsensitiveCompare(targetBundle) == .orderedSame }
        return peers.count <= 1
    }

    public static func runningBundleIDs(
        from applications: [NSRunningApplication] = NSWorkspace.shared.runningApplications
    ) -> [pid_t: String] {
        var ids: [pid_t: String] = [:]
        for app in applications {
            if let bundle = app.bundleIdentifier {
                ids[app.processIdentifier] = bundle
            }
        }
        return ids
    }
}

private func chromeTabScript(application: String) -> String {
    timedBrowserScript(
        """
        tell application "\(application)"
          if (count of windows) is 0 then error "no window"
          set theURL to URL of active tab of front window
          set theName to title of active tab of front window
          return theURL & "\n" & theName
        end tell
        """
    )
}

private func timedBrowserScript(_ body: String) -> String {
    """
    with timeout of 3 seconds
    \(body)
    end timeout
    """
}

private func runAppleScript(_ script: String, timeout: TimeInterval = 4) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    let out = Pipe()
    let err = Pipe()
    process.standardOutput = out
    process.standardError = err
    try process.run()
    let finished = DispatchSemaphore(value: 0)
    DispatchQueue.global(qos: .userInitiated).async {
        process.waitUntilExit()
        finished.signal()
    }
    if finished.wait(timeout: .now() + timeout) == .timedOut {
        process.terminate()
        if process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        throw CaptureError.noURL
    }
    let data = out.fileHandleForReading.readDataToEndOfFile()
    let text = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard process.terminationStatus == 0, !text.isEmpty else {
        throw CaptureError.noURL
    }
    return text
}

public struct URLSessionFetcher: PageFetching {
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    public init() {}

    public func fetchHTML(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<400).contains(http.statusCode) {
            throw CaptureError.noURL
        }
        return data
    }
}

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
