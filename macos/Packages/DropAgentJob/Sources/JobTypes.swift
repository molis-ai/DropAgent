import DropAgentShelf
import Foundation

public struct JobID: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init() { self.rawValue = UUID().uuidString }
}

public struct JobRecord: Equatable, Sendable {
    public var id: JobID
    public var recipe: RecipeID
    public var itemIDs: [ItemID]
    public var directory: URL
    public var outputFile: URL
}

public enum JobError: Error, Equatable, Sendable {
    case noAgent
    case emptySelection
    case notStartable
    case missingItem
}
