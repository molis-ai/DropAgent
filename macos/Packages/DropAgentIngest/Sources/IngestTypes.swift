import Foundation
import DropAgentShelf

public enum IngestError: Error, Equatable, Sendable {
    case missingSource
    case unsupported
    case emptyClipboard
    case captureFailed
    case symlinkRejected
}

public struct AdmitFailure: Equatable, Sendable {
    public var url: URL
    public var error: IngestError

    public init(url: URL, error: IngestError) {
        self.url = url
        self.error = error
    }
}

public struct AdmitResult: Equatable, Sendable {
    public var admitted: [Item]
    public var failures: [AdmitFailure]
    public var pageCaptureIDs: [ItemID]

    public init(admitted: [Item], failures: [AdmitFailure], pageCaptureIDs: [ItemID] = []) {
        self.admitted = admitted
        self.failures = failures
        self.pageCaptureIDs = pageCaptureIDs
    }
}

public protocol ClipboardReading: Sendable {
    func read() -> ClipboardPayload
}

public enum ClipboardPayload: Equatable, Sendable {
    case empty
    case files([URL])
    case image(Data)
    case text(String)
}
