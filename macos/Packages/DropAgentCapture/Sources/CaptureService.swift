import Foundation

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
