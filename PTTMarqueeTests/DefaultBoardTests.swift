import XCTest
@testable import PTTMarquee

final class DefaultBoardTests: XCTestCase {
    func test_defaultBoard_isStock() {
        XCTAssertEqual(PTTBoard.defaultBoardName, "Stock")
    }

    func test_defaultBoard_isAPreset() {
        XCTAssertTrue(PTTBoard.presetBoards.contains { $0.name == PTTBoard.defaultBoardName })
    }
}
