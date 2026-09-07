import AppKit
import ApplicationServices
import CryptoKit
import os
import DropAgentAgent
import DropAgentCapture
import DropAgentIngest
import DropAgentJob
import DropAgentPasteboard
import DropAgentShelf
import DropAgentTUI
import Foundation
import UniformTypeIdentifiers

@main
enum DropAgentCheck {
    static func main() async {
        do {
            try shelf()
            try htmlMarkdown()
            try readableHTML()
            try browserFront()
            try captureRecovery()
            try await frontFiles()
            try automationAccess()
            try capturePermissions()
            try await captureService()
            try await liveWebAdmit()
            try ingest()
            try await ingestDropURLCapture()
            try ingestPasteboard()
            try await ingestDropProvider()
            try await architectureAcceptance()
            try await captureDoesNotInvent()
            try appDoesNotImportCapture()
            try agent()
            try await job()
            try tui()
            try pasteboard()
            try await pasteboardDragLandsFile()
            try await pasteboardWebFolderLands()
            try await pasteboardFolderLands()
            try await pasteboardClipLands()
            try await liveGrok()
            try await liveCapture()
        } catch {
            fail("uncaught \(error)")
        }
        if failures.value == 0 {
            fputs("DropAgentCheck: all passed\n", stdout)
        } else {
            fputs("DropAgentCheck: \(failures.value) failed\n", stderr)
            exit(1)
        }
    }
}

private final class FailureCounter: @unchecked Sendable {
    var value = 0
}

private let failures = FailureCounter()

private func raster(_ format: NSBitmapImageRep.FileType) -> Data {
    let image = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
        NSColor.red.setFill()
        rect.fill()
        return true
    }
    let tiff = image.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    return rep.representation(using: format, properties: [:])!
}

private func fail(_ message: String, file: String = #fileID, line: Int = #line) {
    failures.value += 1
    fputs("FAIL \(file):\(line) \(message)\n", stderr)
}

private func expect(_ condition: Bool, _ message: String, file: String = #fileID, line: Int = #line) {
    if !condition { fail(message, file: file, line: line) }
}

private func expectEqual<T: Equatable>(_ a: T, _ b: T, _ message: String = "", file: String = #fileID, line: Int = #line) {
    if a != b { fail("\(message) \(String(describing: a)) != \(String(describing: b))", file: file, line: line) }
}

