import Foundation

public enum PushTag: String, CaseIterable, Codable {
    case push = "推"
    case boo = "噓"
    case arrow = "→"
    case other = "•"

    public var title: String {
        return self.rawValue
    }

    public static func from(rawString: String) -> PushTag {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("推") { return .push }
        if trimmed.contains("噓") { return .boo }
        if trimmed.contains("→") { return .arrow }
        return .other
    }
}

public struct PTTMessage: Identifiable, Equatable {
    public let id: UUID
    public let tag: PushTag
    public let userId: String
    public let content: String
    public let ipDateTime: String
    public let timestamp: Date
    public let articleTitle: String
    public let articleUrl: URL?
    public let boardName: String
    public let dedupKey: String

    public init(
        id: UUID = UUID(),
        tag: PushTag,
        userId: String,
        content: String,
        ipDateTime: String,
        timestamp: Date = Date(),
        articleTitle: String,
        articleUrl: URL?,
        boardName: String
    ) {
        self.id = id
        self.tag = tag
        self.userId = userId
        self.content = content
        self.ipDateTime = ipDateTime
        self.timestamp = timestamp
        self.articleTitle = articleTitle
        self.articleUrl = articleUrl
        self.boardName = boardName
        self.dedupKey = "\(boardName)_\(articleUrl?.path ?? "")_\(userId)_\(content)_\(ipDateTime)"
    }
}
