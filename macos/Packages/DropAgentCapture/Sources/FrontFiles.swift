import AppKit
import ApplicationServices
import Foundation

public enum FrontFileKind: Equatable, Sendable {
    case finder
    case browser
    case `self`
    case other
}

public enum FrontFileFailure: Equatable, Sendable, Error {
    case selfApp
    case browser
    case needAccessibility
    case needFinderAutomation
    case emptyFinder
    case empty
}

public enum FrontFileSource: Equatable, Sendable {
    case finder
    case copy
    case document
}

public struct FrontFileRead: Equatable, Sendable {
    public var urls: [URL]
    public var source: FrontFileSource

    public init(urls: [URL], source: FrontFileSource) {
        self.urls = urls
        self.source = source
    }
}

public enum FrontFiles {
    public static let finderBundleID = "com.apple.finder"
    public static let commandCKeyCode: CGKeyCode = 8

    public static func classify(bundleID: String?, selfBundle: String) -> FrontFileKind {
        let bundle = bundleID ?? ""
        if isSelf(bundle, selfBundle: selfBundle) { return .self }
        if bundle.caseInsensitiveCompare(finderBundleID) == .orderedSame { return .finder }
        if BrowserFront.Kind.from(bundleID: bundle) != nil { return .browser }
        return .other
    }

    public static func decide(
        kind: FrontFileKind,
        axTrusted: Bool,
        finderAllowed: Bool
    ) -> Result<Void, FrontFileFailure> {
        switch kind {
        case .self: return .failure(.selfApp)
        case .browser: return .failure(.browser)
        case .finder: return finderAllowed ? .success(()) : .failure(.needFinderAutomation)
        case .other: return axTrusted ? .success(()) : .failure(.needAccessibility)
        }
    }

    public static func resolve(
        kind: FrontFileKind,
        axTrusted: Bool,
        finderAllowed: Bool,
        finderURLs: @Sendable () async -> [URL],
        copiedURLs: @Sendable () async -> [URL],
        documentURLs: @Sendable () -> [URL]
    ) async -> Result<FrontFileRead, FrontFileFailure> {
        switch decide(kind: kind, axTrusted: axTrusted, finderAllowed: finderAllowed) {
        case .failure(let failure):
            return .failure(failure)
        case .success:
            break
        }
        switch kind {
        case .self, .browser:
            return .failure(kind == .self ? .selfApp : .browser)
        case .finder:
            let urls = existing(await finderURLs())
            return urls.isEmpty ? .failure(.emptyFinder) : .success(FrontFileRead(urls: urls, source: .finder))
        case .other:
            let copied = existing(await copiedURLs())
            if copied.isEmpty == false {
                return .success(FrontFileRead(urls: copied, source: .copy))
            }
            let documents = existing(documentURLs())
            if documents.isEmpty == false {
                return .success(FrontFileRead(urls: documents, source: .document))
            }
            return .failure(.empty)
        }
    }

    @MainActor
    public static func collect(
        frontBundleID: String?,
        frontPID: pid_t,
        selfBundle: String = Bundle.main.bundleIdentifier ?? "local.dropagent",
        axTrusted: Bool = AccessibilityPage.isTrusted(),
        finderAllowed: Bool = AutomationAccess.isAllowed(bundleIdentifier: FrontFiles.finderBundleID)
    ) async -> Result<FrontFileRead, FrontFileFailure> {
        let kind = classify(bundleID: frontBundleID, selfBundle: selfBundle)
        return await resolve(
            kind: kind,
            axTrusted: axTrusted,
            finderAllowed: finderAllowed,
            finderURLs: { await Task.detached { finderSelection() }.value },
            copiedURLs: { await copyFileURLs(pid: frontPID) },
            documentURLs: { AccessibilityPage.readFileDocuments(pid: frontPID) }
        )
    }