private func tempDir() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("da-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func digest(_ url: URL) -> String {
    SHA256.hash(data: try! Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

private func plantHelpBinary(in directory: URL, name: String, help: String) throws -> URL {
    let url = directory.appendingPathComponent(name)
    let script = """
    #!/bin/sh
    if [ "$1" = "--help" ] || [ "$1" = "exec" ]; then
    cat <<'EOF'
    \(help)
    EOF
    fi
    """
    try Data(script.utf8).write(to: url)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    return url
}

private func shelfItem(title: String, status: ItemStatus = .idle) -> Item {
    Item(
        kind: .pdf,
        title: title,
        sourceURL: URL(fileURLWithPath: "/tmp/\(title)"),
        parts: [ItemPart(name: title, url: URL(fileURLWithPath: "/tmp/inbox/\(title)"))],
        status: status
    )
}

private func shelf() throws {
    let root = try tempDir()
    let store = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    var empty = shelfItem(title: "a.pdf")
    empty.parts = []
    do {
        _ = try store.add(empty)
        fail("empty parts should throw")
    } catch let error as ShelfError {
        expectEqual(error, .emptyParts)
    }

    _ = try store.add(shelfItem(title: "one.pdf"))
    let second = try store.add(shelfItem(title: "two.pdf"))
    expectEqual(store.items().map(\.title), ["two.pdf", "one.pdf"])
    expectEqual(store.selection, [second.id])

    let a = ShelfStore(fileURL: root.appendingPathComponent("s2.json"))
    let one = try a.add(shelfItem(title: "a.pdf"))
    let two = try a.add(shelfItem(title: "b.pdf"))
    a.toggleSelect(id: one.id, command: false)
    a.toggleSelect(id: two.id, command: true)
    expectEqual(a.selection, [one.id, two.id])

    let runningStore = ShelfStore(fileURL: root.appendingPathComponent("s3.json"))
    let running = try runningStore.add(shelfItem(title: "run.pdf", status: .running))
    do {
        try runningStore.remove(ids: [running.id])
        fail("running remove should throw")
    } catch let error as ShelfError {
        expectEqual(error, .runningLocked)
    }

    let persist = ShelfStore(fileURL: root.appendingPathComponent("keep.json"))
    let added = try persist.add(shelfItem(title: "keep.pdf"))
    persist.load()
    expectEqual(persist.items().map(\.id), [added.id])
    expectEqual(persist.results().count, 0)

    let legacyURL = root.appendingPathComponent("legacy.json")
    try JSONEncoder().encode([shelfItem(title: "old.pdf")]).write(to: legacyURL)
    let legacy = ShelfStore(fileURL: legacyURL)
    legacy.load()
    expectEqual(legacy.items().map(\.title), ["old.pdf"])
    expectEqual(legacy.results().count, 0)

    let withResult = ShelfStore(fileURL: root.appendingPathComponent("results.json"))
    let source = try withResult.add(shelfItem(title: "keep.pdf"))
    _ = withResult.addResult(
        ResultRecord(
            sourceItemIDs: [source.id],
            recipe: "总结文件",
            title: "summary.md",
            kind: .markdown,
            output: URL(fileURLWithPath: "/tmp/summary.md")
        )
    )
    withResult.load()
    expectEqual(withResult.items().map(\.title), ["keep.pdf"])
    expectEqual(withResult.results().map(\.title), ["summary.md"])

    let webIdle = Item(
        kind: .web,
        title: "Example Domain",
        sourceURL: URL(string: "https://example.com")!,
        parts: [ItemPart(name: "url.txt", url: URL(fileURLWithPath: "/tmp/url.txt"))],
        event: "正文未抓到"
    )
    expectEqual(webIdle.metaLine, "网站 · 正文未抓到")
    let webReady = Item(
        kind: .web,
        title: "Example Domain",
        sourceURL: URL(string: "https://example.com")!,
        parts: [ItemPart(name: "url.txt", url: URL(fileURLWithPath: "/tmp/url.txt"))]
    )
    expectEqual(webReady.metaLine, "网站 · 待处理")
    let runningLine = Item(
        kind: .pdf,
        title: "source.pdf",
        sourceURL: URL(fileURLWithPath: "/tmp/source.pdf"),
        parts: [ItemPart(name: "source.pdf", url: URL(fileURLWithPath: "/tmp/source.pdf"))],
        status: .running,
        event: "工具调用"
    )
    expectEqual(runningLine.metaLine, "工具调用")
    expectEqual(runningLine.displayTag, "PDF")
    let extracted = Item(
        kind: .markdown,
        title: "extracted.json",
        sourceURL: URL(fileURLWithPath: "/tmp/source.pdf"),
        parts: [ItemPart(name: "extracted.json", url: URL(fileURLWithPath: "/tmp/extracted.json"))],
        status: .done,
        output: URL(fileURLWithPath: "/tmp/extracted.json")
    )
    expectEqual(extracted.displayTag, "JSON")
    let jpegTag = Item(
        kind: .image,
        title: "shot.jpg",
        sourceURL: URL(fileURLWithPath: "/tmp/shot.jpg"),
        parts: [ItemPart(name: "shot.jpg", url: URL(fileURLWithPath: "/tmp/shot.jpg"))]
    )
    expectEqual(jpegTag.displayTag, "JPG")
    let heicTag = Item(
        kind: .image,
        title: "photo.heic",
        sourceURL: URL(fileURLWithPath: "/tmp/photo.heic"),
        parts: [ItemPart(name: "photo.heic", url: URL(fileURLWithPath: "/tmp/photo.heic"))]
    )
    expectEqual(heicTag.displayTag, "HEIC")

    let keys = ShelfStore(fileURL: root.appendingPathComponent("keys.json"))
    let first = try keys.add(shelfItem(title: "a.pdf"))
    let newer = try keys.add(shelfItem(title: "b.pdf"))
    expectEqual(keys.selectedItems().map(\.id), [newer.id])
    keys.moveSelection(offset: 1)
    expectEqual(keys.selectedItems().map(\.id), [first.id])
    keys.moveSelection(offset: 1)
    expectEqual(keys.selectedItems().map(\.id), [first.id], "clamp end")
    keys.moveSelection(offset: -1)
    expectEqual(keys.selectedItems().map(\.id), [newer.id])
}

private struct FailBrowser: FrontBrowserReading {
    func frontPage(of target: BrowserFront?) throws -> (url: URL, title: String) { throw CaptureError.unsupportedBrowser }
}
private struct FailFetch: PageFetching {
    func fetchHTML(url: URL) async throws -> Data { throw CaptureError.noURL }
}
private struct FailSnap: WindowSnapshotting {
    func snapshotFrontWindow(of pid: pid_t) async throws -> Data? { nil }
}
private struct StubBrowser: FrontBrowserReading {
    var result: Result<(url: URL, title: String), CaptureError>
    func frontPage(of target: BrowserFront?) throws -> (url: URL, title: String) { try result.get() }
}
private struct StubFetcher: PageFetching {
    var result: Result<Data, Error>
    func fetchHTML(url: URL) async throws -> Data { try result.get() }
}
private struct StubSnapshot: WindowSnapshotting {
    var data: Data?
    func snapshotFrontWindow(of pid: pid_t) async throws -> Data? { data }
}
private struct StubPageSnapshot: PageSnapshotting {
    var data: Data?
    func snapshotPage(url: URL) async -> Data? { data }
}
private struct MemoryClipboard: ClipboardReading {
    var payload: ClipboardPayload
    func read() -> ClipboardPayload { payload }
}

private func htmlMarkdown() throws {
    let md = HTMLMarkdown.convert("<html><h1>Hi</h1><script>alert(1)</script><p>Body &amp; more</p></html>")
    expect(md.contains("# Hi"), "heading")
    expect(md.contains("Body & more"), "entity")
    expect(!md.contains("alert"), "script stripped")

    let article = HTMLMarkdown.convert(
        "<nav>Skip me</nav><article><h1>Keep</h1><p>Hi <a href=\"https://example.com/x\">there</a> &mdash; <strong>bold</strong></p></article>"
    )
    expect(article.contains("# Keep"), "article heading")
    expect(article.contains("[there](https://example.com/x)"), "markdown link")
    expect(article.contains("—"), "mdash")
    expect(article.contains("**bold**"), "strong")
    expect(!article.contains("Skip me"), "nav dropped")

    let relative = HTMLMarkdown.convert(
        "<article><p><a href=\"/x\">go</a> <a href=\"javascript:alert(1)\">no</a> <a href=\"data:text/html,hi\">blob</a></p></article>",
        baseURL: URL(string: "https://example.com/page")
    )
    expect(relative.contains("[go](https://example.com/x)"), "relative href")
    expect(!relative.contains("javascript:"), "drop javascript href")
    expect(relative.contains("no"), "javascript label remains")
    expect(relative.contains("blob"), "data label remains")
    expect(!relative.contains("data:"), "drop data href")

    let main = HTMLMarkdown.convert("<main><p>Only <em>this</em></p></main><footer>foot</footer>")
    expect(main.contains("*this*"), "emphasis")
    expect(!main.contains("foot"), "footer dropped when main exists")

    let fenced = HTMLMarkdown.convert("<article><p>Run</p><pre><code>npm i</code></pre></article>")
    expect(fenced.contains("```"), "fenced fence")
    expect(fenced.contains("npm i"), "pre body")
    expect(!fenced.contains("`npm i`"), "pre is not also inline")

    let inline = HTMLMarkdown.convert("<p>set <code>PATH</code></p>")
    expect(inline.contains("`PATH`"), "inline code")

    let table = HTMLMarkdown.convert(
        "<article><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td><a href=\"/x\">go</a></td></tr></table></article>",
        baseURL: URL(string: "https://example.com/page")
    )
    expect(table.contains("| A | B |"), "table header")
    expect(table.contains("| --- | --- |"), "table rule")
    expect(table.contains("| 1 |"), "table cell")
    expect(table.contains("[go](https://example.com/x)"), "table link")

    let quote = HTMLMarkdown.convert("<blockquote><p>Note</p></blockquote>")
    expect(quote.contains("> Note"), "blockquote")

    let image = HTMLMarkdown.convert(
        "<article><p>See <img src=\"/x.png\" alt=\"Logo\"></p></article>",
        baseURL: URL(string: "https://example.com/page")
    )
    expect(image.contains("![Logo](https://example.com/x.png)"), "img markdown")

    let blocked = HTMLMarkdown.convert(
        "<article><img src=\"javascript:alert(1)\" alt=\"no\"><img src=\"data:image/png,xx\" alt=\"blob\"><img alt=\"empty\"></article>"
    )
    expect(blocked.contains("no"), "javascript alt remains")
    expect(blocked.contains("blob"), "data alt remains")
    expect(!blocked.contains("javascript:"), "drop javascript img")
    expect(!blocked.contains("data:"), "drop data img")
    expect(blocked.contains("empty"), "src-less img keeps alt")

    expectEqual(
        HTMLMarkdown.documentTitle("<html><head><title>  Example\n Domain  </title></head></html>"),
        "Example Domain"
    )
    expect(HTMLMarkdown.documentTitle("<html><p>no title</p></html>") == nil, "missing title")

    let examplePage = HTMLMarkdown.convert(
        """
        <!doctype html><html lang="en"><head><title>Example Domain</title>\
        <link rel="icon" href="data:,"><style>body{background:#eee}</style></head>\
        <body><div><h1>Example Domain</h1>\
        <p>This domain is for use in documentation examples without needing permission. Avoid use in operations.</p>\
        <p><a href="https://iana.org/domains/example">Learn more</a></p></div></body></html>
        """,
        baseURL: URL(string: "https://example.com/")
    )
    expect(examplePage.hasPrefix("# Example Domain"), "example starts at heading")
    expect(examplePage.contains("[Learn more](https://iana.org/domains/example)"), "example link")
    expect(!examplePage.split(whereSeparator: \.isNewline).contains(where: { $0 == "-" }), "link tag is not a list item")
    expect(!examplePage.contains("data:,"), "icon data url dropped")
    expectEqual(
        examplePage.split(whereSeparator: \.isNewline).filter { $0 == "Example Domain" }.count,
        0,
        "title not copied into body"
    )

    let realList = HTMLMarkdown.convert("<article><ul><li>One</li><li>Two</li></ul></article>")
    expect(realList.contains("- One"), "real li one")
    expect(realList.contains("- Two"), "real li two")

    let bodyOnly = HTMLMarkdown.convert("<body><p>Hi</p></body>")
    expectEqual(bodyOnly, "Hi")
    expect(!bodyOnly.contains("**"), "body is not bold")
}

private func readableHTML() throws {
    let md = ReadableHTML.markdown(
        from: "<html><h1>Hi</h1><script>alert(1)</script><p>Body &amp; more</p></html>"
    )
    expect(md.contains("# Hi"), "readable heading")
    expect(md.contains("Body & more"), "readable entity")
    expect(!md.contains("alert"), "readable script stripped")
    expect(
        ReadableHTML.isHTMLFile(URL(fileURLWithPath: "/tmp/page.html")),
        "html file"
    )
    expect(
        ReadableHTML.isHTMLFile(URL(fileURLWithPath: "/tmp/page.HTM")),
        "htm file"
    )
    expect(
        ReadableHTML.isHTMLFile(URL(fileURLWithPath: "/tmp/page.md")) == false,
        "md is not html"
    )
}

private func browserFront() throws {
    let safari = BrowserFront.resolve(
        frontmostBundle: "com.apple.Safari",
        frontmostPID: 11,
        selfBundle: "local.dropagent",
        windows: []
    )
    expect(safari?.kind == .safari, "safari kind")
    expect(safari?.pid == 11, "safari pid")

    let finder = BrowserFront.resolve(
        frontmostBundle: "com.apple.finder",
        frontmostPID: 22,
        selfBundle: "local.dropagent",
        windows: [BrowserWindowOwner(bundleID: "com.apple.Safari", pid: 99, layer: 0)]
    )
    expect(finder == nil, "finder does not steal safari")

    let selfApp = BrowserFront.resolve(
        frontmostBundle: "local.dropagent",
        frontmostPID: 33,
        selfBundle: "local.dropagent",
        windows: [
            BrowserWindowOwner(bundleID: "local.dropagent", pid: 33, layer: 0),
            BrowserWindowOwner(bundleID: "com.google.Chrome", pid: 44, layer: 0),
        ]
    )
    expect(selfApp?.kind == .chrome, "self app falls back to chrome")
    expect(selfApp?.pid == 44, "chrome pid")

    let owners = BrowserFront.owners(from: [
        [
            kCGWindowOwnerPID as String: NSNumber(value: 99),
            kCGWindowLayer as String: 25,
        ],
        [
            kCGWindowOwnerPID as String: NSNumber(value: 99),
            kCGWindowLayer as String: 0,
        ],
        [
            kCGWindowOwnerPID as String: NSNumber(value: 33),
            kCGWindowLayer as String: 0,
        ],
    ])
    expectEqual(owners.count, 2, "one owner per pid")
    expectEqual(owners[0].pid, 99)
    expectEqual(owners[0].layer, 0, "prefer standard window over status layer")
    expectEqual(owners[1].pid, 33)
    expect(BrowserFront.Kind.from(bundleID: "com.apple.SafariTechnologyPreview") == nil, "STP not v1 safari")
    expectEqual(BrowserFront.Kind.safari.primaryBundleIdentifier, "com.apple.Safari")
    expectEqual(BrowserFront.Kind.chrome.primaryBundleIdentifier, "com.google.Chrome")
    expectEqual(BrowserFront.Kind.edge.primaryBundleIdentifier, "com.microsoft.edgemac")
    expect(BrowserFront.Kind.from(bundleID: "com.brave.Browser") == .brave, "brave kind")
    expectEqual(BrowserFront.Kind.brave.appleScriptName, "Brave Browser")
    expect(BrowserFront.Kind.brave.usesAppleScript, "brave uses applescript")
    expect(BrowserFront.Kind.arc.usesAppleScript == false, "arc ax only")
    expect(BrowserFront.Kind.appleScriptCases.contains(.safari), "safari in applescript cases")
    expect(BrowserFront.Kind.appleScriptCases.contains(.arc) == false, "arc not in applescript cases")
    expect(BrowserFront.Kind.chrome.knownBundleIdentifiers.contains("com.google.Chrome.canary"), "chrome includes canary")
    expect(
        AppleScriptBrowser.shouldUseAppleScript(
            kind: .chrome,
            targetPID: 10,
            runningBundleIDs: [10: "com.google.chrome"]
        ),
        "single chrome may applescript"
    )
    expect(
        AppleScriptBrowser.shouldUseAppleScript(
            kind: .chrome,
            targetPID: 10,
            runningBundleIDs: [10: "com.google.chrome", 11: "com.google.chrome"]
        ) == false,
        "two chrome processes skip applescript"
    )
    expect(
        AppleScriptBrowser.shouldUseAppleScript(
            kind: .chrome,
            targetPID: 10,
            runningBundleIDs: [10: "com.google.chrome", 11: "com.google.chrome.canary"]
        ),
        "chrome plus canary still scripts chrome"
    )
    expect(
        AppleScriptBrowser.shouldUseAppleScript(
            kind: .arc,
            targetPID: 12,
            runningBundleIDs: [12: "company.thebrowser.Browser"]
        ) == false,
        "arc never applescript"
    )
    expectEqual(
        BrowserFront.pinned(environmentPID: "44", bundleIDForPID: { _ in "com.google.chrome" })?.pid,
        44
    )
    expectEqual(
        BrowserFront.pinned(environmentPID: "44", bundleIDForPID: { _ in "com.google.chrome" })?.kind,
        .chrome
    )
    expect(BrowserFront.pinned(environmentPID: "abc", bundleIDForPID: { _ in "com.google.chrome" }) == nil, "junk pid")
    expect(BrowserFront.pinned(environmentPID: "44", bundleIDForPID: { _ in "com.apple.finder" }) == nil, "non browser pid")
    expect(BrowserFront.pinned(environmentPID: nil, bundleIDForPID: { _ in "com.google.chrome" }) == nil, "no pin")
    expect(URLSessionFetcher.userAgent.contains("Safari"), "browser user agent")
    expect(BrowserFront.Kind.from(bundleID: "org.mozilla.firefox") == .firefox, "firefox kind")
    let arc = BrowserFront.resolve(
        frontmostBundle: "company.thebrowser.Browser",
        frontmostPID: 55,
        selfBundle: "local.dropagent",
        windows: []
    )
    expect(arc?.kind == .arc, "arc kind")
    expectEqual(BrowserFront.Kind.arc.primaryBundleIdentifier, "company.thebrowser.Browser")
    expectEqual(AccessibilityPage.httpURL(from: "https://example.com")?.host, "example.com")
    expectEqual(AccessibilityPage.httpURL(from: "http://localhost/a")?.scheme, "http")
    expect(AccessibilityPage.httpURL(from: "file:///tmp/x") == nil, "reject file url")
    expect(AccessibilityPage.existingFileURL(from: "https://example.com") == nil, "http is not a local file")
    expect(AccessibilityPage.httpURL(from: "not a url") == nil, "reject junk")
    expectEqual(AccessibilityPage.httpURL(from: URL(string: "https://example.org")!)?.host, "example.org")
    expectEqual(AccessibilityPage.httpURL(from: "Example Domain — https://example.com/page")?.host, "example.com")
    expect(AccessibilityPage.windowScore(subrole: "AXStandardWindow") > AccessibilityPage.windowScore(subrole: "AXUnknown"), "standard chrome window before sheets")
    expect(AccessibilityPage.windowScore(subrole: "AXStandardWindow") > AccessibilityPage.windowScore(subrole: "AXDialog"), "standard before dialog")
    expect(AccessibilityPage.roleRank("AXWebArea") > AccessibilityPage.roleRank("AXGroup"), "web area before group")
    expect(AccessibilityPage.roleRank("AXWebArea") > AccessibilityPage.roleRank("AXButton"), "web area before button")
    expectEqual(AccessibilityPage.childVisitOrder(roles: ["AXButton", "AXWebArea", "AXGroup"]), [1, 2, 0])
    let axStart = Date()
    _ = AccessibilityPage.read(pid: ProcessInfo.processInfo.processIdentifier)
    expect(Date().timeIntervalSince(axStart) < 3, "AX read of self does not hang")
}

private func frontFiles() async throws {
    expectEqual(FrontFiles.classify(bundleID: "com.apple.finder", selfBundle: "local.dropagent"), .finder)
    expectEqual(FrontFiles.classify(bundleID: "com.apple.Safari", selfBundle: "local.dropagent"), .browser)
    expectEqual(FrontFiles.classify(bundleID: "com.google.chrome", selfBundle: "local.dropagent"), .browser)
    expectEqual(FrontFiles.classify(bundleID: "local.dropagent", selfBundle: "local.dropagent"), .self)
    expectEqual(FrontFiles.classify(bundleID: "com.microsoft.VSCode", selfBundle: "local.dropagent"), .other)

    func expectFail(_ result: Result<Void, FrontFileFailure>, _ expected: FrontFileFailure) {
        if case .failure(let actual) = result {
            expectEqual(actual, expected)
        } else {
            fail("expected \(expected)")
        }
    }
    func expectOK(_ result: Result<Void, FrontFileFailure>) {
        if case .failure(let actual) = result {
            fail("expected success, got \(actual)")
        }
    }
    expectFail(FrontFiles.decide(kind: .browser, axTrusted: true, finderAllowed: true), .browser)
    expectFail(FrontFiles.decide(kind: .self, axTrusted: true, finderAllowed: true), .selfApp)
    expectFail(FrontFiles.decide(kind: .finder, axTrusted: true, finderAllowed: false), .needFinderAutomation)
    expectFail(FrontFiles.decide(kind: .other, axTrusted: false, finderAllowed: true), .needAccessibility)
    expectOK(FrontFiles.decide(kind: .other, axTrusted: true, finderAllowed: false))
    expectOK(FrontFiles.decide(kind: .finder, axTrusted: false, finderAllowed: true))

    let root = try tempDir()
    let first = root.appendingPathComponent("a.pdf")
    let second = root.appendingPathComponent("b.md")
    try Data("a".utf8).write(to: first)
    try Data("b".utf8).write(to: second)
    let firstURL = first.standardizedFileURL
    let secondURL = second.standardizedFileURL

    expectEqual(FrontFiles.paths(fromText: first.path), [firstURL])
    expectEqual(FrontFiles.paths(fromText: "\(first.path)\n\(second.path)"), [firstURL, secondURL])
    expectEqual(FrontFiles.paths(fromText: "\"\(first.path)\""), [firstURL])
    expect(FrontFiles.paths(fromText: "\(first.path)\nnot-a-file").isEmpty, "mixed text is not files")
    expect(FrontFiles.paths(fromText: "vscode-remote://host\(first.path)").isEmpty, "reject remote")
    expect(FrontFiles.paths(fromText: "relative.pdf").isEmpty, "reject relative")
    expectEqual(FrontFiles.paths(fromText: firstURL.absoluteString), [firstURL])
    expectEqual(AccessibilityPage.existingFileURL(from: firstURL.absoluteString), firstURL)

    let finder = await FrontFiles.resolve(
        kind: .finder,
        axTrusted: true,
        finderAllowed: true,
        finderURLs: { [firstURL] },
        copiedURLs: { [secondURL] },
        documentURLs: { [secondURL] }
    )
    expectEqual(finder, .success(FrontFileRead(urls: [firstURL], source: .finder)))

    let emptyFinder = await FrontFiles.resolve(
        kind: .finder,
        axTrusted: true,
        finderAllowed: true,
        finderURLs: { [] },
        copiedURLs: { [secondURL] },
        documentURLs: { [secondURL] }
    )
    expectEqual(emptyFinder, .failure(.emptyFinder))

    let copied = await FrontFiles.resolve(
        kind: .other,
        axTrusted: true,
        finderAllowed: true,
        finderURLs: { [firstURL] },
        copiedURLs: { [firstURL, secondURL] },
        documentURLs: { [secondURL] }
    )
    expectEqual(copied, .success(FrontFileRead(urls: [firstURL, secondURL], source: .copy)))

    let document = await FrontFiles.resolve(
        kind: .other,
        axTrusted: true,
        finderAllowed: true,
        finderURLs: { [] },
        copiedURLs: { [] },
        documentURLs: { [firstURL] }
    )
    expectEqual(document, .success(FrontFileRead(urls: [firstURL], source: .document)))

    let emptyOther = await FrontFiles.resolve(
        kind: .other,
        axTrusted: true,
        finderAllowed: true,
        finderURLs: { [] },
        copiedURLs: { [] },
        documentURLs: { [] }
    )
    expectEqual(emptyOther, .failure(.empty))

    let board = NSPasteboard.withUniqueName()
    board.clearContents()
    board.setString("keep-me", forType: .string)
    let copiedPaths = await FrontFiles.copyFileURLs(pid: 0, pasteboard: board, postCopy: { _ in
        board.clearContents()
        board.setString(first.path, forType: .string)
    })
    expectEqual(copiedPaths, [firstURL])
    expectEqual(board.string(forType: .string), "keep-me")
}

private func captureRecovery() throws {
    let safari = BrowserFront(kind: .safari, pid: 9)
    expectEqual(CaptureRecovery.decision(target: nil, axTrusted: false, automationAllowed: false), .stop(message: CaptureRecovery.noBrowser, offerPrivacySettings: false))
    expectEqual(CaptureRecovery.decision(target: safari, axTrusted: false, automationAllowed: false), .stop(message: CaptureRecovery.needAccessibility, offerPrivacySettings: true))
    expectEqual(CaptureRecovery.decision(target: safari, axTrusted: true, automationAllowed: false), .proceed)
    expectEqual(CaptureRecovery.decision(target: safari, axTrusted: false, automationAllowed: true), .proceed)

    let noPage = CaptureRecovery.failure(target: nil, axTrusted: false, automationAllowed: false)
    expectEqual(noPage.message, CaptureRecovery.noBrowser)
    expect(noPage.offerPrivacySettings == false, "no browser does not send user to privacy")
    expect(CaptureRecovery.noBrowser.contains("Edge"), "edge in no-browser copy")
    expect(CaptureRecovery.noBrowserHotKey.contains("⌃⌥W"), "hotkey variant names capture key")
    expect(CaptureRecovery.noBrowserHotKey.contains("Edge"), "hotkey variant names edge")
    expect(!CaptureRecovery.noBrowser.contains("⌃⌥W"), "kernel capture copy does not assume hotkey")
    expect(!CaptureRecovery.noBrowser.contains("⌃⌥D"), "kernel capture copy does not assume toggle hotkey")

    let ax = CaptureRecovery.failure(target: safari, axTrusted: false, automationAllowed: false)
    expectEqual(ax.message, CaptureRecovery.needAccessibilityRetry)
    expect(ax.offerPrivacySettings, "ax retry offers privacy")

    let auto = CaptureRecovery.failure(target: safari, axTrusted: true, automationAllowed: false)
    expect(auto.message.contains("Safari"), "automation names safari")
    expect(auto.offerPrivacySettings, "automation offers privacy")

    let brave = CaptureRecovery.failure(target: BrowserFront(kind: .brave, pid: 8), axTrusted: true, automationAllowed: false)
    expect(brave.message.contains("Brave"), "brave copy")
    expect(brave.offerPrivacySettings, "brave automation offers privacy")

    let arc = CaptureRecovery.failure(target: BrowserFront(kind: .arc, pid: 3), axTrusted: true, automationAllowed: false)
    expect(arc.message.contains("Arc"), "arc copy")
    expect(arc.offerPrivacySettings == false, "arc does not send user to automation")

    let none = PageAdmit.decide(token: .none)
    expect(none.proceed == false, "explicit none does not proceed")
    expectEqual(none.message, PageAdmitCopy.noBrowser)
    expect(none.offerPrivacySettings == false, "explicit none does not send user to privacy")
    expectEqual(PageAdmitCopy.needAccessibility, CaptureRecovery.needAccessibility)
}

private func automationAccess() throws {
    let missing = "local.dropagent.missing.\(UUID().uuidString)"
    let start = Date()
    let allowed = AutomationAccess.isAllowed(bundleIdentifier: missing)
    expect(allowed == false, "unknown bundle is not automatable")
    expect(Date().timeIntervalSince(start) < 2, "automation probe does not hang")

    let requestStart = Date()
    let requested = AutomationAccess.requestIfNeeded(bundleIdentifier: missing)
    expect(requested != .allowed, "missing bundle is not allowed after request")
    expect(Date().timeIntervalSince(requestStart) < 2, "automation request of missing bundle does not hang")

    expectEqual(AutomationAccess.state(from: noErr), .allowed)
    expectEqual(AutomationAccess.state(from: OSStatus(errAEEventNotPermitted)), .denied)
    expectEqual(AutomationAccess.state(from: OSStatus(errAEEventWouldRequireUserConsent)), .notDetermined)
    expectEqual(AutomationAccess.state(from: OSStatus(-600)), .unavailable)

    let chromeRunning = NSWorkspace.shared.runningApplications.contains {
        $0.activationPolicy == .regular && $0.bundleIdentifier == "com.google.Chrome"
    }
    if chromeRunning {
        expectEqual(
            AutomationAccess.resolvedBundleIdentifier("com.google.chrome"),
            "com.google.Chrome"
        )
    }

    let scriptStart = Date()
    do {
        _ = try AppleScriptBrowser(allowAppleScript: true).frontPage(of: nil)
    } catch {
        expect(error is CaptureError, "frontPage fails with CaptureError when it cannot read")
    }
    expect(Date().timeIntervalSince(scriptStart) < 8, "AppleScript frontPage does not hang")
}

private func capturePermissions() throws {
    let safariOnly = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.apple.Safari"],
        runningBundleIDs: ["com.apple.Safari"],
        stateForBundle: { _ in .notDetermined }
    )
    expectEqual(safariOnly.browsers.map(\.kind), [.safari])
    expect(safariOnly.browsers.contains { $0.kind == .chrome } == false, "uninstalled chrome is omitted")
    expect(safariOnly.captureReady == false, "undetermined safari is not capture ready")

    let withArc = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.apple.Safari", "company.thebrowser.Browser"],
        runningBundleIDs: ["company.thebrowser.Browser"],
        stateForBundle: { _ in .allowed }
    )
    expect(withArc.browsers.contains { $0.kind == .arc } == false, "arc is not an automation row")
    expect(withArc.browsers.contains { $0.kind == .safari }, "safari still listed")

    let ready = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.apple.Safari", "com.google.chrome"],
        runningBundleIDs: ["com.google.chrome"],
        stateForBundle: { _ in .allowed }
    )
    expectEqual(ready.browsers.map(\.kind), [.safari, .chrome])
    expect(ready.captureReady, "trusted ax and allowed browsers are capture ready")

    let canary = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.google.chrome.canary"],
        runningBundleIDs: ["com.google.chrome.canary"],
        stateForBundle: { $0 == "com.google.chrome.canary" ? .denied : .unavailable }
    )
    expectEqual(canary.browsers.count, 1)
    expectEqual(canary.browsers[0].kind, .chrome)
    expectEqual(canary.browsers[0].bundleIdentifier, "com.google.chrome.canary")
    expectEqual(canary.browsers[0].state, .denied)

    let closedDenied = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.google.chrome"],
        runningBundleIDs: [],
        stateForBundle: { _ in .denied }
    )
    expectEqual(closedDenied.browsers.count, 1)
    expectEqual(closedDenied.browsers[0].running, false)
    expectEqual(closedDenied.browsers[0].state, .unavailable)
    expect(closedDenied.browsers[0].allowed == false, "closed chrome is not capture ready")

    let liveCase = CapturePermissions.status(
        accessibilityTrusted: true,
        installedBundleIDs: ["com.google.chrome"],
        runningBundleIDs: ["com.google.Chrome"],
        stateForBundle: { $0 == "com.google.Chrome" ? .denied : .unavailable }
    )
    expectEqual(liveCase.browsers.count, 1)
    expectEqual(liveCase.browsers[0].bundleIdentifier, "com.google.Chrome")
    expect(liveCase.browsers[0].running, "live chrome stays running")
    expectEqual(liveCase.browsers[0].state, .denied)
    expectEqual(
        CapturePermissions.pickBundle(
            kind: .chrome,
            preferred: ["com.google.Chrome"],
            fallback: ["com.google.chrome"]
        ),
        "com.google.Chrome"
    )

    let wrapped = PageAdmit.setupStatus(ready)
    expect(wrapped.captureReady, "page admit setup mirrors capture ready")
    expectEqual(wrapped.browsers.map(\.displayName), ["Safari", "Google Chrome"])

    let noneTarget = PageAdmit.privacyTarget(token: .none)
    expect(noneTarget == nil, "explicit none has no privacy target")
}

