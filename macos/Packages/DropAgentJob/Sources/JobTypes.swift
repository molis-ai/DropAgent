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
    case missingOutput
}

public struct CustomJobSpec: Equatable, Sendable {
    public var title: String
    public var prompt: String
    public var outputFileName: String
    public var acceptedKinds: Set<ItemKind>

    public init(title: String, prompt: String, outputFileName: String, acceptedKinds: Set<ItemKind>) {
        self.title = title
        self.prompt = prompt
        self.outputFileName = outputFileName
        self.acceptedKinds = acceptedKinds
    }
}
