import Foundation

public enum CaptureFailure: String, Equatable, Sendable {
    case markdownMissing = "正文未抓到"
    case snapshotMissing = "截图未抓到"
    case network = "正文没拉下来"
    case unsupportedBrowser = "没读到当前页"
}

public struct PageCapture: Equatable, Sendable {
    public var url: URL
    public var title: String
    public var markdown: Data?
    public var snapshotPNG: Data?
    public var failures: [CaptureFailure]

    public init(url: URL, title: String, markdown: Data?, snapshotPNG: Data?, failures: [CaptureFailure]) {
        self.url = url
        self.title = title
        self.markdown = markdown
        self.snapshotPNG = snapshotPNG
        self.failures = failures
    }
}

public enum CaptureError: Error, Equatable, Sendable {
    case unsupportedBrowser
    case noURL
}

public protocol FrontBrowserReading: Sendable {
    func frontPage(of target: BrowserFront?) throws -> (url: URL, title: String)
}

public protocol PageFetching: Sendable {
    func fetchHTML(url: URL) async throws -> Data
}

public protocol WindowSnapshotting: Sendable {
    func snapshotFrontWindow(of pid: pid_t) async throws -> Data?
}

public struct CaptureService: Sendable {
    private let browser: FrontBrowserReading
    private let fetcher: PageFetching
    private let snapshot: WindowSnapshotting
    private let pageSnapshot: PageSnapshotting

    public init(
        browser: FrontBrowserReading,
        fetcher: PageFetching,
        snapshot: WindowSnapshotting,
        pageSnapshot: PageSnapshotting = NullPageSnapshot()
    ) {
        self.browser = browser
        self.fetcher = fetcher
        self.snapshot = snapshot
        self.pageSnapshot = pageSnapshot
    }

    public func captureFrontBrowser(target: BrowserFront? = nil) async throws -> PageCapture {
        let page: (url: URL, title: String)
        do {
            let browser = self.browser
            page = try await Task.detached {
                try browser.frontPage(of: target)
            }.value
        } catch CaptureError.unsupportedBrowser {
            throw CaptureError.unsupportedBrowser
        } catch {
            throw CaptureError.noURL
        }
        let pid = target?.pid ?? BrowserFront.current()?.pid ?? 0
        return await fillPage(url: page.url, title: page.title, windowPID: pid)
    }

    public func captureURL(_ url: URL, title: String = "") async -> PageCapture {
        await fillPage(url: url, title: title, windowPID: nil)
    }

    private func fillPage(url: URL, title: String, windowPID: pid_t?) async -> PageCapture {
        var failures: [CaptureFailure] = []
        var markdown: Data?
        var htmlText: String?
        do {
            let html = try await fetcher.fetchHTML(url: url)
            let decoded = String(decoding: html, as: UTF8.self)
            htmlText = decoded
            let text = HTMLMarkdown.convert(decoded, baseURL: url)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(.markdownMissing)
            } else {
                markdown = Data(text.utf8)
            }
        } catch {
            failures.append(.network)
        }

        var png: Data?
        if let windowPID {
            do {
                png = try await snapshot.snapshotFrontWindow(of: windowPID)
            } catch {
                png = nil
            }
        }
        if png == nil {
            png = await pageSnapshot.snapshotPage(url: url)
        }
        if png == nil {
            failures.append(.snapshotMissing)
        }

        return PageCapture(
            url: url,
            title: PageTitle.resolved(browserTitle: title, url: url, html: htmlText),
            markdown: markdown,
            snapshotPNG: png,
            failures: failures
        )
    }
}

public enum PageTitle {
    public static func resolved(browserTitle: String, url: URL, html: String?) -> String {
        let browser = cleaned(browserTitle)
        if isUsable(browser, url: url) { return browser }
        if let html, let fromHTML = HTMLMarkdown.documentTitle(html), isUsable(fromHTML, url: url) {
            return fromHTML
        }
        if let host = url.host, host.isEmpty == false { return host }
        return url.absoluteString
    }

    public static func cleaned(_ title: String) -> String {
        var text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffixes = [
            " - Google Chrome",
            " — Google Chrome",
            " - Microsoft Edge",
            " - Brave",
            " - Safari",
            " — Safari",
            " – Safari",
        ]
        for suffix in suffixes where text.hasSuffix(suffix) {
            text = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    public static func isUsable(_ title: String, url: URL) -> Bool {
        if title.isEmpty { return false }
        if title == url.absoluteString { return false }
        switch title.lowercased() {
        case "未命名", "untitled", "untitled page", "new tab", "新标签页", "新分頁",
             "safari", "chrome", "google chrome", "microsoft edge", "brave":
            return false
        default:
            return true
        }
    }
}
