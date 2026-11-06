import XCTest
@testable import PTTMarquee

final class MessageQueueGroupingTests: XCTestCase {
    private func msg(_ article: String?, _ user: String) -> PTTMessage {
        PTTMessage(
            tag: .push,
            userId: user,
            content: "c\(user)",
            ipDateTime: "01/01 00:00",
            articleTitle: "t",
            articleUrl: article.flatMap { URL(string: "https://example.com/\($0)") },
            boardName: "Stock"
        )
    }

    func test_grouping_ordersByFirstAppearance_keepsInnerOrder() {
        let input = [msg("A","1"), msg("B","2"), msg("A","3"), msg("C","4"), msg("B","5")]
        XCTAssertEqual(MessageQueueManager.groupedByArticle(input).map(\.userId), ["1","3","2","5","4"])
    }

    func test_grouping_nilUrlGroupedTogether() {
        let input = [msg(nil,"1"), msg("A","2"), msg(nil,"3")]
        XCTAssertEqual(MessageQueueManager.groupedByArticle(input).map(\.userId), ["1","3","2"])
    }

    @MainActor
    func test_enqueue_doesNotReorderExistingQueue() async {
        let q = MessageQueueManager()
        let box = EmitBox()
        q.onMessageEmit = { box.ids.append($0.userId) }
        q.togglePause()                                   // 暫停，讓隊列不自動推出
        q.enqueue(messages: [msg("A","1"), msg("B","2")])
        q.enqueue(messages: [msg("B","3"), msg("A","4"), msg("B","5")])
        q.enqueue(messages: [msg("A","1")])               // 重複的推文，應被去重
        XCTAssertEqual(q.queuedCount, 5)
        q.togglePause()
        try? await Task.sleep(nanoseconds: 7_000_000_000)
        XCTAssertEqual(box.ids, ["1","2","3","5","4"])
    }
}

private final class EmitBox { var ids: [String] = [] }
