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
