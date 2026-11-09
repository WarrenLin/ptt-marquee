import XCTest
@testable import PTTMarquee

/// PTT 文章頁回 `Cache-Control: max-age=900`；若沿用預設 URLCache，15 分鐘內每次輪詢都拿到舊頁面，看不到新推文。
final class CrawlerCachingTests: XCTestCase {
    func test_sessionConfiguration_neverUsesCache() {
        let config = PTTCrawlerService.makeSessionConfiguration()
        XCTAssertNil(config.urlCache, "不可使用 URLCache")
        XCTAssertEqual(config.requestCachePolicy, .reloadIgnoringLocalAndRemoteCacheData)
    }

    func test_sessionConfiguration_keepsTimeoutsAndCookie() {
        let config = PTTCrawlerService.makeSessionConfiguration()
        XCTAssertEqual(config.timeoutIntervalForRequest, 10)
        XCTAssertEqual(config.httpAdditionalHeaders?["Cookie"] as? String, "over18=1")
    }
}
