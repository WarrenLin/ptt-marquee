import XCTest
@testable import PTTMarquee

@MainActor
final class FetchErrorHandlingTests: XCTestCase {
    private func makeVM() -> ChatViewModel {
        let vm = ChatViewModel()
        vm.queueManager.togglePause()   // 停止背景輪詢，避免真的連網干擾
        vm.queueManager.togglePause()
        return vm
    }

    // MARK: - 訊息文字

    func test_message_timeout_isChinese() {
        XCTAssertEqual(ChatViewModel.fetchErrorMessage(for: URLError(.timedOut)), "PTT 連線逾時，重試中…")
    }

    func test_message_badServerResponse() {
        XCTAssertEqual(ChatViewModel.fetchErrorMessage(for: URLError(.badServerResponse)), "PTT 伺服器異常，重試中…")
    }

    func test_message_offline() {
        XCTAssertEqual(ChatViewModel.fetchErrorMessage(for: URLError(.notConnectedToInternet)), "網路未連線，重試中…")
    }

    func test_message_other() {
        XCTAssertEqual(ChatViewModel.fetchErrorMessage(for: URLError(.cannotDecodeContentData)), "抓取推文失敗，重試中…")
    }

    // MARK: - 連續失敗門檻

    func test_errorShownOnlyAfterThreeConsecutiveFailures() {
        let vm = makeVM()
        vm.recordFetchFailure(URLError(.timedOut))
        XCTAssertNil(vm.errorMessage)
        vm.recordFetchFailure(URLError(.timedOut))
        XCTAssertNil(vm.errorMessage)
        vm.recordFetchFailure(URLError(.timedOut))
        XCTAssertEqual(vm.errorMessage, "PTT 連線逾時，重試中…")
    }

    func test_successResetsCounterAndClearsError() {
        let vm = makeVM()
        for _ in 0..<3 { vm.recordFetchFailure(URLError(.timedOut)) }
        vm.recordFetchSuccess()
        XCTAssertNil(vm.errorMessage)
        vm.recordFetchFailure(URLError(.timedOut))
        vm.recordFetchFailure(URLError(.timedOut))
        XCTAssertNil(vm.errorMessage, "成功後計數應歸零，再失敗 2 次不應顯示")
    }

    // MARK: - 暫停清除

    func test_pauseClearsFetchErrorAndCounter() {
        let vm = makeVM()
        for _ in 0..<3 { vm.recordFetchFailure(URLError(.timedOut)) }
        vm.togglePause()                      // 暫停
        XCTAssertNil(vm.errorMessage)
        vm.togglePause()                      // 繼續
        vm.recordFetchFailure(URLError(.timedOut))
        XCTAssertNil(vm.errorMessage, "暫停時計數應歸零")
    }
}
