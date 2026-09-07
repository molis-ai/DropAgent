import AppKit
import Foundation

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
