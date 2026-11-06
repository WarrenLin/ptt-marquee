import Foundation

public struct ParsedArticle {
    public let title: String
    public let urlString: String
    public let fullUrl: URL?

    public init(title: String, urlString: String) {
        self.title = title
        self.urlString = urlString
        if urlString.hasPrefix("http") {
            self.fullUrl = URL(string: urlString)
        } else {
            self.fullUrl = URL(string: "https://www.ptt.cc\(urlString)")
        }
    }
}

public struct ParsedPush {
    public let tag: PushTag
    public let userId: String
    public let content: String
    public let ipDateTime: String
}

public enum HTMLParser {
    public static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }

    /// 解析看板文章列表，過濾掉置底公告區塊 (r-list-sep 之後的文章)
    public static func parseArticleList(html: String) -> [ParsedArticle] {
        let regularHTML: String
        if let sepRange = html.range(of: "<div class=\"r-list-sep\">") {
            regularHTML = String(html[..<sepRange.lowerBound])
        } else {
            regularHTML = html
        }

        var articles: [ParsedArticle] = []
        let pattern = #"<div class="title">\s*<a href="([^"]+)">([^<]+)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return articles
        }

        let nsString = regularHTML as NSString
        let matches = regex.matches(in: regularHTML, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let href = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            let rawTitle = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = decodeHTMLEntities(rawTitle)

            if !href.isEmpty && !title.isEmpty {
                articles.append(ParsedArticle(title: title, urlString: href))
            }
        }

        return articles
    }

    /// 取得上一頁的 URL
    public static func parsePreviousPageUrl(html: String) -> String? {
        let pattern = #"<a class="btn wide" href="([^"]+)">‹ 上頁</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let nsString = html as NSString
        guard let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        return nsString.substring(with: match.range(at: 1))
    }

    /// 解析單一文章的所有推文
    public static func parsePushes(html: String) -> [ParsedPush] {
        var pushes: [ParsedPush] = []

        let pattern = #"<div class="push">.*?<span class="[^"]*push-tag">([^<]+)</span>\s*<span class="[^"]*push-userid">([^<]+)</span>\s*<span class="[^"]*push-content">([^<]*)</span>\s*<span class="[^"]*push-ipdatetime">([^<]*)</span>.*?</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return pushes
        }

        let nsString = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges >= 5 else { continue }
            let tagRaw = nsString.substring(with: match.range(at: 1))
            let userId = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
            var content = nsString.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
            let ipDateTime = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)

            if content.hasPrefix(":") {
                content = String(content.dropFirst()).trimmingCharacters(in: .whitespaces)
            }

            content = decodeHTMLEntities(content)
            let tag = PushTag.from(rawString: tagRaw)

            pushes.append(ParsedPush(tag: tag, userId: userId, content: content, ipDateTime: ipDateTime))
        }

        return pushes
    }

    /// 解析文章的標題與看板名稱
    public static func parseArticleMetadata(html: String) -> (title: String?, board: String?) {
        var title: String?
        var board: String?

        // 標題: <span class="article-meta-tag">標題</span><span class="article-meta-value">...</span>
        let titlePattern = #"<span class="article-meta-tag">標題</span>\s*<span class="article-meta-value">([^<]+)</span>"#
        if let titleRegex = try? NSRegularExpression(pattern: titlePattern, options: []),
           let match = titleRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges >= 2 {
            title = decodeHTMLEntities((html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // 看板: <span class="article-meta-tag">看板</span><span class="article-meta-value">...</span>
        let boardPattern = #"<span class="article-meta-tag">看板</span>\s*<span class="article-meta-value">([^<]+)</span>"#
        if let boardRegex = try? NSRegularExpression(pattern: boardPattern, options: []),
           let match = boardRegex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: (html as NSString).length)),
           match.numberOfRanges >= 2 {
            board = (html as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return (title, board)
    }
}
