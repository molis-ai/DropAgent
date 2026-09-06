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

        var failures: [CaptureFailure] = []
        var markdown: Data?
        do {
            let html = try await fetcher.fetchHTML(url: page.url)
            let text = HTMLMarkdown.convert(String(decoding: html, as: UTF8.self), baseURL: page.url)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                failures.append(.markdownMissing)
            } else {
                markdown = Data(text.utf8)
            }
        } catch {
            failures.append(.network)
        }

        var png: Data?
        do {
            let pid = target?.pid ?? BrowserFront.current()?.pid ?? 0
            png = try await snapshot.snapshotFrontWindow(of: pid)
        } catch {
            png = nil
        }
        if png == nil {
            png = await pageSnapshot.snapshotPage(url: page.url)
        }
        if png == nil {
            failures.append(.snapshotMissing)
        }

        return PageCapture(
            url: page.url,
            title: page.title.isEmpty ? page.url.absoluteString : page.title,
            markdown: markdown,
            snapshotPNG: png,
            failures: failures
        )
    }
}
