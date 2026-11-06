import XCTest
@testable import PTTMarquee

/// 設定頁標籤欄寬固定為 `字級 × (maxLabelChars + 1)`，標籤超過上限就會被截成「…」。
final class SettingsLabelTests: XCTestCase {
    func test_allLabelsFitLabelColumn() {
        for row in SettingsScreenView.Row.allCases {
            guard let title = row.title else { continue }
            XCTAssertLessThanOrEqual(title.count, SettingsScreenView.maxLabelChars,
                                     "設定標籤「\(title)」超過 \(SettingsScreenView.maxLabelChars) 字，會被截斷")
        }
    }

    func test_alwaysOnTopLabel_matchesHintName() {
        XCTAssertEqual(SettingsScreenView.Row.alwaysOnTop.title, "視窗浮動")
    }
}
