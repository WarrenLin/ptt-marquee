import XCTest
@testable import PTTMarquee

/// 切換看板（含從單篇實況回到同一個看板）時，畫面與待播隊列都要清空，不能殘留前一個來源的推文。
@MainActor
final class BoardSwitchTests: XCTestCase {
    // 測試與 app 共用真實 UserDefaults，切換看板會寫入 PTTMarquee_BoardName，結束後還原。
    private let boardKey = "PTTMarquee_BoardName"
    private var savedBoard: Any?

    override func setUp() async throws {
        savedBoard = UserDefaults.standard.object(forKey: boardKey)
    }

    override func tearDown() async throws {
        if let savedBoard { UserDefaults.standard.set(savedBoard, forKey: boardKey) }
        else { UserDefaults.standard.removeObject(forKey: boardKey) }
    }

    private func msg(_ user: String, board: String, article: String) -> PTTMessage {
        PTTMessage(tag: .push, userId: user, content: "c\(user)", ipDateTime: "01/01 00:00",
                   articleTitle: "t", articleUrl: URL(string: "https://www.ptt.cc/bbs/\(board)/\(article).html"),
                   boardName: board)
    }

    /// 暫停推播（停止背景抓取），再把指定訊息一次放上畫面。
    private func show(_ vm: ChatViewModel, _ msgs: [PTTMessage]) {
        if !vm.queueManager.isPaused { vm.queueManager.togglePause() }
        vm.queueManager.enqueue(messages: msgs)
        vm.dispatch(.scrollToBottom)
    }

    private func preset(_ name: String) -> PTTBoard { PTTBoard.presetBoards.first { $0.name == name }! }

    func test_switchToOtherBoard_clearsMessagesAndQueue() {
        let vm = ChatViewModel()
        vm.changeBoard(preset("Stock"))
        show(vm, [msg("a", board: "Stock", article: "A")])
        vm.queueManager.enqueue(messages: [msg("b", board: "Stock", article: "A")])
        vm.changeBoard(preset("Baseball"))
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertEqual(vm.queueManager.queuedCount, 0)
    }

    func test_leavingLiveArticleForSameBoard_clearsArticleMessages() {
        let vm = ChatViewModel()
        vm.changeBoard(preset("Stock"))
        vm.lockToArticle(title: "直播", url: URL(string: "https://www.ptt.cc/bbs/Stock/LIVE.html")!, board: "Stock")
        show(vm, [msg("live1", board: "Stock", article: "LIVE")])
        vm.queueManager.enqueue(messages: [msg("live2", board: "Stock", article: "LIVE")])

        vm.changeBoard(preset("Stock"))         // 從看板清單選回同一個看板

        XCTAssertNil(vm.targetArticle)
        XCTAssertTrue(vm.messages.isEmpty, "實況文章的留言不應殘留在看板串流")
        XCTAssertEqual(vm.queueManager.queuedCount, 0)
    }

    func test_selectingCurrentBoardWithoutLiveArticle_keepsMessages() {
        let vm = ChatViewModel()
        vm.changeBoard(preset("Stock"))
        show(vm, [msg("a", board: "Stock", article: "A")])
        vm.changeBoard(preset("Stock"))         // 已在 Stock 看板串流，再選一次不必清空
        XCTAssertEqual(vm.messages.map(\.userId), ["a"])
    }

    func test_leavingLiveArticleForCustomSameBoard_clearsArticleMessages() {
        let vm = ChatViewModel()
        vm.changeBoard(preset("Stock"))
        vm.lockToArticle(title: "直播", url: URL(string: "https://www.ptt.cc/bbs/Stock/LIVE.html")!, board: "Stock")
        show(vm, [msg("live1", board: "Stock", article: "LIVE")])
        vm.setCustomBoard(name: "Stock")
        XCTAssertNil(vm.targetArticle)
        XCTAssertTrue(vm.messages.isEmpty)
    }
}
