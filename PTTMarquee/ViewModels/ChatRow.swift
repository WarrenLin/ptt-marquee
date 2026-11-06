import Foundation

enum ChatRow: Identifiable {
    case separator(id: String, title: String, url: URL?)
    case message(PTTMessage)

    var id: String {
        switch self {
        case .separator(let id, _, _): return id
        case .message(let m): return m.id.uuidString
        }
    }

    /// 依相鄰關係插入文章分隔線；第一則訊息前一定有分隔線。
    static func build(from messages: [PTTMessage], showSeparators: Bool) -> [ChatRow] {
        guard showSeparators else { return messages.map { .message($0) } }
        var rows: [ChatRow] = []
        var previous: PTTMessage?
        for m in messages {
            if previous == nil || previous?.articleUrl != m.articleUrl {
                rows.append(.separator(id: "sep-\(m.id)", title: m.articleTitle, url: m.articleUrl))
            }
            rows.append(.message(m))
            previous = m
        }
        return rows
    }
}
