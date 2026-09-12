import Foundation

public struct ResultID: Hashable, Codable, Sendable, RawRepresentable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID().uuidString
    }
}

public enum ResultStatus: String, Codable, Sendable {
    case done
    case failed
}

public struct ResultRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: ResultID
    public var sourceItemIDs: [ItemID]
    public var recipe: String
    public var title: String
    public var kind: ItemKind
    public var output: URL?
    public var isolationShown: IsolationShown
    public var createdAt: Date
    public var status: ResultStatus
    public var failureReason: String?

    public init(
        id: ResultID = ResultID(),
        sourceItemIDs: [ItemID],
        recipe: String,
        title: String,
        kind: ItemKind,
        output: URL? = nil,
        isolationShown: IsolationShown = .none,
        createdAt: Date = Date(),
        status: ResultStatus = .done,
        failureReason: String? = nil
    ) {
        self.id = id
        self.sourceItemIDs = sourceItemIDs
        self.recipe = recipe
        self.title = title
        self.kind = kind
        self.output = output
        self.isolationShown = isolationShown
        self.createdAt = createdAt
        self.status = status
        self.failureReason = failureReason
    }

    public var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "H:mm"
        return formatter.string(from: createdAt)
    }

    public static func uniqueTitle(_ base: String, among titles: [String]) -> String {
        if titles.contains(base) == false { return base }
        let ext = URL(fileURLWithPath: base).pathExtension
        let stem = ext.isEmpty ? base : String(base.dropLast(ext.count + 1))
        var n = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem) \(n)" : "\(stem) \(n).\(ext)"
            if titles.contains(candidate) == false { return candidate }
            n += 1
        }
    }

    public func takeawayItem() -> Item {
        let url = output ?? URL(fileURLWithPath: "/tmp/\(title)")
        return Item(
            id: ItemID(rawValue: id.rawValue),
            kind: kind,
            title: title,
            sourceURL: url,
            parts: [ItemPart(name: title, url: url)],
            status: status == .done ? .done : .failed,
            recipe: recipe,
            output: output,
            isolationShown: isolationShown,
            createdAt: createdAt,
            failureReason: failureReason
        )
    }
}
