import XCTest
import AppKit
import Combine
@testable import PTTMarquee

final class ScrollTopBottomTests: XCTestCase {
    private func msg(_ user: String) -> PTTMessage {
        PTTMessage(
            tag: .push,
            userId: user,
            content: "c\(user)",
            ipDateTime: "01/01 00:00",
            articleTitle: "t",
            articleUrl: URL(string: "https://example.com/A"),
            boardName: "Stock"
        )
    }

    private func cmd(_ c: String?, _ code: UInt16 = 0, _ mods: NSEvent.ModifierFlags = []) -> KeyCommand? {
        KeyCommand.from(characters: c, keyCode: code, modifiers: mods, isTextInputActive: false)
    }

    // MARK: - Key mapping

    func test_topKeys_mapToScrollToTop() {
        XCTAssertEqual(cmd(nil, 115), .scrollToTop)   // Home
        XCTAssertEqual(cmd("0"), .scrollToTop)
    }

    func test_dollar_mapsToScrollToBottom() {
        XCTAssertEqual(cmd("$", 0, .shift), .scrollToBottom)
        XCTAssertEqual(cmd(nil, 119), .scrollToBottom) // End still works
        XCTAssertEqual(cmd("g"), .scrollToBottom)      // G still works
    }

    func test_topKeys_ignoredWhileTyping() {
        XCTAssertNil(KeyCommand.from(characters: "0", keyCode: 0, modifiers: [], isTextInputActive: true))
        XCTAssertNil(KeyCommand.from(characters: nil, keyCode: 115, modifiers: [], isTextInputActive: true))
    }

    // MARK: - Queue drain

    @MainActor func test_drainAll_returnsQueuedInOrder_andEmpties() {
        let q = MessageQueueManager()
        q.togglePause()
        q.enqueue(messages: [msg("1"), msg("2"), msg("3")])
        XCTAssertEqual(q.drainAll().map(\.userId), ["1", "2", "3"])
        XCTAssertEqual(q.queuedCount, 0)
        XCTAssertEqual(q.drainAll().count, 0)
    }

    @MainActor func test_drainAll_keepsDedup() {
        let q = MessageQueueManager()
        q.togglePause()
        q.enqueue(messages: [msg("1")])
        _ = q.drainAll()
        q.enqueue(messages: [msg("1")])               // already seen → not re-queued
        XCTAssertEqual(q.queuedCount, 0)
    }

    // MARK: - ViewModel 置底 / 置頂

    @MainActor func test_scrollToBottom_flushesQueueIntoMessages() {
        let vm = ChatViewModel()
        vm.queueManager.togglePause()                 // stop drip + polling
        vm.clearMessages()
        vm.queueManager.enqueue(messages: [msg("a"), msg("b"), msg("c")])
        vm.dispatch(.scrollToBottom)
        XCTAssertEqual(vm.messages.map(\.userId), ["a", "b", "c"])
        XCTAssertEqual(vm.queueManager.queuedCount, 0)
    }

    @MainActor func test_scrollToBottom_flushRespectsMessageCap() {
        let vm = ChatViewModel()
        vm.queueManager.togglePause()
        vm.clearMessages()
        vm.queueManager.enqueue(messages: (0..<200).map { msg("u\($0)") })
        vm.dispatch(.scrollToBottom)
        XCTAssertEqual(vm.messages.count, vm.maxMessageCount)
        XCTAssertEqual(vm.messages.last?.userId, "u199")
    }

    @MainActor func test_scrollToTop_publishedOnChat() {
        let vm = ChatViewModel()
        vm.queueManager.togglePause()
        var got: [KeyCommand] = []
        let c = vm.keyCommands.sink { got.append($0) }
        vm.dispatch(.scrollToTop)
        XCTAssertEqual(got, [.scrollToTop])
        c.cancel()
    }
}
