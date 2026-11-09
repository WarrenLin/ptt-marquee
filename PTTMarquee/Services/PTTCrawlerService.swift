import Foundation

public actor PTTCrawlerService {
    private let session: URLSession

    public init() {
        self.session = URLSession(configuration: Self.makeSessionConfiguration())
    }

    /// PTT 文章頁回 `Cache-Control: max-age=900`：若用預設 URLCache，15 分鐘內每次輪詢都讀到快取的舊頁面，
    /// 新推文要等快取過期才一次出現。輪詢一定要拿最新內容，所以完全不使用快取。
    static func makeSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
            "Cookie": "over18=1"
        ]
        return configuration
    }

    /// 抓取指定看板的最新文章列表
    public func fetchRecentArticles(board: String, maxCount: Int = 10) async throws -> [ParsedArticle] {
        guard let url = URL(string: "https://www.ptt.cc/bbs/\(board)/index.html") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("over18=1", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        var articles = HTMLParser.parseArticleList(html: html)

        if articles.count < maxCount, let prevUrlPath = HTMLParser.parsePreviousPageUrl(html: html),
           let prevUrl = URL(string: "https://www.ptt.cc\(prevUrlPath)") {
            var prevRequest = URLRequest(url: prevUrl)
            prevRequest.setValue("over18=1", forHTTPHeaderField: "Cookie")
            if let (prevData, _) = try? await session.data(for: prevRequest),
               let prevHtml = String(data: prevData, encoding: .utf8) {
                let prevArticles = HTMLParser.parseArticleList(html: prevHtml)
                articles = prevArticles + articles
            }
        }

        if articles.count > maxCount {
            articles = Array(articles.suffix(maxCount))
        }

        return articles
    }

    /// 抓取單篇文章的推文
    public func fetchPushes(for article: ParsedArticle, board: String) async -> [PTTMessage] {
        guard let url = article.fullUrl else { return [] }
        var request = URLRequest(url: url)
        request.setValue("over18=1", forHTTPHeaderField: "Cookie")

        guard let (data, response) = try? await session.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return []
        }

        let parsedPushes = HTMLParser.parsePushes(html: html)
        return parsedPushes.map { push in
            PTTMessage(
                tag: push.tag,
                userId: push.userId,
                content: push.content,
                ipDateTime: push.ipDateTime,
                articleTitle: article.title,
                articleUrl: article.fullUrl,
                boardName: board
            )
        }
    }

    /// 抓取單一特定文章的即時推文與標題
    public func fetchSingleArticle(url: URL, fallbackBoard: String? = nil) async throws -> (title: String, board: String, pushes: [PTTMessage]) {
        var request = URLRequest(url: url)
        request.setValue("over18=1", forHTTPHeaderField: "Cookie")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        let meta = HTMLParser.parseArticleMetadata(html: html)
        let title = meta.title ?? "PTT 文章"
        let board = meta.board ?? fallbackBoard ?? PTTBoard.defaultBoardName

        let parsedPushes = HTMLParser.parsePushes(html: html)
        let messages = parsedPushes.map { push in
            PTTMessage(
                tag: push.tag,
                userId: push.userId,
                content: push.content,
                ipDateTime: push.ipDateTime,
                articleTitle: title,
                articleUrl: url,
                boardName: board
            )
        }

        return (title, board, messages)
    }

    /// 批次抓取多篇文章推文
    public func fetchLatestMessages(board: String, articleCount: Int = 8) async throws -> [PTTMessage] {
        let articles = try await fetchRecentArticles(board: board, maxCount: articleCount)
        guard !articles.isEmpty else { return [] }

        var allMessages: [PTTMessage] = []

        await withTaskGroup(of: [PTTMessage].self) { group in
            for article in articles {
                group.addTask { [weak self] in
                    guard let self = self else { return [] }
                    return await self.fetchPushes(for: article, board: board)
                }
            }

            for await pushes in group {
                allMessages.append(contentsOf: pushes)
            }
        }

        return allMessages
    }
}
