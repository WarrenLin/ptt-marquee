import XCTest
@testable import PTTMarquee

final class BlockBarTests: XCTestCase {
    func test_stepped_clampsToRange() {
        let b = BlockBar.boardInterval
        XCTAssertEqual(b.stepped(30, direction: 1), 30)
        XCTAssertEqual(b.stepped(5, direction: -1), 5)
        XCTAssertEqual(b.stepped(8, direction: 1), 9)
    }

    func test_opacityStep() {
        XCTAssertEqual(BlockBar.opacity.stepped(0.85, direction: 1), 0.90, accuracy: 0.001)
    }

    func test_filledCells() {
        XCTAssertEqual(BlockBar.boardInterval.filledCells(for: 5), 0)
        XCTAssertEqual(BlockBar.boardInterval.filledCells(for: 30), 8)
        XCTAssertEqual(BlockBar.fontSize.filledCells(for: 13), 2)
    }

    func test_valueForCell_lastIsUpperBound_andSnapsToStep() {
        let b = BlockBar.boardInterval
        XCTAssertEqual(b.value(forCell: 7), 30)
        XCTAssertEqual(b.value(forCell: 0), 5)
        for i in 0..<b.cells {
            XCTAssertEqual(b.value(forCell: i).truncatingRemainder(dividingBy: 1), 0)
        }
    }
}
