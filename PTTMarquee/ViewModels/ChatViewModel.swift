import Foundation
import SwiftUI
import Combine

public struct TargetArticle: Equatable {
    public let title: String
    public let url: URL
    public let boardName: String

    public init(title: String, url: URL, boardName: String) {
        self.title = title
        self.url = url
        self.boardName = boardName
    }
}

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var messages: [PTTMessage] = []
    public let maxMessageCount: Int = 150

    // 看板與單篇實況文章
    @Published public var currentBoard: PTTBoard {
        didSet {
            UserDefaults.standard.set(currentBoard.name, forKey: "PTTMarquee_BoardName")
            onBoardChanged()
        }
    }
    @Published public var targetArticle: TargetArticle? = nil

    @Published public var isFetching: Bool = false
    @Published public var statusMessage: String = "連線中..."
    @Published public var errorMessage: String? = nil

    // 設定選項 (持久化保存於 UserDefaults)
    @Published public var windowOpacity: Double {
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: "PTTMarquee_WindowOpacity")
        }
    }
    @Published public var fontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: "PTTMarquee_FontSize")
        }
    }
    @Published public var isLocked: Bool {
        didSet {
            UserDefaults.standard.set(isLocked, forKey: "PTTMarquee_IsLocked")
        }
    }
    @Published public var isAlwaysOnTop: Bool {
        didSet {
            UserDefaults.standard.set(isAlwaysOnTop, forKey: "PTTMarquee_IsAlwaysOnTop")
        }
    }

    // 🔄 動態抓取刷新頻率 (秒)
    @Published public var boardRefreshInterval: Double {
        didSet {
            UserDefaults.standard.set(boardRefreshInterval, forKey: "PTTMarquee_BoardRefreshInterval")
        }
    }
    @Published public var articleRefreshInterval: Double {
        didSet {
            UserDefaults.standard.set(articleRefreshInterval, forKey: "PTTMarquee_ArticleRefreshInterval")
        }
    }

    @Published public var filterType: FilterType = .all

    // 終端機畫面與鍵盤狀態
    @Published public var screen: TerminalScreen = .chat
    @Published public var isTextInputActive = false
    @Published public var isConfirmingQuit = false
    public let keyCommands = PassthroughSubject<KeyCommand, Never>()
    /// 看板清單的「自訂看板…」切到設定畫面時設為 true；設定畫面出現時把游標放在「前往看板」並清回 false。
    public var settingsStartsAtBoardInput = false

    public enum FilterType: String, CaseIterable, Identifiable {
        case all = "全部"
        case pushOnly = "只看推"
        case booOnly = "只看噓"

        public var id: String { rawValue }
    }

    public let queueManager = MessageQueueManager()
    private let crawler = PTTCrawlerService()
    private var pollTask: Task<Void, Never>?

    public init() {
        let defaults = UserDefaults.standard

        // 讀取持久化設定
        let savedOpacity = defaults.double(forKey: "PTTMarquee_WindowOpacity")
        self.windowOpacity = savedOpacity > 0 ? savedOpacity : 0.85

        let savedFontSize = defaults.double(forKey: "PTTMarquee_FontSize")
        self.fontSize = savedFontSize > 0 ? CGFloat(savedFontSize) : 13.0

        if defaults.object(forKey: "PTTMarquee_IsAlwaysOnTop") != nil {
            self.isAlwaysOnTop = defaults.bool(forKey: "PTTMarquee_IsAlwaysOnTop")
        } else {
            self.isAlwaysOnTop = true
        }

        self.isLocked = defaults.bool(forKey: "PTTMarquee_IsLocked")

        let savedBoardInterval = defaults.double(forKey: "PTTMarquee_BoardRefreshInterval")
        self.boardRefreshInterval = savedBoardInterval >= 5 ? savedBoardInterval : 8.0

        let savedArticleInterval = defaults.double(forKey: "PTTMarquee_ArticleRefreshInterval")
        self.articleRefreshInterval = savedArticleInterval >= 2 ? savedArticleInterval : 3.0

        let savedBoardName = defaults.string(forKey: "PTTMarquee_BoardName") ?? PTTBoard.defaultBoardName
        let initialBoard = PTTBoard.presetBoards.first(where: { $0.name == savedBoardName }) ?? PTTBoard(name: savedBoardName, displayName: savedBoardName, isOver18: true)
        self.currentBoard = initialBoard

        setupQueueSubscription()
        startPolling()
    }

    deinit {
        pollTask?.cancel()
    }

    private func setupQueueSubscription() {
        queueManager.onMessageEmit = { [weak self] message in
            guard let self = self else { return }
            self.appendMessage(message)
        }
    }

    private func appendMessage(_ message: PTTMessage) {
        appendMessages([message])
    }

    private func appendMessages(_ newMessages: [PTTMessage]) {
        guard !newMessages.isEmpty else { return }
        messages.append(contentsOf: newMessages)
        if messages.count > maxMessageCount {
            messages.removeFirst(messages.count - maxMessageCount)
        }
    }

    public var filteredMessages: [PTTMessage] {
        switch filterType {
        case .all:
            return messages
        case .pushOnly:
            return messages.filter { $0.tag == .push }
        case .booOnly:
            return messages.filter { $0.tag == .boo }
        }
    }

    public func changeBoard(_ board: PTTBoard) {
        guard board != currentBoard else {
            // 從單篇實況選回同一個看板：清掉實況留言並重新抓看板；本來就在看板串流則不動
            unlockTargetArticle()
            return
        }
        targetArticle = nil
        currentBoard = board   // didSet → onBoardChanged() 清空並重新抓取
    }

    public func setCustomBoard(name: String) {
        targetArticle = nil
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let newBoard = PTTBoard(name: cleanName, displayName: cleanName, isOver18: true)
        currentBoard = newBoard
    }

    /// 鎖定單篇文章實況
    public func lockToArticle(title: String, url: URL, board: String) {
        pollTask?.cancel()
        queueManager.reset()
        messages.removeAll()
        targetArticle = TargetArticle(title: title, url: url, boardName: board)
        statusMessage = "🎯 實況：\(title)"
        startPolling()
    }

    /// 透過輸入網址鎖定單篇文章
    public func lockToArticle(byUrlString input: String) {
        var cleanUrl = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanUrl.hasPrefix("//") {
            cleanUrl = "https:" + cleanUrl
        } else if !cleanUrl.hasPrefix("http") && cleanUrl.hasPrefix("www.ptt.cc") {
            cleanUrl = "https://" + cleanUrl
        } else if cleanUrl.hasPrefix("/bbs/") {
            cleanUrl = "https://www.ptt.cc" + cleanUrl
        }

        guard let url = URL(string: cleanUrl), url.host?.contains("ptt.cc") == true else {
            errorMessage = "無效的 PTT 文章網址"
            return
        }

        pollTask?.cancel()
        queueManager.reset()
        messages.removeAll()
        targetArticle = TargetArticle(title: "載入文章中...", url: url, boardName: currentBoard.name)
        statusMessage = "🎯 連線單篇實況中..."
        startPolling()
    }

    /// 解除文章鎖定，返回看板串流
    public func unlockTargetArticle() {
        guard targetArticle != nil else { return }
        pollTask?.cancel()
        targetArticle = nil
        queueManager.reset()
        messages.removeAll()
        statusMessage = "返回看板：\(currentBoard.displayName)"
        startPolling()
    }

    private func onBoardChanged() {
        pollTask?.cancel()
        queueManager.reset()
        messages.removeAll()
        statusMessage = "切換至 \(currentBoard.displayName)..."
        startPolling()
    }

    public func cycleFilter() {
        switch filterType {
        case .all: filterType = .pushOnly
        case .pushOnly: filterType = .booOnly
        case .booOnly: filterType = .all
        }
    }

    private func handleQuitConfirmation(_ cmd: KeyCommand) {
        switch cmd {
        case .yes: NSApplication.shared.terminate(nil)
        case .no, .escape: isConfirmingQuit = false
        default: break
        }
    }

    /// 鍵盤與滑鼠的單一入口。
    public func dispatch(_ cmd: KeyCommand) {
        if isConfirmingQuit {
            handleQuitConfirmation(cmd)
            return
        }
        if screen == .chat {
            handleChatCommand(cmd)
            if cmd == .scrollToBottom || cmd == .scrollToTop { keyCommands.send(cmd) }
        } else {
            keyCommands.send(cmd)
        }
    }

    /// 聊天畫面層級的指令處理（僅在 screen == .chat 時作用）。
    public func handleChatCommand(_ cmd: KeyCommand) {
        guard screen == .chat else { return }
        switch cmd {
        case .pause: togglePause()
        case .filter: cycleFilter()
        case .lock: isLocked.toggle()
        case .top: isAlwaysOnTop.toggle()
        case .boards: screen = .boards
        case .settings: screen = .settings
        case .help: screen = .help
        case .quit: isConfirmingQuit = true
        case .back: if targetArticle != nil { unlockTargetArticle() }
        case .scrollToBottom: appendMessages(queueManager.drainAll()) // 置底：待播訊息一次全部顯示，捲動由 View 處理
        default: break // scrollToTop 由 View 處理
        }
    }

    public func togglePause() {
        queueManager.togglePause()
        if queueManager.isPaused {
            // 暫停後不再抓取，紅字不會再被成功的抓取清掉，所以在這裡清除
            consecutiveFetchFailures = 0
            errorMessage = nil
            statusMessage = "推播已暫停"
        } else {
            if let target = targetArticle {
                statusMessage = "🎯 實況中：\(target.title)"
            } else {
                statusMessage = "連線中 (\(currentBoard.name))"
            }
        }
    }

    public func clearMessages() {
        messages.removeAll()
        queueManager.reset()
    }

    public func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }

                if !self.queueManager.isPaused {
                    if let target = self.targetArticle {
                        await self.performFetchSingleArticle(target: target)
                        // 使用動態單篇實況輪詢間隔 (預設 3 秒，可調整 2~15 秒)
                        let sleepSec = max(2.0, self.articleRefreshInterval)
                        try? await Task.sleep(nanoseconds: UInt64(sleepSec * 1_000_000_000))
                    } else {
                        await self.performFetchBoard()
                        // 使用動態看板聚合輪詢間隔 (預設 8 秒，可調整 5~30 秒)
                        let sleepSec = max(4.0, self.boardRefreshInterval)
                        try? await Task.sleep(nanoseconds: UInt64(sleepSec * 1_000_000_000))
                    }
                } else {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }
    }

    // MARK: - 抓取錯誤處理

    /// PTT 網頁版常間歇性卡住 15～30 秒；偶爾一次失敗下一輪就會自動重試，
    /// 連續失敗達此次數才顯示紅字，避免一直打擾。
    static let fetchFailureThreshold = 3
    private var consecutiveFetchFailures = 0

    func recordFetchSuccess() {
        consecutiveFetchFailures = 0
        errorMessage = nil
    }

    func recordFetchFailure(_ error: Error) {
        consecutiveFetchFailures += 1
        if consecutiveFetchFailures >= Self.fetchFailureThreshold {
            errorMessage = Self.fetchErrorMessage(for: error)
        }
    }

    static func fetchErrorMessage(for error: Error) -> String {
        switch (error as? URLError)?.code {
        case .timedOut?: return "PTT 連線逾時，重試中…"
        case .badServerResponse?: return "PTT 伺服器異常，重試中…"
        case .notConnectedToInternet?, .networkConnectionLost?: return "網路未連線，重試中…"
        default: return "抓取推文失敗，重試中…"
        }
    }

    private func performFetchSingleArticle(target: TargetArticle) async {
        isFetching = true

        do {
            let (title, board, allPushes) = try await crawler.fetchSingleArticle(url: target.url, fallbackBoard: target.boardName)
            guard !Task.isCancelled else { return }
            recordFetchSuccess()

            if targetArticle?.title != title {
                targetArticle = TargetArticle(title: title, url: target.url, boardName: board)
            }

            // 剛進入單篇實況時，若畫面為空，直接將最新 40 筆留言載入畫面
            if messages.isEmpty {
                let initialBatch = Array(allPushes.suffix(40))
                queueManager.markSeen(messages: allPushes)
                self.messages = initialBatch
                statusMessage = "🎯 實況：\(title) (已載入即時留言)"
            } else {
                // 之後隨時間產生的新推文平滑排隊推入
                queueManager.enqueue(messages: allPushes)
                statusMessage = "🎯 實況：\(title) (待播: \(queueManager.queuedCount))"
            }
        } catch {
            if !Task.isCancelled {
                recordFetchFailure(error)
                statusMessage = "單篇連線重試中..."
            }
        }
        isFetching = false
    }

    private func performFetchBoard() async {
        isFetching = true
        let boardName = currentBoard.name

        do {
            let messages = try await crawler.fetchLatestMessages(board: boardName, articleCount: 8)
            if !Task.isCancelled {
                recordFetchSuccess()
                queueManager.enqueue(messages: messages)
                statusMessage = "看板：\(boardName) (待播: \(queueManager.queuedCount))"
            }
        } catch {
            if !Task.isCancelled {
                recordFetchFailure(error)
                statusMessage = "連線異常，重試中..."
            }
        }
        isFetching = false
    }
}
