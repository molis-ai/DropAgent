import DropAgentAgent
import DropAgentShelf
import Foundation

public struct PreparedTUISend: Equatable, Sendable {
    public var cwd: URL
    public var session: SessionHandle
    public var injection: String
    public var itemIDs: [ItemID]
    public var isolatedHome: URL
    public var feedOnLaunch: Bool
}

public enum TUIError: Error, Equatable, Sendable {
    case noAgent
    case empty
    case missingItem
    case launchFailed
}