private func ingest() throws {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let capture = CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    let ingest = IngestService(shelf: shelf, inboxRoot: root.appendingPathComponent("Inbox"), capture: capture)

    let original = root.appendingPathComponent("doc.pdf")
    let bytes = Data("pdf-bytes".utf8)
    try bytes.write(to: original)
    let result = ingest.admit(urls: [original])
    expect(result.failures.isEmpty, "pdf admit failures")
    let item = result.admitted[0]
    expectEqual(item.kind, .pdf)
    expectEqual(item.sourceURL.path, original.path)
    expect(item.parts[0].url.path != original.path, "inbox copy")
    expectEqual(try Data(contentsOf: item.parts[0].url), bytes)
    expect(item.sourceChecksum != nil, "checksum")
    expectEqual(item.status, .idle)

    let missing = ingest.admit(urls: [URL(fileURLWithPath: "/tmp/dropagent-missing-\(UUID().uuidString).pdf")])
    expect(missing.admitted.isEmpty, "missing admitted")
    expectEqual(missing.failures.first?.error, .missingSource)

    let md = root.appendingPathComponent("note.md")
    try Data("# hi".utf8).write(to: md)
    let partial = ingest.admit(urls: [md, URL(fileURLWithPath: "/tmp/missing-\(UUID().uuidString).pdf")])
    expectEqual(partial.admitted.count, 1)
    expectEqual(partial.failures.count, 1)

    let url = URL(string: "https://example.com/a")!
    let urlAdmit = ingest.admit(urls: [url])
    expectEqual(urlAdmit.admitted.first?.kind, .web)
    expectEqual(urlAdmit.admitted.first?.parts.first?.name, "url.txt")
    expectEqual(urlAdmit.admitted.first?.event, IngestService.pageCapturePendingEvent)
    expectEqual(urlAdmit.admitted.first?.status, .idle)
    expectEqual(urlAdmit.pageCaptureIDs, urlAdmit.admitted.map(\.id))
    let quietURL = ingest.admit(urls: [url], capturePages: false)
    expectEqual(quietURL.admitted.first?.kind, .url)
    expectEqual(quietURL.admitted.first?.parts.first?.name, "link.txt")
    expect(quietURL.pageCaptureIDs.isEmpty, "tui url is not captured")

    let clip = try ingest.admitClipboard(MemoryClipboard(payload: .text("渠道折扣收到 9%")))
    expectEqual(clip.first?.kind, .clip)

    let clipURL = try ingest.admitClipboard(MemoryClipboard(payload: .text("https://dropoverapp.com")))
    expectEqual(clipURL.first?.kind, .web)
    expectEqual(clipURL.first?.parts.first?.name, "url.txt")
    let quietClip = try ingest.admitClipboard(MemoryClipboard(payload: .text("https://dropoverapp.com")), capturePages: false)
    expectEqual(quietClip.first?.kind, .url)
    expectEqual(quietClip.first?.parts.first?.name, "link.txt")

    do {
        _ = try ingest.admitClipboard(MemoryClipboard(payload: .empty))
        fail("empty clipboard")
    } catch let error as IngestError {
        expectEqual(error, .emptyClipboard)
    }

    let real = root.appendingPathComponent("real.txt")
    try Data("x".utf8).write(to: real)
    let link = root.appendingPathComponent("link.txt")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    expectEqual(ingest.admit(urls: [link]).failures.first?.error, .symlinkRejected)

    let webloc = root.appendingPathComponent("Example.webloc")
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <plist version="1.0">
    <dict>
      <key>URL</key>
      <string>https://example.com/page</string>
    </dict>
    </plist>
    """
    try Data(plist.utf8).write(to: webloc)
    let fromWebloc = ingest.admit(urls: [webloc]).admitted.first
    expectEqual(fromWebloc?.kind, .web)
    expectEqual(fromWebloc?.sourceURL.absoluteString, "https://example.com/page")
    expectEqual(fromWebloc?.parts.first?.name, "url.txt")
    expectEqual(
        try String(contentsOf: fromWebloc!.parts[0].url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
        "https://example.com/page"
    )
    expectEqual(fromWebloc?.event, IngestService.pageCapturePendingEvent)
    let quietWebloc = ingest.admit(urls: [webloc], capturePages: false).admitted.first
    expectEqual(quietWebloc?.kind, .url)
    expectEqual(quietWebloc?.parts.first?.name, "link.txt")

    let junkWebloc = root.appendingPathComponent("bad.webloc")
    try Data("not a plist".utf8).write(to: junkWebloc)
    let junk = ingest.admit(urls: [junkWebloc]).admitted.first
    expectEqual(junk?.kind, .file)
    expectEqual(junk?.title, "bad.webloc")
    expectEqual(junk?.displayTag, "FILE")

    let png = try ingest.admitImageData(Data([0x89, 0x50, 0x4E, 0x47]))
    expectEqual(png.kind, .image)
    expectEqual(png.parts[0].name, "clipboard.png")
    expectEqual(png.displayTag, "PNG")

    let jpegFile = root.appendingPathComponent("shot.jpg")
    try Data("jpeg-bytes".utf8).write(to: jpegFile)
    let jpegItem = ingest.admit(urls: [jpegFile]).admitted.first
    expectEqual(jpegItem?.kind, .image)
    expectEqual(jpegItem?.displayTag, "JPG")

    let heicFile = root.appendingPathComponent("photo.heic")
    try Data("heic-bytes".utf8).write(to: heicFile)
    let heicItem = ingest.admit(urls: [heicFile]).admitted.first
    expectEqual(heicItem?.kind, .image)
    expectEqual(heicItem?.displayTag, "HEIC")

    let bundle = root.appendingPathComponent("bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
    try Data("inside".utf8).write(to: bundle.appendingPathComponent("a.txt"))
    let folderItem = ingest.admit(urls: [bundle]).admitted.first
    expectEqual(folderItem?.kind, .folder)
    expectEqual(folderItem?.status, .idle)
    expect(folderItem?.parts.first?.url.path != bundle.path, "folder copied")

    let zipFile = root.appendingPathComponent("archive.zip")
    try Data("PK".utf8).write(to: zipFile)
    let zipItem = ingest.admit(urls: [zipFile]).admitted.first
    expectEqual(zipItem?.kind, .file)
    expectEqual(zipItem?.displayTag, "ZIP")
    expectEqual(zipItem?.kind.word, "文件")
    expect(!RecipeCatalog.spec(.summarize).acceptedKinds.contains(.file), "summarize no generic file")
    expect(!RecipeCatalog.spec(.translate).acceptedKinds.contains(.file), "translate no generic file")
    expect(RecipeCatalog.spec(.brief).acceptedKinds.contains(.file), "brief takes files")

    let rtfFile = root.appendingPathComponent("note.rtf")
    try Data("{\\rtf1 hello}".utf8).write(to: rtfFile)
    let rtfItem = ingest.admit(urls: [rtfFile]).admitted.first
    expectEqual(rtfItem?.kind, .file)
    expectEqual(rtfItem?.displayTag, "RTF")
    expectEqual(rtfItem?.kind.word, "文件")

    let htmlFile = root.appendingPathComponent("page.html")
    try Data("<html><p>Hi</p></html>".utf8).write(to: htmlFile)
    let htmlItem = ingest.admit(urls: [htmlFile]).admitted.first
    expectEqual(htmlItem?.kind, .file)
    expectEqual(htmlItem?.displayTag, "HTML")
    expectEqual(htmlItem?.kind.word, "文件")

    let swiftFile = root.appendingPathComponent("main.swift")
    try Data("let x = *star*\n".utf8).write(to: swiftFile)
    let swiftItem = ingest.admit(urls: [swiftFile]).admitted.first
    expectEqual(swiftItem?.kind, .markdown)
    expectEqual(swiftItem?.displayTag, "SWIFT")
    expectEqual(swiftItem?.kind.word, "文稿")

    let yamlFile = root.appendingPathComponent("config.yaml")
    try Data("name: drop\n".utf8).write(to: yamlFile)
    let yamlItem = ingest.admit(urls: [yamlFile]).admitted.first
    expectEqual(yamlItem?.kind, .markdown)
    expectEqual(yamlItem?.displayTag, "YAML")

    let noteFile = root.appendingPathComponent("note.md")
    try Data("# Hi\n".utf8).write(to: noteFile)
    let noteItem = ingest.admit(urls: [noteFile]).admitted.first
    expectEqual(noteItem?.kind, .markdown)
    expectEqual(noteItem?.displayTag, "MD")
}

private func ingestDropURLCapture() async throws {
    let root = try tempDir()
    let failedShelf = ShelfStore(fileURL: root.appendingPathComponent("fail-shelf.json"))
    let failed = IngestService(
        shelf: failedShelf,
        inboxRoot: root.appendingPathComponent("FailInbox"),
        capture: CaptureService(
            browser: FailBrowser(),
            fetcher: FailFetch(),
            snapshot: FailSnap(),
            pageSnapshot: NullPageSnapshot()
        )
    )
    let url = URL(string: "https://example.com/dropped")!
    let stub = failed.admit(urls: [url])
    expectEqual(stub.admitted.first?.kind, .web)
    expectEqual(stub.admitted.first?.event, IngestService.pageCapturePendingEvent)
    expectEqual(stub.admitted.first?.parts.map(\.name), ["url.txt"])
    expectEqual(stub.admitted.first?.status, .idle)
    expectEqual(stub.pageCaptureIDs.count, 1)
    await failed.captureDroppedPages(ids: stub.pageCaptureIDs)
    let afterFail = failedShelf.item(id: stub.admitted[0].id)
    expectEqual(afterFail?.kind, .web)
    expect(afterFail?.event.contains("正文没拉下来") == true, "network failure labeled")
    expect(afterFail?.parts.contains { $0.name == "page.md" } == false, "no fake markdown")
    expect(afterFail?.parts.contains { $0.name == "url.txt" } == true, "url kept")

    let okRoot = try tempDir()
    let okShelf = ShelfStore(fileURL: okRoot.appendingPathComponent("ok-shelf.json"))
    let ok = IngestService(
        shelf: okShelf,
        inboxRoot: okRoot.appendingPathComponent("OkInbox"),
        capture: CaptureService(
            browser: FailBrowser(),
            fetcher: StubFetcher(result: .success(Data(
                "<html><head><title>Example Domain</title></head><p>Hi from drop</p></html>".utf8
            ))),
            snapshot: FailSnap(),
            pageSnapshot: StubPageSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
        )
    )
    let admitted = ok.admit(urls: [url])
    await ok.captureDroppedPages(ids: admitted.pageCaptureIDs)
    let filled = okShelf.item(id: admitted.admitted[0].id)
    expectEqual(filled?.kind, .web)
    expectEqual(filled?.title, "Example Domain")
    expectEqual(filled?.event, "")
    expect(filled?.parts.contains { $0.name == "page.md" } == true, "page.md written")
    expect(filled?.parts.contains { $0.name == "snapshot.png" } == true, "snapshot written")
    let md = filled?.parts.first { $0.name == "page.md" }.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) } ?? ""
    expect(md.contains("Hi from drop"), "markdown body")
}

private func ingestPasteboard() throws {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    let board = NSPasteboard.withUniqueName()
    board.clearContents()
    expectEqual(ClipboardPayload.from(pasteboard: board), .empty)
    expect(ingest.admitPasteboard(board).admitted.isEmpty, "empty pasteboard drop")
    expect(ingest.admitPasteboard(board).failures.isEmpty, "empty pasteboard drop has no failure")

    let original = root.appendingPathComponent("doc.pdf")
    let bytes = Data("pdf-bytes".utf8)
    try bytes.write(to: original)
    expect(board.writeObjects([original as NSURL]), "write file")
    guard case .files(let urls) = ClipboardPayload.from(pasteboard: board) else {
        fail("file pasteboard")
        return
    }
    expectEqual(urls.map(\.path), [original.path])
    let namesBoard = NSPasteboard.withUniqueName()
    namesBoard.clearContents()
    namesBoard.setPropertyList([original.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
    guard case .files(let named) = ClipboardPayload.from(pasteboard: namesBoard) else {
        fail("filenames pasteboard")
        return
    }
    expectEqual(named.map(\.path), [original.path])
    let admitted = ingest.admit(urls: urls)
    expectEqual(admitted.admitted.first?.kind, .pdf)
    expectEqual(try Data(contentsOf: original), bytes)

    board.clearContents()
    let link = URL(string: "https://example.com/a")!
    expect(board.writeObjects([link as NSURL]), "write url")
    guard case .text(let text) = ClipboardPayload.from(pasteboard: board) else {
        fail("url pasteboard")
        return
    }
    expectEqual(text, "https://example.com/a")
    let fromBoard = try ingest.admitClipboard(PasteboardClipboard(board))
    expectEqual(fromBoard.first?.kind, .web)
    expectEqual(fromBoard.first?.sourceURL.absoluteString, "https://example.com/a")
    expectEqual(fromBoard.first?.parts.first?.name, "url.txt")

    board.clearContents()
    board.setString("渠道折扣收到 9%", forType: .string)
    expectEqual(ClipboardPayload.from(pasteboard: board), .text("渠道折扣收到 9%"))
    let clip = try ingest.admitClipboard(PasteboardClipboard(board))
    expectEqual(clip.first?.kind, .clip)

    board.clearContents()
    expectEqual(PasteboardClipboard(board).read(), .empty)

    let rich = NSAttributedString(string: "从备忘录来的口径")
    let rtf = try rich.data(
        from: NSRange(location: 0, length: rich.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
    expectEqual(ClipboardPayload.plainText(fromRTF: rtf), Optional("从备忘录来的口径"))
    board.declareTypes([.rtf], owner: nil)
    board.setData(rtf, forType: .rtf)
    board.setString("", forType: .string)
    guard case .text(let rtfText) = ClipboardPayload.from(pasteboard: board) else {
        fail("rtf pasteboard")
        return
    }
    expectEqual(rtfText, "从备忘录来的口径")
    let fromRTF = try ingest.admitClipboard(PasteboardClipboard(board))
    expectEqual(fromRTF.first?.kind, .clip)

    board.clearContents()
    let picture = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
        NSColor.red.setFill()
        rect.fill()
        return true
    }
    expect(board.writeObjects([picture]), "write image")
    guard case .image(let png) = ClipboardPayload.from(pasteboard: board) else {
        fail("image pasteboard")
        return
    }
    expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), "image is png")
    let shot = try ingest.admitClipboard(PasteboardClipboard(board))
    expectEqual(shot.first?.kind, .image)
    expectEqual(shot.first?.parts.first?.name, "clipboard.png")

    board.clearContents()
    let titlesType = NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType")
    board.declareTypes([titlesType], owner: nil)
    board.setPropertyList(
        [["https://example.com/tab"], ["Example Domain"]],
        forType: titlesType
    )
    guard case .text(let tabText) = ClipboardPayload.from(pasteboard: board) else {
        fail("web titles pasteboard")
        return
    }
    expectEqual(tabText, "https://example.com/tab")
    let fromTab = try ingest.admitClipboard(PasteboardClipboard(board))
    expectEqual(fromTab.first?.kind, .web)
    expectEqual(fromTab.first?.sourceURL.absoluteString, "https://example.com/tab")

    board.clearContents()
    let missing = URL(fileURLWithPath: "/tmp/dropagent-no-such-\(UUID().uuidString).webloc")
    let tab = URL(string: "https://example.com/tab")!
    expect(board.writeObjects([missing as NSURL, tab as NSURL]), "write phantom webloc plus url")
    guard case .text(let mixed) = ClipboardPayload.from(pasteboard: board) else {
        fail("tab pasteboard prefers http")
        return
    }
    expectEqual(mixed, "https://example.com/tab")

    board.clearContents()
    expect(board.writeObjects([missing as NSURL]), "write missing file")
    expectEqual(ClipboardPayload.from(pasteboard: board), .empty)

    board.clearContents()
    board.declareTypes([.URL], owner: nil)
    board.setData(Data("https://example.com/data".utf8), forType: .URL)
    guard case .text(let fromData) = ClipboardPayload.from(pasteboard: board) else {
        fail("url data pasteboard")
        return
    }
    expectEqual(fromData, "https://example.com/data")

    board.clearContents()
    let bookmarkType = NSPasteboard.PasteboardType("org.chromium.bookmark-dictionary-list")
    board.declareTypes([bookmarkType], owner: nil)
    board.setPropertyList(
        [["URL": "https://example.com/bookmark", "Title": "Bookmark"]],
        forType: bookmarkType
    )
    guard case .text(let fromBookmark) = ClipboardPayload.from(pasteboard: board) else {
        fail("chromium bookmark pasteboard")
        return
    }
    expectEqual(fromBookmark, "https://example.com/bookmark")
}

private func ingestDropProvider() async throws {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    let original = root.appendingPathComponent("drop.pdf")
    let bytes = Data("%PDF-1.4 dropped".utf8)
    try bytes.write(to: original)
    let before = digest(original)
    guard let provider = NSItemProvider(contentsOf: original) else {
        fail("NSItemProvider for pdf")
        return
    }
    let result = await ingest.admitProviders([provider])
    expect(result.failures.isEmpty, "drop failures")
    guard let item = result.admitted.first else {
        fail("drop admitted none")
        return
    }
    expectEqual(item.kind, .pdf)
    expectEqual(item.status, .idle)
    expectEqual(digest(original), before, "drop left original")
    expect(item.parts[0].url.path != original.path, "drop copied to inbox")
    expectEqual(try Data(contentsOf: item.parts[0].url), bytes)

    let heicProvider = NSItemProvider()
    let heicBytes = Data("not-a-real-heic".utf8)
    heicProvider.registerDataRepresentation(forTypeIdentifier: UTType.heic.identifier, visibility: .all) { completion in
        completion(heicBytes, nil)
        return nil
    }
    let heicDrop = await ingest.admitProviders([heicProvider])
    expectEqual(heicDrop.admitted.first?.kind, .image)
}

private func architectureAcceptance() async throws {
    let root = try tempDir()
    let original = root.appendingPathComponent("keep.pdf")
    try Data("pdf-bytes".utf8).write(to: original)
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    let admitted = ingest.admit(urls: [original])
    expectEqual(admitted.admitted.first?.status, .idle)
    expectEqual(try Data(contentsOf: original), Data("pdf-bytes".utf8))

    let none = FakeAgent(presence: .none)
    do {
        _ = try TUIService(shelf: shelf, agent: none, inboxRoot: root.appendingPathComponent("TUIInbox"))
            .send(itemIDs: [admitted.admitted[0].id], text: "hi")
        fail("tui should require agent")
    } catch let error as TUIError {
        expectEqual(error, .noAgent)
    }
    expectEqual(shelf.items().first?.status, .idle)

    do {
        _ = try await JobService(shelf: shelf, agent: none, jobsRoot: root.appendingPathComponent("Jobs"))
            .start(itemIDs: [admitted.admitted[0].id], recipe: .summarize)
        fail("job should require agent")
    } catch let error as JobError {
        expectEqual(error, .noAgent)
    }
    expectEqual(shelf.items().first?.status, .idle)
    expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Jobs").path), "no job dir")
}

private struct StubExecutor: CodexExecuting {
    var sandbox = true
    func supportsWorkspaceSandbox(at executable: URL) -> Bool { sandbox }
    func exec(executable: URL, request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        try "ok".write(to: request.outputFile, atomically: true, encoding: .utf8)
        return AgentRunResult(exitCode: 0, events: [], lastMessage: "ok")
    }
    func cancel() {}
}

private func agent() throws {
    let service = AgentService(runner: StubExecutor())
    let unknown = AgentPresence.codex(path: URL(fileURLWithPath: "/opt/homebrew/bin/codex"), isolation: .unknown)
    expectEqual(service.isolationCopy(for: unknown), "未确认工作区限制，仍在副本目录跑")
    expectEqual(IsolationShown.unconfirmed.spokenFact, service.isolationCopy(for: unknown))
    expectEqual(service.isolationCopy(for: AgentPresence.none), "未发现 Agent")
    let workspace = AgentPresence.codex(path: URL(fileURLWithPath: "/opt/homebrew/bin/codex"), isolation: .workspace)
    expect(service.isolationCopy(for: workspace).contains("Workspace Sandbox"), "workspace copy")
    expectEqual(IsolationShown.workspace.spokenFact, service.isolationCopy(for: workspace))
    expect(!service.isolationCopy(for: workspace).contains("完全看不到"), "no overclaim")

    let grokUnknown = AgentPresence.grok(path: URL(fileURLWithPath: "/opt/homebrew/bin/grok"), isolation: .unknown)
    expectEqual(service.isolationCopy(for: grokUnknown), "未确认工作区限制，仍在副本目录跑")
    expect(!service.isolationCopy(for: grokUnknown).contains("Workspace"), "grok no workspace")
    let grokTUI = AgentPresence.grok(path: URL(fileURLWithPath: "/opt/homebrew/bin/grok"), isolation: .tui)
    expectEqual(service.isolationCopy(for: grokTUI), "在终端执行，不是副本沙箱")

    let request = AgentRunRequest(
        workdir: URL(fileURLWithPath: "/tmp/work"),
        promptFile: URL(fileURLWithPath: "/tmp/prompt.txt"),
        outputFile: URL(fileURLWithPath: "/tmp/out.md"),
        isolation: .workspace
    )
    let grokHelp = """
      --cwd <CWD>
      --prompt-file <PATH>
      --output-format <OUTPUT_FORMAT>
  -p, --single <PROMPT>
      --always-approve
      --permission-mode bypassPermissions
"""
    expect(HeadlessCLI.canRunJob(engine: .grok, help: grokHelp), "grok job")
    expect(!HeadlessCLI.canRunJob(engine: .grok, help: "Grok Build TUI"), "grok tui only")
    expect(HeadlessCLI.canRunJob(engine: .claude, help: "use -p/--print for non-interactive"), "claude job")
    expect(HeadlessCLI.canRunJob(engine: .codex, help: "Commands:\n  exec              Run Codex non-interactively"), "codex job")
    expect(!HeadlessCLI.canRunJob(engine: .codex, help: "Auto-approve all tool executions"), "executions is not exec")
    expect(HeadlessCLI.canRunJob(engine: .gemini, help: "  --prompt <prompt>"), "gemini job")
    let grokArgs = HeadlessCLI.arguments(engine: .grok, help: grokHelp, request: request, prompt: "hello")
    expect(grokArgs.contains("--prompt-file"), "grok prompt file")
    expect(grokArgs.contains("--cwd"), "grok cwd")
    expect(!grokArgs.contains("--always-approve"), "grok no always-approve")
    expect(!grokArgs.contains("bypassPermissions"), "grok no bypass")
    let claudeArgs = HeadlessCLI.arguments(
        engine: .claude,
        help: "-p, --print\n--output-format\n--add-dir\n--dangerously-skip-permissions",
        request: request,
        prompt: "hello"
    )
    expect(claudeArgs.contains("--print"), "claude print")
    expect(claudeArgs.contains("hello"), "claude prompt")
    expect(!claudeArgs.contains("--dangerously-skip-permissions"), "claude no skip")
    let geminiArgs = HeadlessCLI.arguments(engine: .gemini, help: "--prompt <prompt>", request: request, prompt: "hello")
    expect(geminiArgs.contains("--prompt"), "gemini prompt flag")
    expect(!HeadlessCLI.canRunJob(engine: .gemini, help: ""), "gemini empty")

    let root = try tempDir()
    let binary = try plantHelpBinary(in: root, name: "codex", help: "Commands:\n  exec              Run Codex non-interactively\n")
    let found = AgentService(
        runner: StubExecutor(sandbox: true),
        settings: AgentSettings(executableOverride: binary.path),
        pathEnvironment: "/does/not/exist",
        home: root
    )
    expectEqual(found.discover(settings: AgentSettings(executableOverride: binary.path)), .codex(path: binary, isolation: .workspace))

    let missing = AgentService(runner: StubExecutor(), pathEnvironment: "/empty", home: URL(fileURLWithPath: "/tmp/no-home-\(UUID().uuidString)"))
    expectEqual(missing.discover(settings: AgentSettings()), AgentPresence.none)

    let args = CodexCLI.execArguments(request: request, prompt: "hello")
    expect(args.contains("--ephemeral"), "ephemeral")
    expect(args.contains("--ignore-user-config"), "ignore config")
    expect(args.contains("workspace-write"), "sandbox")
    expectEqual(args.last, "hello")
    expect(!args.contains("--dangerously-bypass-approvals-and-sandbox"), "no bypass")
    expect(!args.contains("--always-approve"), "exec no always-approve")
    expect(!args.contains("bypassPermissions"), "exec no bypassPermissions")
    expect(!args.contains("--dangerously-skip-permissions"), "exec no skip permissions")
    expect(!args.contains("sandbox_workspace_write.network_access=true"), "summarize stays offline")
    let networked = AgentRunRequest(
        workdir: URL(fileURLWithPath: "/tmp/work"),
        promptFile: URL(fileURLWithPath: "/tmp/prompt.txt"),
        outputFile: URL(fileURLWithPath: "/tmp/out.md"),
        isolation: .workspace,
        network: true
    )
    let netArgs = CodexCLI.execArguments(request: networked, prompt: "hello")
    expect(netArgs.contains("-c"), "network config flag")
    expect(netArgs.contains("sandbox_workspace_write.network_access=true"), "translate may use network")
    expect(!netArgs.contains("--dangerously-bypass-approvals-and-sandbox"), "network still sandboxed")
    let recipeEnv = CodexCLI.recipeEnvironment(executable: URL(fileURLWithPath: "/usr/local/bin/codex"))
    expect(recipeEnv["CODEX_HOME"] == nil, "recipe does not inherit CODEX_HOME")
    expectEqual(recipeEnv["HOME"], FileManager.default.homeDirectoryForCurrentUser.path)

    let session = try found.ensureInteractiveSession()
    expectEqual(session.executable, binary)
    expect(session.environment.contains { $0.hasPrefix("PATH=") && $0.contains(binary.deletingLastPathComponent().path) }, "tui path")
    expect(session.environment.contains { $0.hasPrefix("TERM=") }, "tui term")

    let decoded = try JSONDecoder().decode(AgentSettings.self, from: Data(#"{"executableOverride":"/opt/codex"}"#.utf8))
    expectEqual(decoded.executableOverride, "/opt/codex")
    expectEqual(decoded.tuiEngine, .auto)

    let bothRoot = try tempDir()
    let grokBin = try plantHelpBinary(
        in: bothRoot,
        name: "grok",
        help: "      --cwd <CWD>\n      --prompt-file <PATH>\n  -p, --single <PROMPT>\n      --output-format\n"
    )
    let claudeBin = try plantHelpBinary(
        in: bothRoot,
        name: "claude",
        help: "Claude Code - use -p/--print for non-interactive output\n"
    )
    _ = try plantHelpBinary(
        in: bothRoot,
        name: "codex",
        help: "Commands:\n  exec              Run Codex non-interactively\n"
    )
    let mixed = AgentService(
        runner: StubExecutor(sandbox: true),
        settings: AgentSettings(),
        pathEnvironment: bothRoot.path,
        home: bothRoot
    )
    let autoTUI = mixed.tuiPresence(settings: AgentSettings(tuiEngine: .auto))
    expectEqual(autoTUI.engine, .grok)
    expectEqual(autoTUI.executable, grokBin)
    expectEqual(mixed.recipePresence(settings: AgentSettings()).engine, .grok)
    let forced = mixed.tuiPresence(settings: AgentSettings(tuiEngine: .codex))
    expectEqual(forced.engine, .codex)
    let claudeTUI = mixed.tuiPresence(settings: AgentSettings(tuiEngine: .claude))
    expectEqual(claudeTUI.executable, claudeBin)
    let missingGemini = mixed.tuiPresence(settings: AgentSettings(tuiEngine: .gemini))
    expectEqual(missingGemini, AgentPresence.none)
    let names = mixed.installedEngines(settings: AgentSettings()).compactMap(\.engine)
    expect(names.contains(.grok) && names.contains(.claude) && names.contains(.codex), "installed three")
    expect(!names.contains(.gemini), "gemini absent")

    let grokOnlyRoot = try tempDir()
    let grokOnlyBin = grokOnlyRoot.appendingPathComponent("grok")
    try Data("#!/bin/sh\n".utf8).write(to: grokOnlyBin)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: grokOnlyBin.path)
    let grokOnly = AgentService(
        runner: StubExecutor(sandbox: true),
        settings: AgentSettings(),
        pathEnvironment: grokOnlyRoot.path,
        home: grokOnlyRoot
    )
    expectEqual(grokOnly.tuiPresence(settings: AgentSettings()).engine, .grok)
    expectEqual(grokOnly.recipePresence(settings: AgentSettings()), .none)

    let grokJobRoot = try tempDir()
    let grokJobBin = try plantHelpBinary(
        in: grokJobRoot,
        name: "grok",
        help: "      --prompt-file <PATH>\n  -p, --single <PROMPT>\n"
    )
    let grokJobAgent = AgentService(
        runner: StubExecutor(sandbox: true),
        settings: AgentSettings(),
        pathEnvironment: grokJobRoot.path,
        home: grokJobRoot
    )
    expectEqual(grokJobAgent.tuiPresence(settings: AgentSettings()).engine, .grok)
    expectEqual(grokJobAgent.recipePresence(settings: AgentSettings()), .grok(path: grokJobBin, isolation: .unknown))
    expectEqual(grokJobAgent.tuiPresence(settings: AgentSettings(tuiEngine: .claude)), .none)

    let claudeForced = mixed.recipePresence(settings: AgentSettings(tuiEngine: .claude))
    expectEqual(claudeForced.engine, .claude)
    expectEqual(claudeForced.isolation, .unknown)

    expectEqual(AgentEngine.identified(binaryName: "agent", help: "Grok Build TUI", path: "/Users/me/.grok/bin/agent"), .grok)
    expectEqual(AgentEngine.identified(binaryName: "cursor-agent", help: "Cursor Agent\n  -p, --print", path: "/usr/local/bin/cursor-agent"), .cursor)
    expectEqual(AgentEngine.identified(binaryName: "agent", help: "Grok Build TUI", path: "/opt/bin/agent"), .grok)
    expectEqual(AgentEngine.identified(binaryName: "agent", help: "Cursor CLI --print", path: "/Users/me/.local/bin/agent"), .cursor)
    expectEqual(CLICommand.posixQuote("it's"), "'it'\\''s'")

    let extraRoot = try tempDir()
    let extraHome = extraRoot.appendingPathComponent("home", isDirectory: true)
    let grokAgentDir = extraHome.appendingPathComponent(".grok/bin", isDirectory: true)
    try FileManager.default.createDirectory(at: grokAgentDir, withIntermediateDirectories: true)
    _ = try plantHelpBinary(in: grokAgentDir, name: "agent", help: "Grok Build TUI\n")
    let grokInExtra = try plantHelpBinary(
        in: extraRoot,
        name: "grok",
        help: "      --prompt-file <PATH>\n  -p, --single <PROMPT>\n"
    )
    let opencodeBin = try plantHelpBinary(
        in: extraRoot,
        name: "opencode",
        help: """
        opencode [project]
              --prompt
              --auto
        Commands:
          run [message..]
              --dir
        """
    )
    let cursorBin = try plantHelpBinary(
        in: extraRoot,
        name: "cursor-agent",
        help: "Cursor Agent\n  -p, --print\n  --force\n  --yolo\n"
    )
    let extra = AgentService(
        runner: StubExecutor(sandbox: true),
        settings: AgentSettings(),
        pathEnvironment: extraRoot.path,
        home: extraHome
    )
    expectEqual(extra.tuiPresence(settings: AgentSettings()).engine, .grok)
    expectEqual(extra.tuiPresence(settings: AgentSettings(tuiEngine: .opencode)).executable, opencodeBin)
    expectEqual(extra.recipePresence(settings: AgentSettings(tuiEngine: .opencode)).engine, .opencode)
    expectEqual(extra.tuiPresence(settings: AgentSettings(tuiEngine: .cursor)).executable, cursorBin)
    expectEqual(extra.recipePresence(settings: AgentSettings(tuiEngine: .cursor)).engine, .cursor)
    expectEqual(extra.tuiPresence(settings: AgentSettings(tuiEngine: .grok)).executable, grokInExtra)
    let opencodeArgs = HeadlessCLI.arguments(
        engine: .opencode,
        help: "run [message..]\n--dir\n--auto",
        request: request,
        prompt: "hello"
    )
    expectEqual(opencodeArgs.first, "run")
    expect(opencodeArgs.contains("--dir"), "opencode dir")
    expect(opencodeArgs.contains("hello"), "opencode prompt")
    expect(!opencodeArgs.contains("--auto"), "opencode no auto")
    let cursorArgs = HeadlessCLI.arguments(
        engine: .cursor,
        help: "-p, --print\n--yolo\n--force",
        request: request,
        prompt: "hello"
    )
    expect(cursorArgs.contains("--print") || cursorArgs.contains("-p"), "cursor print")
    expect(!cursorArgs.contains("--yolo"), "cursor no yolo")
    expect(!cursorArgs.contains("--force"), "cursor no force")

    let customBin = try plantHelpBinary(in: extraRoot, name: "my-agent", help: "just a tui\n")
    let custom = CustomRuntime(id: "c1", title: "Mine", executable: customBin.path, kind: .tui)
    let customSettings = AgentSettings(customRuntimes: [custom], selectedCustomID: "c1")
    let customPresence = extra.tuiPresence(settings: customSettings)
    expectEqual(customPresence.runtimeKey, "custom:c1")
    expectEqual(customPresence.shortTitle, "Mine")
    expectEqual(customPresence.executable, customBin)
    expect(extra.installedEngines(settings: customSettings).contains { $0.runtimeKey == "custom:c1" }, "custom listed")

    let llmBin = try plantHelpBinary(in: extraRoot, name: "llm", help: "llm [prompt]\n")
    expectEqual(extra.tuiPresence(settings: AgentSettings(tuiEngine: .llm)).executable, llmBin)
    expectEqual(extra.recipePresence(settings: AgentSettings(tuiEngine: .llm)).engine, .llm)
    expectEqual(HeadlessCLI.arguments(engine: .llm, help: "", request: request, prompt: "hello"), ["hello"])

    func event(_ json: String) -> String? {
        CodexJSONL.event(from: Data(json.utf8))?.message
    }
    expectEqual(event(#"{"type":"item.started","item":{"type":"command_execution"}}"#), "工具调用")
    expectEqual(event(#"{"type":"thread.started"}"#), "开始运行")
    expectEqual(event(#"{"type":"error"}"#), "失败")
    expectEqual(event(#"{"type":"exec_approval"}"#), "等待授权")
    expectEqual(event(#"{"message":"复制到 input/ 与 work/"}"#), "复制到 input/ 与 work/")
    expect(event(#"{"type":"token_count","count":1}"#) == nil, "skip token noise")
    expect(event(#"{"type":"item.completed","item":{"type":"reasoning"}}"#) == nil, "skip empty completed")
    expectEqual(event(#"{"type":"item.started","item":{"type":"web_search"}}"#), "联网")
    expectEqual(event(#"{"type":"item.started"}"#), "进行中")
    expectEqual(event(#"{"type":"item.completed","item":{"type":"command_execution"}}"#), "工具调用完成")
}

final class FakeAgent: AgentRunning, @unchecked Sendable {
    var settings = AgentSettings()
    var presence: AgentPresence
    var lastRequest: AgentRunRequest?
    var lastPrompt = ""
    var outputText = "这是总结"
    var mutateWorkCopy = false
    var failCode: Int32?
    var failEvent: String?
    init(presence: AgentPresence) { self.presence = presence }
    func discover(settings: AgentSettings) -> AgentPresence { presence }
    func isolationCopy(for presence: AgentPresence) -> String { "Workspace Sandbox：Agent 只能写任务工作区" }
    func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        lastRequest = request
        lastPrompt = String(decoding: try Data(contentsOf: request.promptFile), as: UTF8.self)
        if mutateWorkCopy {
            let files = try FileManager.default.contentsOfDirectory(at: request.workdir, includingPropertiesForKeys: nil)
            if let first = files.first(where: { !$0.lastPathComponent.hasPrefix(".") }) {
                try Data("mutated-copy".utf8).write(to: first)
            }
        }
        if let failEvent {
            onEvent?(AgentEvent(message: failEvent))
        }
        if let failCode {
            throw AgentError.failed(failCode)
        }
        try FileManager.default.createDirectory(at: request.outputFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try outputText.write(to: request.outputFile, atomically: true, encoding: .utf8)
        onEvent?(AgentEvent(message: "写入 output/"))
        return AgentRunResult(exitCode: 0, events: [AgentEvent(message: "写入 output/")], lastMessage: outputText)
    }
    func ensureInteractiveSession() throws -> SessionHandle {
        guard let url = presence.executable else { throw AgentError.notFound }
        return SessionHandle(executable: url)
    }
    func cancelCurrent() {}
}

private func job() async throws {
    func setup() throws -> (ShelfStore, URL, URL, Item) {
        let root = try tempDir()
        let original = root.appendingPathComponent("source.pdf")
        try Data("original-bytes".utf8).write(to: original)
        let inbox = root.appendingPathComponent("Inbox/item1", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let copy = inbox.appendingPathComponent("source.pdf")
        try FileManager.default.copyItem(at: original, to: copy)
        let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
        let item = try shelf.add(Item(
            kind: .pdf,
            title: "source.pdf",
            sourceURL: original,
            parts: [ItemPart(name: "source.pdf", url: copy)],
            sourceChecksum: digest(original)
        ))
        return (shelf, root.appendingPathComponent("Jobs"), original, item)
    }

    let noneEnv = try setup()
    let noneJob = JobService(shelf: noneEnv.0, agent: FakeAgent(presence: .none), jobsRoot: noneEnv.1)
    do {
        _ = try await noneJob.start(itemIDs: [noneEnv.3.id], recipe: .summarize)
        fail("no agent should throw")
    } catch let error as JobError {
        expectEqual(error, .noAgent)
    }
    expectEqual(noneEnv.0.item(id: noneEnv.3.id)?.status, .idle)

    let grokEnv = try setup()
    let grokAgent = FakeAgent(presence: .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .unknown))
    let grokJob = JobService(shelf: grokEnv.0, agent: grokAgent, jobsRoot: grokEnv.1)
    _ = try await grokJob.start(itemIDs: [grokEnv.3.id], recipe: .summarize)
    expectEqual(try Data(contentsOf: grokEnv.2), Data("original-bytes".utf8))
    expectEqual(grokEnv.0.item(id: grokEnv.3.id)?.status, .idle)
    expectEqual(grokEnv.0.item(id: grokEnv.3.id)?.title, "source.pdf")
    expectEqual(grokEnv.0.results().first?.title, "summary.md")
    expectEqual(grokEnv.0.results().first?.status, .done)
    let grokDirs = try FileManager.default.contentsOfDirectory(at: grokEnv.1, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    let grokManifest = try JSONSerialization.jsonObject(with: Data(contentsOf: grokDirs[0].appendingPathComponent("manifest.json"))) as? [String: Any]
    expectEqual(grokManifest?["agent"] as? String, "grok")
    expectEqual(grokManifest?["isolation"] as? String, "unknown")

    let env = try setup()
    let agent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    agent.mutateWorkCopy = true
    let job = JobService(shelf: env.0, agent: agent, jobsRoot: env.1)
    let jobID = try await job.start(itemIDs: [env.3.id], recipe: .summarize)
    expectEqual(try Data(contentsOf: env.2), Data("original-bytes".utf8))
    let finished = env.0.item(id: env.3.id)!
    expectEqual(finished.status, .idle)
    expectEqual(finished.title, "source.pdf")
    expectEqual(finished.kind, .pdf)
    expectEqual(finished.isolationShown, .none)
    expectEqual(env.0.results().first?.title, "summary.md")
    expectEqual(env.0.results().first?.isolationShown, .workspace)
    expectEqual(env.0.results().first?.sourceItemIDs, [env.3.id])
    expect(!agent.lastPrompt.contains(env.2.path), "prompt has original path")
    expect(agent.lastPrompt.contains("source.pdf"), "relative name")
    let workFile = agent.lastRequest!.workdir.appendingPathComponent("source.pdf")
    expect(try workFile.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true, "symlink")
    expectEqual(try String(contentsOf: workFile, encoding: .utf8), "mutated-copy")
    let jobDirs = try FileManager.default.contentsOfDirectory(at: env.1, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
    expectEqual(jobDirs.count, 1, "one job dir")
    let manifestObject = try JSONSerialization.jsonObject(with: Data(contentsOf: jobDirs[0].appendingPathComponent("manifest.json"))) as? [String: Any]
    expectEqual(manifestObject?["recipe"] as? String, "summarize")
    expectEqual(manifestObject?["agent"] as? String, "codex")
    expectEqual(manifestObject?["isolation"] as? String, "workspace")
    let listed = manifestObject?["items"] as? [[String: Any]]
    expectEqual(listed?.first?["checksum"] as? String, finished.sourceChecksum)
    expect(FileManager.default.fileExists(atPath: jobDirs[0].appendingPathComponent("events.jsonl").path), "events.jsonl")
    let eventLog = try String(contentsOf: jobDirs[0].appendingPathComponent("events.jsonl"), encoding: .utf8)
    expect(eventLog.contains("复制到 input/ 与 work/"), "copy event logged")
    expect(eventLog.contains("写入 output/"), "agent event logged")
    let record = job.job(id: jobID)
    expectEqual(record?.recipe, .summarize)
    expectEqual(record?.itemIDs, [env.3.id])
    expectEqual(record?.outputFile.lastPathComponent, "summary.md")
    expectEqual(listed?.first?["id"] as? String, env.3.id.rawValue)
    let inputFile = jobDirs[0].appendingPathComponent("input/source.pdf")
    expectEqual(try Data(contentsOf: inputFile), Data("original-bytes".utf8))
    do {
        try Data("overwrite-input".utf8).write(to: inputFile)
        fail("input should be read-only")
    } catch {
        expectEqual(try Data(contentsOf: inputFile), Data("original-bytes".utf8), "input unchanged")
    }

    let changed = try setup()
    try Data("changed".utf8).write(to: changed.2)
    let changedAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    _ = try await JobService(shelf: changed.0, agent: changedAgent, jobsRoot: changed.1)
        .start(itemIDs: [changed.3.id], recipe: .summarize)
    expectEqual(changed.0.item(id: changed.3.id)?.status, .idle)
    expectEqual(changed.0.item(id: changed.3.id)?.title, "source.pdf")
    expectEqual(changed.0.results().first?.status, .failed)
    expectEqual(changed.0.results().first?.failureReason, "原件中途变了，结果按副本做的")
    expect(changed.0.results().first?.output != nil, "hash mismatch keeps output")

    let unknownEnv = try setup()
    _ = try await JobService(
        shelf: unknownEnv.0,
        agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .unknown)),
        jobsRoot: unknownEnv.1
    ).start(itemIDs: [unknownEnv.3.id], recipe: .summarize)
    expectEqual(unknownEnv.0.item(id: unknownEnv.3.id)?.status, .idle)
    expectEqual(unknownEnv.0.results().first?.isolationShown, .unconfirmed)
    expect(unknownEnv.0.results().first?.isolationShown != .safeCopy, "unknown is not Safe Copy")

    let failEnv = try setup()
    let failAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    failAgent.failEvent = "失败"
    failAgent.failCode = 1
    do {
        _ = try await JobService(shelf: failEnv.0, agent: failAgent, jobsRoot: failEnv.1)
            .start(itemIDs: [failEnv.3.id], recipe: .summarize)
        fail("agent failure should throw")
    } catch let error as AgentError {
        expectEqual(error, .failed(1))
    }
    expectEqual(failEnv.0.item(id: failEnv.3.id)?.status, .idle)
    expectEqual(failEnv.0.item(id: failEnv.3.id)?.title, "source.pdf")
    expectEqual(failEnv.0.results().first?.status, .failed)
    expectEqual(failEnv.0.results().first?.failureReason, "失败")
    expectEqual(try Data(contentsOf: failEnv.2), Data("original-bytes".utf8))

    let blankFail = try setup()
    let blankAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    blankAgent.failCode = 2
    do {
        _ = try await JobService(shelf: blankFail.0, agent: blankAgent, jobsRoot: blankFail.1)
            .start(itemIDs: [blankFail.3.id], recipe: .summarize)
        fail("blank agent failure should throw")
    } catch let error as AgentError {
        expectEqual(error, .failed(2))
    }
    expectEqual(blankFail.0.item(id: blankFail.3.id)?.status, .idle)
    expectEqual(blankFail.0.results().first?.failureReason, "任务失败")

    let extractEnv = try setup()
    let extractAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    extractAgent.outputText = "{\"ok\":true}"
    let extractJob = JobService(shelf: extractEnv.0, agent: extractAgent, jobsRoot: extractEnv.1)
    let extractID = try await extractJob.start(itemIDs: [extractEnv.3.id], recipe: .extract)
    expectEqual(extractEnv.0.item(id: extractEnv.3.id)?.title, "source.pdf")
    expectEqual(extractEnv.0.item(id: extractEnv.3.id)?.kind, .pdf)
    expectEqual(extractEnv.0.item(id: extractEnv.3.id)?.status, .idle)
    expectEqual(extractEnv.0.results().first?.title, "extracted.json")
    expectEqual(extractEnv.0.results().first?.kind, .markdown)
    expectEqual(extractEnv.0.results().first?.takeawayItem().displayTag, "JSON")
    expectEqual(RecipeCatalog.spec(.extract).outputKind, .markdown)
    expectEqual(try String(contentsOf: extractEnv.0.results().first!.output!, encoding: .utf8), "{\"ok\":true}")
    expectEqual(extractJob.job(id: extractID)?.recipe, .extract)
    expectEqual(extractJob.job(id: extractID)?.outputFile.lastPathComponent, "extracted.json")
    expect(extractJob.job(id: JobID(rawValue: "missing")) == nil, "missing job")

    let fenced = try setup()
    let fencedAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    fencedAgent.outputText = "```json\n{\"ok\":true}\n```"
    _ = try await JobService(shelf: fenced.0, agent: fencedAgent, jobsRoot: fenced.1)
        .start(itemIDs: [fenced.3.id], recipe: .extract)
    expectEqual(try String(contentsOf: fenced.0.results().first!.output!, encoding: .utf8), "{\"ok\":true}")
    expectEqual(RecipeOutput.finalize("```json\n{\"a\":1}\n```", fileName: "extracted.json"), "{\"a\":1}")
    expectEqual(RecipeOutput.finalize("hello", fileName: "summary.md"), "hello")
    expectEqual(RecipeOutput.finalize("{\"a\":1}", fileName: "extracted.json"), "{\"a\":1}")

    for recipe in RecipeID.allCases where recipe != .summarize && recipe != .extract && recipe != .brief {
        let env = try setup()
        let agent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
        _ = try await JobService(shelf: env.0, agent: agent, jobsRoot: env.1)
            .start(itemIDs: [env.3.id], recipe: recipe)
        let spec = RecipeCatalog.spec(recipe)
        let item = env.0.item(id: env.3.id)!
        expectEqual(item.status, .idle, recipe.rawValue)
        expectEqual(item.title, "source.pdf", recipe.rawValue)
        expectEqual(env.0.results().first?.title, spec.outputFileName, recipe.rawValue)
        expect(FileManager.default.fileExists(atPath: env.0.results().first?.output?.path ?? ""), "\(recipe.rawValue) output")
        expectEqual(try Data(contentsOf: env.2), Data("original-bytes".utf8), recipe.rawValue)
        expect(!agent.lastPrompt.contains(env.2.path), "\(recipe.rawValue) original path")
    }

    let folderEnv = try setup()
    let folder = folderEnv.1.deletingLastPathComponent().appendingPathComponent("folder", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let folderItem = try folderEnv.0.add(Item(
        kind: .folder,
        title: "folder",
        sourceURL: folder,
        parts: [ItemPart(name: "folder", url: folder)]
    ))
    do {
        _ = try await JobService(
            shelf: folderEnv.0,
            agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)),
            jobsRoot: folderEnv.1
        ).start(itemIDs: [folderItem.id], recipe: .extract)
        fail("folder extract should be rejected")
    } catch let error as JobError {
        expectEqual(error, .notStartable)
    }
    expectEqual(folderEnv.0.item(id: folderItem.id)?.status, .idle)

    let folderRoot = try tempDir()
    let originalFolder = folderRoot.appendingPathComponent("bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalFolder, withIntermediateDirectories: true)
    let notes = originalFolder.appendingPathComponent("notes.md")
    try Data("folder-notes".utf8).write(to: notes)
    let folderShelf = ShelfStore(fileURL: folderRoot.appendingPathComponent("shelf.json"))
    let folderIngest = IngestService(
        shelf: folderShelf,
        inboxRoot: folderRoot.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    if let admittedFolder = folderIngest.admit(urls: [originalFolder]).admitted.first {
        expectEqual(admittedFolder.kind, .folder)
        let folderAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
        _ = try await JobService(
            shelf: folderShelf,
            agent: folderAgent,
            jobsRoot: folderRoot.appendingPathComponent("Jobs")
        ).start(itemIDs: [admittedFolder.id], recipe: .summarize)
        expectEqual(try String(contentsOf: notes, encoding: .utf8), "folder-notes")
        let finishedFolder = folderShelf.item(id: admittedFolder.id)!
        expectEqual(finishedFolder.status, .idle)
        expectEqual(finishedFolder.title, "bundle")
        expectEqual(folderShelf.results().first?.title, "summary.md")
        expect(!folderAgent.lastPrompt.contains(originalFolder.path), "folder prompt original path")
        expect(folderAgent.lastPrompt.contains("bundle"), "folder relative name")
        let workBundle = folderAgent.lastRequest!.workdir.appendingPathComponent("bundle")
        var workIsDir: ObjCBool = false
        expect(FileManager.default.fileExists(atPath: workBundle.path, isDirectory: &workIsDir), "work has folder")
        expect(workIsDir.boolValue, "work copy is directory")
        expectEqual(try String(contentsOf: workBundle.appendingPathComponent("notes.md"), encoding: .utf8), "folder-notes")
        expect(try workBundle.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true, "folder work not symlink")
    } else {
        fail("folder admit for summarize")
    }

    let briefOne = try setup()
    do {
        _ = try await JobService(
            shelf: briefOne.0,
            agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace)),
            jobsRoot: briefOne.1
        ).start(itemIDs: [briefOne.3.id], recipe: .brief)
        fail("brief needs two items")
    } catch let error as JobError {
        expectEqual(error, .notStartable)
    }
    expectEqual(briefOne.0.item(id: briefOne.3.id)?.status, .idle)
    expectEqual(RecipeID.brief.minimumCount, 2)

    let briefRoot = try tempDir()
    let originalA = briefRoot.appendingPathComponent("a.md")
    let originalB = briefRoot.appendingPathComponent("b.md")
    try Data("alpha-source".utf8).write(to: originalA)
    try Data("beta-source".utf8).write(to: originalB)
    let briefShelf = ShelfStore(fileURL: briefRoot.appendingPathComponent("shelf.json"))
    let inboxA = briefRoot.appendingPathComponent("Inbox/a", isDirectory: true)
    let inboxB = briefRoot.appendingPathComponent("Inbox/b", isDirectory: true)
    try FileManager.default.createDirectory(at: inboxA, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: inboxB, withIntermediateDirectories: true)
    try Data("alpha-source".utf8).write(to: inboxA.appendingPathComponent("a.md"))
    try Data("beta-source".utf8).write(to: inboxB.appendingPathComponent("b.md"))
    let itemA = try briefShelf.add(Item(
        kind: .markdown,
        title: "a.md",
        sourceURL: originalA,
        parts: [ItemPart(name: "a.md", url: inboxA.appendingPathComponent("a.md"))],
        sourceChecksum: digest(originalA)
    ))
    let itemB = try briefShelf.add(Item(
        kind: .markdown,
        title: "b.md",
        sourceURL: originalB,
        parts: [ItemPart(name: "b.md", url: inboxB.appendingPathComponent("b.md"))],
        sourceChecksum: digest(originalB)
    ))
    let briefAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    briefAgent.outputText = "两份材料合成的交付"
    _ = try await JobService(
        shelf: briefShelf,
        agent: briefAgent,
        jobsRoot: briefRoot.appendingPathComponent("Jobs")
    ).start(itemIDs: [itemA.id, itemB.id], recipe: .brief)
    expectEqual(briefAgent.lastRequest?.network, false)
    expect(briefAgent.lastPrompt.contains("a.md"), "brief lists first")
    expect(briefAgent.lastPrompt.contains("b.md"), "brief lists second")
    expectEqual(try Data(contentsOf: originalA), Data("alpha-source".utf8))
    expectEqual(try Data(contentsOf: originalB), Data("beta-source".utf8))
    expectEqual(briefShelf.item(id: itemA.id)?.status, .idle)
    expectEqual(briefShelf.item(id: itemB.id)?.status, .idle)
    expectEqual(briefShelf.item(id: itemA.id)?.title, "a.md")
    expectEqual(briefShelf.item(id: itemB.id)?.title, "b.md")
    expectEqual(briefShelf.results().count, 1)
    expectEqual(briefShelf.results().first?.title, "brief.md")
    expectEqual(Set(briefShelf.results().first?.sourceItemIDs ?? []), [itemA.id, itemB.id])

    let translateEnv = try setup()
    let translateAgent = FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    _ = try await JobService(shelf: translateEnv.0, agent: translateAgent, jobsRoot: translateEnv.1)
        .start(itemIDs: [translateEnv.3.id], recipe: .translate)
    expectEqual(translateAgent.lastRequest?.network, true)
    expectEqual(translateEnv.0.item(id: translateEnv.3.id)?.title, "source.pdf")
    expectEqual(translateEnv.0.results().first?.title, "translated.md")

    let cancelEnv = try setup()
    let waiting = WaitingAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    let cancelJob = JobService(shelf: cancelEnv.0, agent: waiting, jobsRoot: cancelEnv.1)
    let cancelTask = Task {
        try await cancelJob.start(itemIDs: [cancelEnv.3.id], recipe: .summarize)
    }
    try await Task.sleep(nanoseconds: 80_000_000)
    cancelJob.cancel()
    do {
        _ = try await cancelTask.value
        fail("cancel should throw")
    } catch AgentError.cancelled {
        expectEqual(cancelEnv.0.item(id: cancelEnv.3.id)?.status, .idle)
        expectEqual(cancelEnv.0.results().count, 0)
    }

    let streamEnv = try setup()
    let streaming = StreamingAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .workspace))
    let streamJob = JobService(shelf: streamEnv.0, agent: streaming, jobsRoot: streamEnv.1)
    let streamTask = Task {
        try await streamJob.start(itemIDs: [streamEnv.3.id], recipe: .summarize)
    }
    try await Task.sleep(nanoseconds: 80_000_000)
    expectEqual(streamEnv.0.item(id: streamEnv.3.id)?.status, .running)
    expectEqual(streamEnv.0.item(id: streamEnv.3.id)?.event, "工具调用")
    _ = try await streamTask.value
    expectEqual(streamEnv.0.item(id: streamEnv.3.id)?.status, .idle)
    expectEqual(streamEnv.0.results().first?.status, .done)
}

final class WaitingAgent: AgentRunning, @unchecked Sendable {
    var settings = AgentSettings()
    var presence: AgentPresence
    private let state = OSAllocatedUnfairLock<WaitingState>(initialState: WaitingState())
    init(presence: AgentPresence) { self.presence = presence }
    func discover(settings: AgentSettings) -> AgentPresence { presence }
    func isolationCopy(for presence: AgentPresence) -> String { "" }
    func ensureInteractiveSession() throws -> SessionHandle {
        SessionHandle(executable: URL(fileURLWithPath: "/usr/bin/true"))
    }
    func cancelCurrent() {
        let pending = state.withLock { current -> CheckedContinuation<AgentRunResult, Error>? in
            current.cancelled = true
            let pending = current.continuation
            current.continuation = nil
            return pending
        }
        pending?.resume(throwing: AgentError.cancelled)
    }
    func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        if state.withLock(\.cancelled) { throw AgentError.cancelled }
        return try await withCheckedThrowingContinuation { continuation in
            let alreadyCancelled = state.withLock { current -> Bool in
                if current.cancelled { return true }
                current.continuation = continuation
                return false
            }
            if alreadyCancelled {
                continuation.resume(throwing: AgentError.cancelled)
            }
        }
    }
}

private struct WaitingState {
    var continuation: CheckedContinuation<AgentRunResult, Error>?
    var cancelled = false
}

final class StreamingAgent: AgentRunning, @unchecked Sendable {
    var settings = AgentSettings()
    var presence: AgentPresence
    init(presence: AgentPresence) { self.presence = presence }
    func discover(settings: AgentSettings) -> AgentPresence { presence }
    func isolationCopy(for presence: AgentPresence) -> String { "" }
    func ensureInteractiveSession() throws -> SessionHandle {
        SessionHandle(executable: URL(fileURLWithPath: "/usr/bin/true"))
    }
    func cancelCurrent() {}
    func run(_ request: AgentRunRequest, onEvent: (@Sendable (AgentEvent) -> Void)?) async throws -> AgentRunResult {
        onEvent?(AgentEvent(message: "工具调用"))
        try await Task.sleep(nanoseconds: 200_000_000)
        try FileManager.default.createDirectory(at: request.outputFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "streamed".write(to: request.outputFile, atomically: true, encoding: .utf8)
        return AgentRunResult(exitCode: 0, events: [AgentEvent(message: "工具调用")], lastMessage: "streamed")
    }
}

private func tui() throws {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let part = root.appendingPathComponent("a.pdf")
    try Data("x".utf8).write(to: part)
    let item = try shelf.add(Item(
        kind: .pdf,
        title: "a.pdf",
        sourceURL: URL(fileURLWithPath: "/secret/original.pdf"),
        parts: [ItemPart(name: "a.pdf", url: part)]
    ))
    let none = TUIService(shelf: shelf, agent: FakeAgent(presence: .none), inboxRoot: root.appendingPathComponent("TUIInbox"))
    do {
        _ = try none.send(itemIDs: [item.id], text: "hi")
        fail("tui no agent")
    } catch let error as TUIError {
        expectEqual(error, .noAgent)
    }
    expectEqual(shelf.item(id: item.id)?.status, .idle)

    let missing = URL(fileURLWithPath: root.appendingPathComponent("no-such-grok-\(UUID().uuidString)").path)
    do {
        _ = try TUIService(
            shelf: shelf,
            agent: FakeAgent(presence: .grok(path: missing, isolation: .tui)),
            inboxRoot: root.appendingPathComponent("MissingTUI")
        ).send(itemIDs: [item.id], text: "hi")
        fail("missing tui binary should throw")
    } catch let error as TUIError {
        expectEqual(error, .launchFailed)
    }
    expectEqual(shelf.item(id: item.id)?.status, .idle)

    let original = URL(fileURLWithPath: "/secret/original-\(UUID().uuidString).pdf")
    let copy = root.appendingPathComponent("copy.pdf")
    try Data("payload".utf8).write(to: copy)
    let item2 = try shelf.add(Item(kind: .pdf, title: "copy.pdf", sourceURL: original, parts: [ItemPart(name: "copy.pdf", url: copy)]))
    let prepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("TUIInbox")
    ).send(itemIDs: [item2.id], text: "哪几条不能对外说")
    expectEqual(shelf.item(id: item2.id)?.status, .sent)
    expect(!prepared.injection.contains(original.path), "tui original path")
    expect(prepared.injection.contains("copy.pdf"), "tui relative")
    expectEqual(try String(contentsOf: prepared.cwd.appendingPathComponent("copy.pdf"), encoding: .utf8), "payload")
    expectEqual(prepared.cwd.lastPathComponent, "session")
    expect(prepared.session.arguments.contains("-C"), "tui cd")
    expect(prepared.session.arguments.contains(prepared.cwd.path), "tui cd path")
    expect(prepared.session.arguments.contains("--no-alt-screen"), "tui no alt screen")
    expect(prepared.session.arguments.contains("--disable"), "tui disable features")
    expect(prepared.session.arguments.contains("apps"), "tui no bundled apps mcp")
    expect(prepared.session.arguments.contains("hooks"), "tui no hooks feature")
    expect(!prepared.session.arguments.contains("--dangerously-bypass-approvals-and-sandbox"), "tui no bypass")
    expect(prepared.session.environment.contains { $0 == "CODEX_HOME=\(prepared.isolatedHome.path)" }, "tui isolated home")
    expect(prepared.isolatedHome.lastPathComponent == "codex-home", "codex home dir")
    let isolatedConfig = try String(contentsOf: prepared.isolatedHome.appendingPathComponent("config.toml"), encoding: .utf8)
    expect(isolatedConfig.contains("trust_level"), "isolated trust")
    expect(isolatedConfig.contains(prepared.cwd.resolvingSymlinksInPath().path), "isolated trusts cwd")
    expect(!isolatedConfig.contains("mcp_servers"), "no user mcp")
    expect(!FileManager.default.fileExists(atPath: prepared.isolatedHome.appendingPathComponent("hooks.json").path), "no user hooks")

    let fakeUser = root.appendingPathComponent("fake-codex", isDirectory: true)
    try FileManager.default.createDirectory(at: fakeUser, withIntermediateDirectories: true)
    try Data("login-token".utf8).write(to: fakeUser.appendingPathComponent("auth.json"))
    try IsolatedCodexHome.copyLogin(from: fakeUser, into: prepared.isolatedHome)
    expectEqual(try String(contentsOf: prepared.isolatedHome.appendingPathComponent("auth.json"), encoding: .utf8), "login-token")
    let mode = (try FileManager.default.attributesOfItem(atPath: prepared.isolatedHome.appendingPathComponent("auth.json").path)[.posixPermissions] as? NSNumber)?.intValue ?? 0
    expect(mode & 0o777 == 0o600, "auth mode")

    let revertFile = root.appendingPathComponent("revert.pdf")
    try Data("revert".utf8).write(to: revertFile)
    let revertItem = try shelf.add(Item(kind: .pdf, title: "revert.pdf", sourceURL: revertFile, parts: [ItemPart(name: "revert.pdf", url: revertFile)]))
    let revertTUI = TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("RevertInbox")
    )
    _ = try revertTUI.send(itemIDs: [revertItem.id], text: "回滚")
    expectEqual(shelf.item(id: revertItem.id)?.status, .sent)
    revertTUI.revertSend(itemIDs: [revertItem.id])
    expectEqual(shelf.item(id: revertItem.id)?.status, .idle, "revert send")
    expectEqual(shelf.item(id: revertItem.id)?.isolationShown, IsolationShown.none, "revert isolation")

    let output = root.appendingPathComponent("summary.md")
    try Data("总结正文".utf8).write(to: output)
    try shelf.patch(id: item2.id) { live in
        live.status = .done
        live.output = output
        live.title = "summary.md"
    }
    let withOutput = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("TUIInbox")
    ).send(itemIDs: [item2.id], text: "看结果", sessionDirectory: prepared.cwd)
    expectEqual(shelf.item(id: item2.id)?.status, .done, "done stays drag-ready")
    expect(withOutput.injection.contains("summary.md"), "tui includes output")
    expect(!withOutput.injection.contains(original.path), "output send no original")
    expectEqual(try String(contentsOf: withOutput.cwd.appendingPathComponent("summary.md"), encoding: .utf8), "总结正文")

    let again = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .codex(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("TUIInbox")
    ).send(itemIDs: [item2.id], text: "第二句", sessionDirectory: prepared.cwd)
    expectEqual(again.cwd, prepared.cwd)
    expect(again.injection.contains("copy.pdf"), "reuse name")
    expect(again.injection.contains("第二句"), "second text")

    let grokPrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("GrokInbox")
    ).send(itemIDs: [item2.id], text: "用 Grok 看")
    expect(grokPrepared.session.arguments.contains("--cwd"), "grok cwd")
    expect(grokPrepared.session.arguments.contains("--no-alt-screen"), "grok no alt")
    expect(!grokPrepared.session.arguments.contains("--always-approve"), "grok no auto approve")
    expect(!grokPrepared.session.arguments.contains("bypassPermissions"), "grok no bypass")
    expect(grokPrepared.session.environment.contains { $0.hasPrefix("GROK_HOME=") }, "grok home")
    expectEqual(grokPrepared.isolatedHome.lastPathComponent, "grok-home")
    let grokConfig = try String(contentsOf: grokPrepared.isolatedHome.appendingPathComponent("config.toml"), encoding: .utf8)
    expect(!grokConfig.contains("mcp_servers"), "grok no mcp")
    let grokUser = root.appendingPathComponent("fake-grok", isDirectory: true)
    try FileManager.default.createDirectory(at: grokUser, withIntermediateDirectories: true)
    try Data("grok-login".utf8).write(to: grokUser.appendingPathComponent("auth.json"))
    try IsolatedGrokHome.copyLogin(from: grokUser, into: grokPrepared.isolatedHome)
    expectEqual(try String(contentsOf: grokPrepared.isolatedHome.appendingPathComponent("auth.json"), encoding: .utf8), "grok-login")

    let grokSeedUser = root.appendingPathComponent("grok-user-config", isDirectory: true)
    try FileManager.default.createDirectory(at: grokSeedUser, withIntermediateDirectories: true)
    try Data("""
    [ui]
    permission_mode = "always-approve"
    yolo = true

    [privacy]
    privacy_banner_acked = "2026-08-07T12:11:23Z"

    [mcp_servers.forklight]
    command = "/tmp/forklight"
    """.utf8).write(to: grokSeedUser.appendingPathComponent("config.toml"))
    let grokSeedHome = root.appendingPathComponent("grok-seed-home", isDirectory: true)
    try IsolatedGrokHome.prepare(at: grokSeedHome, userHome: grokSeedUser)
    let seeded = try String(contentsOf: grokSeedHome.appendingPathComponent("config.toml"), encoding: .utf8)
    expect(seeded.contains("privacy_banner_acked = \"2026-08-07T12:11:23Z\""), "copy privacy ack")
    expect(!seeded.contains("mcp_servers"), "seed has no mcp")
    expect(!seeded.contains("always-approve"), "seed has no always-approve")
    expect(!seeded.contains("yolo"), "seed has no yolo")
    try Data("keep-me\n".utf8).write(to: grokSeedHome.appendingPathComponent("config.toml"))
    try IsolatedGrokHome.prepare(at: grokSeedHome, userHome: grokSeedUser)
    expectEqual(
        try String(contentsOf: grokSeedHome.appendingPathComponent("config.toml"), encoding: .utf8),
        "keep-me\n",
        "second prepare does not overwrite"
    )

    let claudePrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .claude(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("ClaudeInbox")
    ).send(itemIDs: [item2.id], text: "用 Claude 看")
    expect(claudePrepared.session.arguments.contains("--strict-mcp-config"), "claude strict mcp")
    expect(claudePrepared.session.arguments.contains("--setting-sources"), "claude skip user settings")
    expect(!claudePrepared.session.arguments.contains("--dangerously-skip-permissions"), "claude no skip")
    expect(!claudePrepared.session.arguments.contains("--bare"), "claude keeps auth")
    expect(claudePrepared.session.environment.contains { $0.hasPrefix("CLAUDE_CONFIG_DIR=") }, "claude config dir")

    let geminiPrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .gemini(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("GeminiInbox")
    ).send(itemIDs: [item2.id], text: "用 Gemini 看")
    expect(geminiPrepared.session.arguments.contains("--prompt"), "gemini prompt")
    expect(!geminiPrepared.session.arguments.contains("--yolo"), "gemini no yolo")
    expect(geminiPrepared.session.environment.contains { $0.hasPrefix("GEMINI_CONFIG_DIR=") }, "gemini config dir")

    let opencodePrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .opencode(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("OpenCodeInbox")
    ).send(itemIDs: [item2.id], text: "用 OpenCode 看")
    expect(opencodePrepared.session.arguments.contains("--prompt"), "opencode prompt")
    expect(opencodePrepared.session.arguments.contains(opencodePrepared.cwd.path), "opencode project")
    expect(!opencodePrepared.session.arguments.contains("--auto"), "opencode no auto")
    expect(opencodePrepared.session.environment.contains { $0.hasPrefix("OPENCODE_CONFIG_DIR=") }, "opencode config dir")
    expectEqual(opencodePrepared.isolatedHome.lastPathComponent, "opencode-home")
    expect(opencodePrepared.feedOnLaunch == false, "opencode is tui")

    let cursorPrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .cursor(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("CursorInbox")
    ).send(itemIDs: [item2.id], text: "用 Cursor 看")
    expect(cursorPrepared.session.arguments.contains { $0.contains("用 Cursor 看") }, "cursor prompt")
    expect(!cursorPrepared.session.arguments.contains("--yolo"), "cursor tui no yolo")
    expect(!cursorPrepared.session.arguments.contains("--force"), "cursor tui no force")

    let llmPrepared = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .llm(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("LLMInbox")
    ).send(itemIDs: [item2.id], text: "译成中文")
    expectEqual(llmPrepared.session.arguments, ["-l"])
    expectEqual(llmPrepared.session.executable, CLICommand.shellExecutable())
    expect(llmPrepared.feedOnLaunch, "cli feeds shell")
    expect(llmPrepared.injection.contains("/usr/bin/true"), "cli binary")
    expect(llmPrepared.injection.contains("译成中文"), "cli prompt")
    expect(!llmPrepared.injection.contains(original.path), "cli no original")

    let originalBundle = root.appendingPathComponent("bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: originalBundle, withIntermediateDirectories: true)
    try Data("inside".utf8).write(to: originalBundle.appendingPathComponent("a.txt"))
    let inboxBundle = root.appendingPathComponent("inbox-bundle", isDirectory: true)
    try FileManager.default.copyItem(at: originalBundle, to: inboxBundle)
    let folderTUI = try shelf.add(Item(
        kind: .folder,
        title: "bundle",
        sourceURL: originalBundle,
        parts: [ItemPart(name: "bundle", url: inboxBundle)]
    ))
    let folderSend = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("TUIFolder")
    ).send(itemIDs: [folderTUI.id], text: "看这个目录")
    expectEqual(try String(contentsOf: folderSend.cwd.appendingPathComponent("bundle/a.txt"), encoding: .utf8), "inside")
    expectEqual(try String(contentsOf: originalBundle.appendingPathComponent("a.txt"), encoding: .utf8), "inside")
    expect(!folderSend.injection.contains(originalBundle.path), "folder tui original path")
    expect(folderSend.injection.contains("bundle"), "folder tui relative")
    expectEqual(shelf.item(id: folderTUI.id)?.status, .sent)

    let extra = root.appendingPathComponent("from-result.md")
    try Data("result-body".utf8).write(to: extra)
    let keepIdleFile = root.appendingPathComponent("keep-idle.md")
    try Data("keep".utf8).write(to: keepIdleFile)
    let keepIdle = try shelf.add(Item(
        kind: .markdown,
        title: "keep-idle.md",
        sourceURL: keepIdleFile,
        parts: [ItemPart(name: "keep-idle.md", url: keepIdleFile)]
    ))
    let extraSend = try TUIService(
        shelf: shelf,
        agent: FakeAgent(presence: .grok(path: URL(fileURLWithPath: "/usr/bin/true"), isolation: .tui)),
        inboxRoot: root.appendingPathComponent("TUIResult")
    ).send(itemIDs: [], text: "看结果", extraFiles: [extra])
    expectEqual(try String(contentsOf: extraSend.cwd.appendingPathComponent("from-result.md"), encoding: .utf8), "result-body")
    expect(extraSend.injection.contains("from-result.md"), "result file listed")
    expectEqual(extraSend.itemIDs, [])
    expectEqual(shelf.item(id: keepIdle.id)?.status, .idle, "sending a result does not mark inputs sent")
    expectEqual(shelf.item(id: folderTUI.id)?.status, .sent, "extra files do not patch other items")
}

private func pasteboard() throws {
    let root = try tempDir()
    let file = root.appendingPathComponent("note.md")
    try Data("hello".utf8).write(to: file)
    let md = Item(kind: .markdown, title: "note.md", sourceURL: file, parts: [ItemPart(name: "note.md", url: file)])
    let mdRep = PasteboardService.representation(for: md)
    expectEqual(mdRep.plainText, "hello")
    expect(mdRep.utis.contains(UTType.fileURL.identifier), "file uti")
    expect(mdRep.utis.contains(UTType.utf8PlainText.identifier), "text uti")

    let zipPath = root.appendingPathComponent("archive.zip")
    try Data("PK".utf8).write(to: zipPath)
    let zipItem = Item(kind: .file, title: "archive.zip", sourceURL: zipPath, parts: [ItemPart(name: "archive.zip", url: zipPath)])
    let zipRep = PasteboardService.representation(for: zipItem)
    expectEqual(zipRep.fileURLs.map(\.lastPathComponent), ["archive.zip"])
    expect(zipRep.plainText == nil, "zip is not text")
    expect(zipRep.utis.contains(UTType.fileURL.identifier), "zip file uti")

    let link = URL(string: "https://example.com")!
    let linkFile = root.appendingPathComponent("link.txt")
    try Data(link.absoluteString.utf8).write(to: linkFile)
    let urlItem = Item(kind: .url, title: "example.com", sourceURL: link, parts: [ItemPart(name: "link.txt", url: linkFile)])
    let urlRep = PasteboardService.representation(for: urlItem)
    expect(urlRep.fileURLs.isEmpty, "url has no staged file")
    expectEqual(urlRep.plainText, link.absoluteString)
    expectEqual(urlRep.webURL, Optional(link))
    expect(PasteboardService.promisedUTIs(for: urlItem).contains(UTType.url.identifier), "url uti")
    expect(!PasteboardService.promisedUTIs(for: urlItem).contains(UTType.fileURL.identifier), "url no file uti")
    let urlBoard = NSPasteboard.withUniqueName()
    PasteboardService.copy(urlItem, to: urlBoard)
    let urlFiles = urlBoard.readObjects(forClasses: [NSURL.self], options: [
        .urlReadingFileURLsOnly: true
    ]) as? [URL] ?? []
    expect(urlFiles.isEmpty, "url copy has no file")
    expectEqual(urlBoard.string(forType: .string), link.absoluteString)

    let folder = root.appendingPathComponent("web", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let page = folder.appendingPathComponent("page.md")
    try Data("# page".utf8).write(to: page)
    let png = folder.appendingPathComponent("snapshot.png")
    try raster(.png).write(to: png)
    let urlFile = folder.appendingPathComponent("url.txt")
    try Data("https://example.com".utf8).write(to: urlFile)
    let web = Item(
        kind: .web,
        title: "Example",
        sourceURL: URL(string: "https://example.com")!,
        parts: [
            ItemPart(name: "url.txt", url: urlFile),
            ItemPart(name: "page.md", url: page),
            ItemPart(name: "snapshot.png", url: png),
        ]
    )
    let webRep = PasteboardService.representation(for: web)
    expectEqual(webRep.fileURLs.first?.lastPathComponent, "Example")
    expect(webRep.fileURLs.first != folder, "web drag is a named copy")
    expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("page.md").path), "inbox web folder stays")
    expect(FileManager.default.fileExists(atPath: webRep.fileURLs[0].appendingPathComponent("page.md").path), "named web folder has page.md")
    expectEqual(webRep.plainText, "# page")
    expect(webRep.pngData?.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) == true, "web png flavor")

    let slashWeb = Item(
        kind: .web,
        title: "Foo/Bar:Baz",
        sourceURL: URL(string: "https://example.com/x")!,
        parts: web.parts
    )
    expectEqual(PasteboardService.representation(for: slashWeb).fileURLs.first?.lastPathComponent, "Foo-Bar-Baz")
    let blankWeb = Item(
        kind: .web,
        title: "  ",
        sourceURL: URL(string: "https://example.com/y")!,
        parts: web.parts
    )
    expectEqual(PasteboardService.representation(for: blankWeb).fileURLs.first?.lastPathComponent, "网站")

    let output = root.appendingPathComponent("summary.md")
    try Data("result".utf8).write(to: output)
    let done = Item(
        kind: .markdown,
        title: "summary.md",
        sourceURL: URL(fileURLWithPath: "/tmp/source.pdf"),
        parts: [ItemPart(name: "source.pdf", url: URL(fileURLWithPath: "/tmp/source.pdf"))],
        status: .done,
        output: output
    )
    expectEqual(PasteboardService.representation(for: done).fileURLs, [output])
    expectEqual(PasteboardService.representation(for: done).plainText, "result")
    expect(!PasteboardService.export(done).isEmpty, "export writers")

    let pasteboard = NSPasteboard.withUniqueName()
    PasteboardService.copy(done, to: pasteboard)
    let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
        .urlReadingFileURLsOnly: true
    ]) as? [URL] ?? []
    expectEqual(urls.first?.path, output.path)
    let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    let landed = desktop.appendingPathComponent("summary.md")
    guard let fromBoard = urls.first else {
        fail("pasteboard missing file url")
        return
    }
    try FileManager.default.copyItem(at: fromBoard, to: landed)
    expectEqual(try String(contentsOf: landed, encoding: .utf8), "result")

    let jpegFile = root.appendingPathComponent("photo.jpg")
    try raster(.jpeg).write(to: jpegFile)
    let jpegItem = Item(
        kind: .image,
        title: "photo.jpg",
        sourceURL: jpegFile,
        parts: [ItemPart(name: "photo.jpg", url: jpegFile)]
    )
    let jpegRep = PasteboardService.representation(for: jpegItem)
    expectEqual(jpegRep.fileURLs, [jpegFile])
    let jpegPNG = jpegRep.pngData ?? Data()
    expect(jpegPNG.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]), "jpeg exports png magic")
    expect(!jpegPNG.starts(with: [0xFF, 0xD8]), "jpeg flavor is not jpeg bytes")

    let pngFile = root.appendingPathComponent("shot.png")
    let pngBytes = raster(.png)
    try pngBytes.write(to: pngFile)
    let pngItem = Item(
        kind: .image,
        title: "shot.png",
        sourceURL: pngFile,
        parts: [ItemPart(name: "shot.png", url: pngFile)]
    )
    expectEqual(PasteboardService.representation(for: pngItem).pngData, pngBytes)
}

private func pasteboardDragLandsFile() async throws {
    let root = try tempDir()
    let output = root.appendingPathComponent("summary.md")
    try Data("result-from-drag\n".utf8).write(to: output)
    let done = Item(
        kind: .markdown,
        title: "summary.md",
        sourceURL: URL(fileURLWithPath: "/tmp/source.pdf"),
        parts: [ItemPart(name: "source.pdf", url: URL(fileURLWithPath: "/tmp/source.pdf"))],
        status: .done,
        output: output
    )
    let provider = PasteboardService.itemProvider(for: done)
    expect(!provider.registeredTypeIdentifiers.isEmpty, "drag types")
    let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    let source = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 1))
                }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let url = item as? URL {
                continuation.resume(returning: url)
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                continuation.resume(returning: url)
            } else {
                continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 2))
            }
        }
    }
    expectEqual(source.lastPathComponent, "summary.md")
    let landed = desktop.appendingPathComponent(source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: landed)
    expectEqual(try String(contentsOf: landed, encoding: .utf8), "result-from-drag\n")
}

private func pasteboardWebFolderLands() async throws {
    let root = try tempDir()
    let folder = root.appendingPathComponent("site", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let page = folder.appendingPathComponent("page.md")
    let shot = folder.appendingPathComponent("snapshot.png")
    let link = folder.appendingPathComponent("url.txt")
    try Data("# page body".utf8).write(to: page)
    try Data([0x89, 0x50, 0x4E, 0x47]).write(to: shot)
    try Data("https://example.com".utf8).write(to: link)
    let web = Item(
        kind: .web,
        title: "Example",
        sourceURL: URL(string: "https://example.com")!,
        parts: [
            ItemPart(name: "url.txt", url: link),
            ItemPart(name: "page.md", url: page),
            ItemPart(name: "snapshot.png", url: shot),
        ]
    )
    let provider = PasteboardService.itemProvider(for: web)
    let source = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 3)) }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let url = item as? URL {
                continuation.resume(returning: url)
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                continuation.resume(returning: url)
            } else {
                continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 4))
            }
        }
    }
    var isDir: ObjCBool = false
    expect(FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir), "web folder exists")
    expect(isDir.boolValue, "web drag is a folder")
    expectEqual(source.lastPathComponent, "Example")
    expect(FileManager.default.fileExists(atPath: source.appendingPathComponent("page.md").path), "folder has page.md")
    expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("page.md").path), "inbox site folder stays")
    let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    let landed = desktop.appendingPathComponent(source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: landed)
    expectEqual(try String(contentsOf: landed.appendingPathComponent("page.md"), encoding: .utf8), "# page body")
}

private func pasteboardFolderLands() async throws {
    let root = try tempDir()
    let original = root.appendingPathComponent("bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
    try Data("folder-notes".utf8).write(to: original.appendingPathComponent("notes.md"))
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    guard let item = ingest.admit(urls: [original]).admitted.first else {
        fail("folder admit for drag")
        return
    }
    expectEqual(item.kind, .folder)
    expect(item.parts.first?.url.path.hasSuffix("/") == false, "inbox folder has no trailing slash")
    let provider = PasteboardService.itemProvider(for: item)
    expect(
        provider.registeredTypeIdentifiers.contains { identifier in
            identifier == UTType.folder.identifier || identifier == UTType.fileURL.identifier
        },
        "folder drag types"
    )
    let source = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 5)) }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let url = item as? URL {
                continuation.resume(returning: url)
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                continuation.resume(returning: url)
            } else {
                continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 6))
            }
        }
    }
    var isDir: ObjCBool = false
    expect(FileManager.default.fileExists(atPath: source.path, isDirectory: &isDir), "dir drag exists")
    expect(isDir.boolValue, "dir drag is a folder")
    expectEqual(try String(contentsOf: source.appendingPathComponent("notes.md"), encoding: .utf8), "folder-notes")
    let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    let landed = desktop.appendingPathComponent(source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: landed)
    expectEqual(try String(contentsOf: landed.appendingPathComponent("notes.md"), encoding: .utf8), "folder-notes")
    expectEqual(try String(contentsOf: original.appendingPathComponent("notes.md"), encoding: .utf8), "folder-notes")
}

private func pasteboardClipLands() async throws {
    let root = try tempDir()
    let clipFile = root.appendingPathComponent("clip.txt")
    try Data("渠道折扣从 14% 收到 9%。".utf8).write(to: clipFile)
    let clip = Item(
        kind: .clip,
        title: "剪贴板",
        sourceURL: clipFile,
        parts: [ItemPart(name: "clip.txt", url: clipFile)]
    )
    let rep = PasteboardService.representation(for: clip)
    expectEqual(rep.plainText, "渠道折扣从 14% 收到 9%。")
    expectEqual(rep.fileURLs.map(\.lastPathComponent), ["clip.txt"])
    let provider = PasteboardService.itemProvider(for: clip)
    let source = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 7)) }
            }
            return
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let url = item as? URL {
                continuation.resume(returning: url)
            } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                continuation.resume(returning: url)
            } else {
                continuation.resume(throwing: error ?? NSError(domain: "DropAgentCheck", code: 8))
            }
        }
    }
    expectEqual(source.lastPathComponent, "clip.txt")
    expectEqual(try String(contentsOf: source, encoding: .utf8), "渠道折扣从 14% 收到 9%。")
    let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
    try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
    let landed = desktop.appendingPathComponent(source.lastPathComponent)
    try FileManager.default.copyItem(at: source, to: landed)
    expectEqual(try String(contentsOf: landed, encoding: .utf8), "渠道折扣从 14% 收到 9%。")
}

private func captureService() async throws {
    let service = CaptureService(
        browser: StubBrowser(result: .failure(.unsupportedBrowser)),
        fetcher: StubFetcher(result: .success(Data())),
        snapshot: StubSnapshot(data: nil)
    )
    do {
        _ = try await service.captureFrontBrowser()
        fail("unsupported should throw")
    } catch let error as CaptureError {
        expectEqual(error, .unsupportedBrowser)
    }

    let url = URL(string: "https://example.com/page")!
    let page = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .failure(CaptureError.noURL)),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    expectEqual(page.url, url)
    expect(page.markdown == nil, "markdown nil")
    expect(page.failures.contains(.network), "network failure")

    let linked = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .success(Data("<article><p><a href=\"/x\">go</a></p></article>".utf8))),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    let linkedText = String(decoding: linked.markdown ?? Data(), as: UTF8.self)
    expect(linkedText.contains("[go](https://example.com/x)"), "capture resolves relative links")

    let fallback = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .success(Data("<html><p>Hi</p></html>".utf8))),
        snapshot: StubSnapshot(data: nil),
        pageSnapshot: StubPageSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    expect(fallback.snapshotPNG != nil, "page snapshot fallback")
    expect(!fallback.failures.contains(.snapshotMissing), "fallback not labeled missing")

    let missingShot = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .success(Data("<html><p>Hi</p></html>".utf8))),
        snapshot: StubSnapshot(data: nil),
        pageSnapshot: NullPageSnapshot()
    ).captureFrontBrowser()
    expect(missingShot.snapshotPNG == nil, "nil png")
    expect(missingShot.failures.contains(.snapshotMissing), "snapshot missing labeled")

    let linkedBare = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .success(Data("<html><p><a href=\"/docs\">Docs</a></p></html>".utf8))),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    let body = String(data: linkedBare.markdown ?? Data(), encoding: .utf8) ?? ""
    expect(body.contains("[Docs](https://example.com/docs)"), "capture resolves relative links without article")

    let recorder = RecordingBrowser()
    let pinned = BrowserFront(kind: .safari, pid: 4242)
    _ = try await CaptureService(
        browser: recorder,
        fetcher: StubFetcher(result: .failure(CaptureError.noURL)),
        snapshot: StubSnapshot(data: nil),
        pageSnapshot: StubPageSnapshot(data: Data([0x89]))
    ).captureFrontBrowser(target: pinned)
    expectEqual(recorder.seen, 4242)

    let snap = RecordingSnap()
    _ = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Example"))),
        fetcher: StubFetcher(result: .failure(CaptureError.noURL)),
        snapshot: snap
    ).captureFrontBrowser(target: pinned)
    expectEqual(snap.pid, 4242)

    let untitled = try await CaptureService(
        browser: StubBrowser(result: .success((url, "未命名 — Safari"))),
        fetcher: StubFetcher(result: .success(Data(
            "<html><head><title>Example Domain</title></head><p>Hi</p></html>".utf8
        ))),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    expectEqual(untitled.title, "Example Domain")

    let kept = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Keep Me"))),
        fetcher: StubFetcher(result: .success(Data(
            "<html><head><title>Other</title></head><p>Hi</p></html>".utf8
        ))),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    expectEqual(kept.title, "Keep Me")

    let hostFallback = try await CaptureService(
        browser: StubBrowser(result: .success((url, "Untitled"))),
        fetcher: StubFetcher(result: .failure(CaptureError.noURL)),
        snapshot: StubSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureFrontBrowser()
    expectEqual(hostFallback.title, "example.com")

    let dropSnap = RecordingSnap()
    let dropped = await CaptureService(
        browser: FailBrowser(),
        fetcher: StubFetcher(result: .success(Data(
            "<html><head><title>Dropped Title</title></head><p>Hi</p></html>".utf8
        ))),
        snapshot: dropSnap,
        pageSnapshot: StubPageSnapshot(data: Data([0x89, 0x50, 0x4E, 0x47]))
    ).captureURL(URL(string: "https://example.com/drop")!)
    expectEqual(dropped.title, "Dropped Title")
    expect(dropped.markdown != nil, "drop capture has markdown")
    expect(dropped.snapshotPNG != nil, "drop capture uses page snapshot")
    expectEqual(dropSnap.pid, -1)
    expect(dropped.failures.isEmpty, "drop capture no failures")

    let sheet: [String: Any] = [
        kCGWindowOwnerPID as String: pid_t(99),
        kCGWindowLayer as String: 0,
        kCGWindowNumber as String: CGWindowID(1),
        kCGWindowBounds as String: ["Width": 420, "Height": 160],
    ]
    let mainWindow: [String: Any] = [
        kCGWindowOwnerPID as String: pid_t(99),
        kCGWindowLayer as String: 0,
        kCGWindowNumber as String: CGWindowID(7),
        kCGWindowBounds as String: ["Width": 1440, "Height": 900],
    ]
    expectEqual(FrontWindowSnapshot.preferredWindowNumber(from: [sheet, mainWindow], pid: 99), CGWindowID(7))
    expect(FrontWindowSnapshot.preferredWindowNumber(from: [sheet], pid: 12) == nil, "other pid ignored")
}

private final class RecordingBrowser: FrontBrowserReading, @unchecked Sendable {
    var seen: pid_t = 0
    func frontPage(of target: BrowserFront?) throws -> (url: URL, title: String) {
        seen = target?.pid ?? 0
        return (URL(string: "https://example.com")!, "Example")
    }
}

private final class RecordingSnap: WindowSnapshotting, @unchecked Sendable {
    var pid: pid_t = -1
    func snapshotFrontWindow(of pid: pid_t) async throws -> Data? {
        self.pid = pid
        return Data([0x89, 0x50, 0x4E, 0x47])
    }
}

private func liveWebAdmit() async throws {
    let url = URL(string: "https://example.com/")!
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(
            browser: StubBrowser(result: .success((url, "Example Domain"))),
            fetcher: URLSessionFetcher(),
            snapshot: StubSnapshot(data: nil),
            pageSnapshot: URLPageSnapshot()
        )
    )
    let item = try await ingest.admitCurrentPage()
    expectEqual(item.kind, .web)
    expectEqual(item.status, .idle)
    expectEqual(item.title, "Example Domain")
    expectEqual(item.sourceURL, url)
    expect(item.parts.contains { $0.name == "url.txt" }, "url.txt")
    expect(item.parts.contains { $0.name == "page.md" }, "page.md")
    expect(item.parts.contains { $0.name == "snapshot.png" }, "snapshot.png")
    expectEqual(shelf.items().count, 1)
    let urlText = item.parts.first { $0.name == "url.txt" }.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) }
    expectEqual(urlText, "https://example.com/\n")
    let png = item.parts.first { $0.name == "snapshot.png" }.flatMap { try? Data(contentsOf: $0.url) }
    expect((png?.count ?? 0) > 32, "live web png")
    let md = item.parts.first { $0.name == "page.md" }.flatMap { try? String(contentsOf: $0.url, encoding: .utf8) }
    expect((md?.isEmpty ?? true) == false, "live web markdown")
    expect(md?.hasSuffix("\n") == true, "page.md newline")
    expect(!(md?.split(whereSeparator: \.isNewline).contains(where: { $0 == "-" }) ?? true), "live example.md no empty list")
    fputs("live web admit: WEB \(item.title) png=\(png?.count ?? 0) md=\(md?.count ?? 0)\n", stdout)
}

private func captureDoesNotInvent() async throws {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    do {
        _ = try await ingest.admitCurrentPage()
        fail("capture should fail")
    } catch let error as IngestError {
        expectEqual(error, .captureFailed)
    }
    expect(shelf.items().isEmpty, "no fake web item")
}

private func appDoesNotImportCapture() throws {
    let appDir = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("App")
    let files = try FileManager.default.contentsOfDirectory(at: appDir, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "swift" }
    expect(files.isEmpty == false, "app sources exist")
    for file in files {
        let text = try String(contentsOf: file, encoding: .utf8)
        expect(text.contains("import DropAgentCapture") == false, "\(file.lastPathComponent) imports Capture")
    }
}

private func liveCapture() async throws {
    if try await captureFrontPageIntoShelf() {
        return
    }
}

private func captureFrontPageIntoShelf() async throws -> Bool {
    let root = try tempDir()
    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(
            browser: AppleScriptBrowser(allowAppleScript: false),
            fetcher: URLSessionFetcher(),
            snapshot: FrontWindowSnapshot(),
            pageSnapshot: URLPageSnapshot()
        )
    )
    do {
        let item = try await ingest.admitCurrentPage()
        expectEqual(item.kind, .web, "live web kind")
        expect(item.sourceURL.scheme == "http" || item.sourceURL.scheme == "https", "live web url")
        expect(shelf.items().count == 1, "live web on shelf")
        expect(item.parts.contains { $0.name == "url.txt" }, "live url.txt")
        fputs("live capture: WEB \(item.title) \(item.sourceURL.absoluteString)\n", stdout)
        return true
    } catch {
        fputs("live capture: \(error)\n", stdout)
        return false
    }
}

private func liveGrok() async throws {
    let home = FileManager.default.homeDirectoryForCurrentUser
    let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
    var settings = AgentSettings()
    settings.tuiEngine = .grok
    let agent = AgentService(runner: StubExecutor(), settings: settings, pathEnvironment: pathEnv, home: home)
    let presence = agent.tuiPresence(settings: settings)
    guard case .grok(let path, _) = presence else {
        fail("live Grok executable not found")
        return
    }
    fputs("live Grok: \(path.path)\n", stdout)
    fflush(stdout)

    let root = try tempDir()
    let original = root.appendingPathComponent("note.md")
    let body = "渠道折扣收到 9%。这是给 DropAgent 验收用的短材料。"
    try Data(body.utf8).write(to: original)
    let before = digest(original)

    let shelf = ShelfStore(fileURL: root.appendingPathComponent("shelf.json"))
    let ingest = IngestService(
        shelf: shelf,
        inboxRoot: root.appendingPathComponent("Inbox"),
        capture: CaptureService(browser: FailBrowser(), fetcher: FailFetch(), snapshot: FailSnap())
    )
    let admitted = ingest.admit(urls: [original])
    expect(admitted.failures.isEmpty, "live grok admit")
    guard let item = admitted.admitted.first else {
        fail("live grok admit produced no item")
        return
    }
    expectEqual(item.status, .idle)

    let prepared = try TUIService(
        shelf: shelf,
        agent: agent,
        inboxRoot: root.appendingPathComponent("TUIInbox")
    ).send(itemIDs: [item.id], text: "读一下这份材料")

    expectEqual(digest(original), before, "grok original hash")
    expectEqual(try String(contentsOf: original, encoding: .utf8), body)
    expectEqual(shelf.item(id: item.id)?.status, .sent)
    expectEqual(prepared.session.executable, path)
    expect(prepared.session.arguments.contains("--cwd"), "grok cwd")
    expect(prepared.session.arguments.contains("--no-alt-screen"), "grok no alt")
    expect(!prepared.session.arguments.contains("--always-approve"), "grok no auto approve")
    expect(prepared.session.environment.contains { $0.hasPrefix("GROK_HOME=") }, "grok home")
    expect(!prepared.injection.contains(original.path), "grok prompt original path")
    expect(prepared.injection.contains("note.md"), "grok relative")
    expectEqual(try String(contentsOf: prepared.cwd.appendingPathComponent("note.md"), encoding: .utf8), body)
    expect(try prepared.cwd.appendingPathComponent("note.md").resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true, "grok symlink")
    fputs("live Grok send: cwd=\(prepared.cwd.path)\n", stdout)
    fflush(stdout)
}
