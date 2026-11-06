import XCTest
import AppKit
@testable import PTTMarquee

final class KeyCommandTests: XCTestCase {
    private func cmd(_ c: String?, _ code: UInt16 = 0, _ mods: NSEvent.ModifierFlags = [], text: Bool = false) -> KeyCommand? {
        KeyCommand.from(characters: c, keyCode: code, modifiers: mods, isTextInputActive: text)
    }

    func test_letterKeys_mapCaseInsensitive() {
        XCTAssertEqual(cmd("p"), .pause)
        XCTAssertEqual(cmd("P"), .pause)
        XCTAssertEqual(cmd("?", 44, .shift), .help)
        XCTAssertEqual(cmd("g"), .scrollToBottom)
        XCTAssertEqual(cmd("x"), .quit)
        XCTAssertEqual(cmd("q"), .back)
    }

    func test_specialKeyCodes() {
        XCTAssertEqual(cmd(nil, 119), .scrollToBottom)
        XCTAssertEqual(cmd(nil, 53), .escape)
        XCTAssertEqual(cmd("\r", 36), .enter)
        XCTAssertEqual(cmd(nil, 76), .enter)
        XCTAssertEqual(cmd(nil, 126), .up)
        XCTAssertEqual(cmd(nil, 125), .down)
        XCTAssertEqual(cmd(nil, 123), .left)
        XCTAssertEqual(cmd(nil, 124), .right)
    }

    func test_modifiedKeys_returnNil() {
        XCTAssertNil(cmd("q", 12, .command))
        XCTAssertNil(cmd("c", 8, .command))
        XCTAssertNil(cmd("v", 9, .control))
        XCTAssertNil(cmd("p", 35, .option))
        XCTAssertNil(cmd(nil, 126, .command))
    }

    func test_textInputActive_returnsNil() {
        XCTAssertNil(cmd("s", text: true))
        XCTAssertNil(cmd("t", text: true))
        XCTAssertNil(cmd(nil, 36, text: true))
    }

    func test_unknownKey_returnsNil() {
        XCTAssertNil(cmd("z"))
    }

    @MainActor func test_cycleFilter() {
        let vm = ChatViewModel()
        vm.filterType = .all
        vm.cycleFilter(); XCTAssertEqual(vm.filterType, .pushOnly)
        vm.cycleFilter(); XCTAssertEqual(vm.filterType, .booOnly)
        vm.cycleFilter(); XCTAssertEqual(vm.filterType, .all)
    }

    @MainActor func test_quitRequiresConfirm() {
        let vm = ChatViewModel()
        vm.dispatch(.quit)
        XCTAssertTrue(vm.isConfirmingQuit)
        vm.dispatch(.no)
        XCTAssertFalse(vm.isConfirmingQuit)
    }

    @MainActor func test_dispatch_quitConfirmAndEscape() {
        let vm = ChatViewModel()
        vm.dispatch(.quit)
        XCTAssertTrue(vm.isConfirmingQuit)
        vm.dispatch(.pause) // ignored while confirming
        XCTAssertTrue(vm.isConfirmingQuit)
        vm.dispatch(.escape)
        XCTAssertFalse(vm.isConfirmingQuit)
    }

    @MainActor func test_dispatch_backInSubscreen_doesNotUnlockArticle() {
        let vm = ChatViewModel()
        vm.targetArticle = TargetArticle(title: "t", url: URL(string: "https://www.ptt.cc/bbs/a/M.1.A.html")!, boardName: "a")
        vm.screen = .settings
        vm.dispatch(.back)
        XCTAssertEqual(vm.screen, .settings)
        XCTAssertFalse(vm.isConfirmingQuit)
        XCTAssertNotNil(vm.targetArticle)
    }

    @MainActor func test_dispatch_subscreenForwardsToKeyCommands() {
        let vm = ChatViewModel()
        vm.screen = .help
        var got: [KeyCommand] = []
        let c = vm.keyCommands.sink { got.append($0) }
        vm.dispatch(.back)
        XCTAssertEqual(got, [.back])
        c.cancel()
    }

    @MainActor func test_dispatch_chatScreenSwitches() {
        let vm = ChatViewModel()
        vm.dispatch(.boards); XCTAssertEqual(vm.screen, .boards)
    }

    @MainActor func test_dispatch_scrollToBottomPublishedOnChat() {
        let vm = ChatViewModel()
        var got: [KeyCommand] = []
        let c = vm.keyCommands.sink { got.append($0) }
        vm.dispatch(.scrollToBottom)
        XCTAssertEqual(got, [.scrollToBottom])
        c.cancel()
    }
}
