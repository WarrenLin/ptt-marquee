import XCTest
@testable import PTTMarquee

final class ChatRowTests: XCTestCase {
    private func msg(_ article: String, _ user: String) -> PTTMessage {
        PTTMessage(
            tag: .push,
            userId: user,
            content: "c\(user)",
            ipDateTime: "01/01 00:00",
            articleTitle: "title-\(article)",
            articleUrl: URL(string: "https://example.com/\(article)"),
            boardName: "Stock"
        )
    }

    private func short(_ rows: [ChatRow]) -> [String] {
        rows.map {
            switch $0 {
            case .separator(_, let title, _): return "sep:" + title.replacingOccurrences(of: "title-", with: "")
            case .message(let m): return "msg:" + m.userId
            }
        }
    }

    func test_firstMessage_alwaysHasSeparator() {
        let rows = ChatRow.build(from: [msg("A", "1")], showSeparators: true)
        XCTAssertEqual(short(rows), ["sep:A", "msg:1"])
    }

    func test_separatorOnlyWhenArticleChanges() {
        let input = [msg("A", "1"), msg("A", "2"), msg("B", "3"), msg("A", "4")]
        XCTAssertEqual(short(ChatRow.build(from: input, showSeparators: true)),
                       ["sep:A", "msg:1", "msg:2", "sep:B", "msg:3", "sep:A", "msg:4"])
    }

    func test_noSeparatorsInSingleArticleMode() {
        let input = [msg("A", "1"), msg("B", "2")]
        XCTAssertEqual(short(ChatRow.build(from: input, showSeparators: false)), ["msg:1", "msg:2"])
    }

    func test_filteredList_recomputesSeparators() {
        let a1 = msg("A", "1"), a2 = msg("A", "2"), b3 = msg("B", "3"), a4 = msg("A", "4")
        let filtered = [a1, a2, b3, a4].filter { $0.userId != "3" }
        XCTAssertEqual(short(ChatRow.build(from: filtered, showSeparators: true)),
                       ["sep:A", "msg:1", "msg:2", "msg:4"])
    }

    func test_separatorTitleAndUrlComeFromMessage() {
        let m = msg("A", "1")
        let rows = ChatRow.build(from: [m], showSeparators: true)
        guard case .separator(let id, let title, let url) = rows[0] else { return XCTFail() }
        XCTAssertEqual(title, m.articleTitle)
        XCTAssertEqual(url, m.articleUrl)
        XCTAssertEqual(id, "sep-\(m.id)")
    }
}
