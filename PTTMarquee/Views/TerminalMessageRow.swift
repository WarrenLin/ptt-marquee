import SwiftUI
import AppKit

/// 一行一則的 telnet 風格留言：`推 ID: 內文 …… MM/dd HH:mm`
struct TerminalMessageRow: View {
    let message: PTTMessage
    let fontSize: CGFloat
    /// 看板模式才提供「鎖定此篇為實況聊天室」
    let canLockArticle: Bool
    var onLockArticle: ((String, URL, String) -> Void)?

    @State private var isHovered = false

    /// 提取易讀的推文時間 (去除冗長 IP，例如 "11/06 10:26")
    private var displayTime: String {
        let trimmed = message.ipDateTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: " ")
        }
        return trimmed
    }

    private func color(_ normal: Color) -> Color {
        isHovered ? TerminalTheme.highlightFg : normal
    }

    var body: some View {
        // 寬度足夠時：標籤、ID:、內文（懸掛縮排）、時間同一行，等同
        // HStack(alignment: .firstTextBaseline) + Spacer；
        // 視窗太窄（內文欄不到約 6 個中文字寬）時，內文改到下一行，避免一字一行。
        TerminalMessageRowLayout(minContentWidth: fontSize * 6, timeSpacing: 6) {
            Text(message.tag.title + " ")
                .font(TerminalTheme.font(fontSize, bold: message.tag == .push))
                .foregroundColor(color(TerminalTheme.color(for: message.tag)))
            Text(message.userId + ": ")
                .font(TerminalTheme.font(fontSize))
                .foregroundColor(color(TerminalTheme.userId))
            Text(message.content)
                .font(TerminalTheme.font(fontSize))
                .foregroundColor(color(TerminalTheme.content))
                .fixedSize(horizontal: false, vertical: true)
            Text(displayTime)
                .font(TerminalTheme.font(fontSize))
                .foregroundColor(color(TerminalTheme.time))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .background(isHovered ? TerminalTheme.highlightBg : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .contextMenu {
            if let articleUrl = message.articleUrl {
                if canLockArticle {
                    Button("鎖定此篇為實況聊天室") {
                        onLockArticle?(message.articleTitle, articleUrl, message.boardName)
                    }
                    Divider()
                }
                Button("在瀏覽器開啟文章") {
                    NSWorkspace.shared.open(articleUrl)
                }
                Button("複製文章網址") {
                    copy(articleUrl.absoluteString)
                }
            }
            Button("複製留言內文") {
                copy(message.content)
            }
            Button("複製使用者 ID") {
                copy(message.userId)
            }
        }
    }

    private func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

/// 留言行版面：子 View 依序為 標籤、ID、內文、時間，以第一行文字基線對齊。
struct TerminalMessageRowLayout: Layout {
    var minContentWidth: CGFloat
    var timeSpacing: CGFloat

    private struct Placement {
        var frames: [CGRect]
        var size: CGSize
    }

    private func compute(width proposedWidth: CGFloat?, subviews: Subviews) -> Placement {
        guard subviews.count == 4 else {
            return Placement(frames: subviews.map { _ in .zero }, size: .zero)
        }
        let tag = subviews[0], id = subviews[1], content = subviews[2], time = subviews[3]
        let tagSize = tag.sizeThatFits(.unspecified)
        let idSize = id.sizeThatFits(.unspecified)
        let timeSize = time.sizeThatFits(.unspecified)
        let prefixWidth = tagSize.width + idSize.width
        let idealContent = content.sizeThatFits(.unspecified)
        let idealWidth = prefixWidth + idealContent.width + timeSpacing + timeSize.width
        let width = proposedWidth.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        let available = width - prefixWidth - timeSpacing - timeSize.width

        func baseline(_ view: LayoutSubview, _ proposal: ProposedViewSize) -> CGFloat {
            view.dimensions(in: proposal)[VerticalAlignment.firstTextBaseline]
        }

        if available >= minContentWidth {
            // 懸掛縮排：內文換行時對齊在 ID: 之後
            let contentProposal = ProposedViewSize(width: available, height: nil)
            let contentSize = content.sizeThatFits(contentProposal)
            let bTag = baseline(tag, .unspecified)
            let bId = baseline(id, .unspecified)
            let bContent = baseline(content, contentProposal)
            let bTime = baseline(time, .unspecified)
            let maxB = max(bTag, bId, bContent, bTime)
            let frames = [
                CGRect(origin: CGPoint(x: 0, y: maxB - bTag), size: tagSize),
                CGRect(origin: CGPoint(x: tagSize.width, y: maxB - bId), size: idSize),
                CGRect(origin: CGPoint(x: prefixWidth, y: maxB - bContent), size: contentSize),
                CGRect(origin: CGPoint(x: width - timeSize.width, y: maxB - bTime), size: timeSize),
            ]
            let height = frames.map(\.maxY).max() ?? 0
            return Placement(frames: frames, size: CGSize(width: width, height: height))
        }

        // 窄視窗：第一行 標籤 ID: …… 時間，內文從下一行開始、對齊在標籤之後
        let bTag = baseline(tag, .unspecified)
        let bId = baseline(id, .unspecified)
        let bTime = baseline(time, .unspecified)
        let maxB = max(bTag, bId, bTime)
        let tagFrame = CGRect(origin: CGPoint(x: 0, y: maxB - bTag), size: tagSize)
        let idFrame = CGRect(origin: CGPoint(x: tagSize.width, y: maxB - bId), size: idSize)
        let timeFrame = CGRect(origin: CGPoint(x: max(prefixWidth + timeSpacing, width - timeSize.width), y: maxB - bTime), size: timeSize)
        let firstLineHeight = max(tagFrame.maxY, idFrame.maxY, timeFrame.maxY)
        let contentWidth = max(width - tagSize.width, 1)
        let contentSize = content.sizeThatFits(ProposedViewSize(width: contentWidth, height: nil))
        let contentFrame = CGRect(origin: CGPoint(x: tagSize.width, y: firstLineHeight), size: contentSize)
        return Placement(
            frames: [tagFrame, idFrame, contentFrame, timeFrame],
            size: CGSize(width: width, height: contentFrame.maxY)
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        compute(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = compute(width: bounds.width, subviews: subviews)
        for (view, frame) in zip(subviews, placement.frames) {
            view.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}