    public static func paths(fromText text: String) -> [URL] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { stripQuotes($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0.isEmpty == false }
        guard lines.isEmpty == false else { return [] }
        var urls: [URL] = []
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("vscode-remote:") || lower.hasPrefix("untitled:") {
                return []
            }
            guard let url = localFile(from: line) else { return [] }
            if urls.contains(url) == false {
                urls.append(url)
            }
        }
        return urls
    }

    public static func paths(fromPasteboard pasteboard: NSPasteboard) -> [URL] {
        var found: [URL] = []
        func append(_ url: URL) {
            let resolved = url.standardizedFileURL
            guard resolved.isFileURL else { return }
            guard FileManager.default.fileExists(atPath: resolved.path) else { return }
            if found.contains(resolved) == false {
                found.append(resolved)
            }
        }
        if let names = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            names.forEach { append(URL(fileURLWithPath: $0)) }
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] {
            urls.forEach(append)
        }
        for item in pasteboard.pasteboardItems ?? [] {
            if let text = item.string(forType: .fileURL) {
                if let url = URL(string: text), url.isFileURL {
                    append(url)
                } else if text.hasPrefix("/") {
                    append(URL(fileURLWithPath: text))
                }
            }
        }
        if found.isEmpty, let text = pasteboard.string(forType: .string) {
            return paths(fromText: text)
        }
        return found
    }

    public static func postCommandC(pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: commandCKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: commandCKeyCode, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
    }

    public static func copyFileURLs(
        pid: pid_t,
        pasteboard: NSPasteboard = .general,
        postCopy: (pid_t) -> Void = FrontFiles.postCommandC,
        timeout: TimeInterval = 0.45
    ) async -> [URL] {
        let backup = PasteboardBackup.capture(pasteboard)
        let before = pasteboard.changeCount
        postCopy(pid)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != before { break }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        let urls = paths(fromPasteboard: pasteboard)
        backup.restore(onto: pasteboard)
        return urls
    }

    public static func finderSelection() -> [URL] {
        let script = """
        with timeout of 3 seconds
        tell application id "\(finderBundleID)"
          set theSel to selection
          if (count of theSel) is 0 then return ""
          set chunks to {}
          repeat with f in theSel
            try
              set end of chunks to POSIX path of (f as alias)
            end try
          end repeat
          set AppleScript's text item delimiters to linefeed
          return chunks as text
        end tell
        end timeout
        """
        guard let text = runAppleScript(script) else { return [] }
        return paths(fromText: text)
    }

    private static func existing(_ urls: [URL]) -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath: $0.standardizedFileURL.path) }
    }

    private static func localFile(from text: String) -> URL? {
        if let url = URL(string: text), url.isFileURL {
            let resolved = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: resolved.path) else { return nil }
            return resolved
        }
        if text.hasPrefix("/") {
            let url = URL(fileURLWithPath: text).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return url
        }
        return nil
    }

    private static func stripQuotes(_ text: String) -> String {
        if text.count >= 2 {
            if text.hasPrefix("\""), text.hasSuffix("\"") {
                return String(text.dropFirst().dropLast())
            }
            if text.hasPrefix("'"), text.hasSuffix("'") {
                return String(text.dropFirst().dropLast())
            }
        }
        return text
    }

    private static func isSelf(_ bundle: String, selfBundle: String) -> Bool {
        let lower = bundle.lowercased()
        let selfLower = selfBundle.lowercased()
        if lower.isEmpty == false, lower == selfLower { return true }
        return lower == "local.dropagent"
    }

    private static func runAppleScript(_ script: String, timeout: TimeInterval = 4) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            return nil
        }
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
            return nil
        }
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else { return nil }
        return text
    }
}

public struct PasteboardBackup: Equatable, Sendable {
    public var changeCount: Int
    public var items: [[String: Data]]

    public static func capture(_ pasteboard: NSPasteboard) -> PasteboardBackup {
        var items: [[String: Data]] = []
        for item in pasteboard.pasteboardItems ?? [] {
            var types: [String: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    types[type.rawValue] = data
                }
            }
            if types.isEmpty == false {
                items.append(types)
            }
        }
        return PasteboardBackup(changeCount: pasteboard.changeCount, items: items)
    }

    public func restore(onto pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard items.isEmpty == false else { return }
        let written: [NSPasteboardItem] = items.map { types in
            let item = NSPasteboardItem()
            for (raw, data) in types {
                item.setData(data, forType: NSPasteboard.PasteboardType(raw))
            }
            return item
        }
        pasteboard.writeObjects(written)
    }
}
