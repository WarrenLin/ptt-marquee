import Foundation

public struct PTTBoard: Identifiable, Hashable, Codable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let isOver18: Bool

    public init(name: String, displayName: String, isOver18: Bool = true) {
        self.name = name
        self.displayName = displayName
        self.isOver18 = isOver18
    }

    /// 首次啟動（尚未記憶任何看板）時使用的看板
    public static let defaultBoardName = "Stock"

    public static let presetBoards: [PTTBoard] = [
        PTTBoard(name: "Gossiping", displayName: "八卦板 (Gossiping)", isOver18: true),
        PTTBoard(name: "Stock", displayName: "股板 (Stock)", isOver18: false),
        PTTBoard(name: "Baseball", displayName: "棒球板 (Baseball)", isOver18: false),
        PTTBoard(name: "C_Chat", displayName: "希洽板 (C_Chat)", isOver18: false),
        PTTBoard(name: "NBA", displayName: "NBA板 (NBA)", isOver18: false),
        PTTBoard(name: "LoL", displayName: "英雄聯盟 (LoL)", isOver18: false),
        PTTBoard(name: "Lifeismoney", displayName: "省錢板 (Lifeismoney)", isOver18: false),
        PTTBoard(name: "Tech_Job", displayName: "科技工作 (Tech_Job)", isOver18: false),
        PTTBoard(name: "HatePolitics", displayName: "政黑板 (HatePolitics)", isOver18: true),
        PTTBoard(name: "movie", displayName: "電影板 (movie)", isOver18: false)
    ]
}
