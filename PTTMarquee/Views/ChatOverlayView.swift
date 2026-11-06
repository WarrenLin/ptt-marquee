import SwiftUI
import AppKit

public struct BottomAnchorDistanceKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

public struct ChatOverlayView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject private var queueManager: MessageQueueManager

    @State private var isUserScrolledUp: Bool = false
    @State private var newMessagesWhileScrolledUp: Int = 0
    @State private var isProgrammaticScrolling: Bool = false

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        self.queueManager = viewModel.queueManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            TerminalTitleBar(title: titleText, status: statusText, isDraggable: !viewModel.isLocked, fontSize: barFontSize)

            middleArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(TerminalTheme.font(barFontSize))
                    .foregroundColor(TerminalTheme.error)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
            }

            hintBar
        }
        // 透明度只作用在黑色背景，文字與色塊維持不透明
        .background(Color.black.opacity(viewModel.windowOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .contextMenu { windowContextMenu }
    }

    // MARK: - 標題列 / 提示列

    /// 標題列、提示列等狀態列沿用字體設定。
    private var barFontSize: CGFloat { viewModel.fontSize }

    private var titleText: String {
        switch viewModel.screen {
        case .chat:
            if let target = viewModel.targetArticle {
                return "【實況】\(target.title)"
            }
            return "【看板】\(viewModel.currentBoard.name)"
        case .settings: return "【個人設定】"
        case .boards: return "【熱門看板】"
        case .help: return "【使用說明】"
        }
    }

    private var statusText: String {
        var parts: [String] = []
        if queueManager.queuedCount > 0 { parts.append("● 待播 \(queueManager.queuedCount)") }
        if queueManager.isPaused { parts.append("暫停") }
        if viewModel.isLocked { parts.append("已固定") }
        if viewModel.filterType != .all { parts.append(viewModel.filterType.rawValue) }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private var hintBar: some View {
        if viewModel.isConfirmingQuit {
            TerminalQuitConfirmBar(fontSize: barFontSize, onTap: viewModel.dispatch)
        } else {
            switch viewModel.screen {
            case .chat:
                TerminalHintBar(
                    modeLabel: viewModel.targetArticle == nil ? "看板串流" : "單篇實況",
                    hints: chatHints,
                    fontSize: barFontSize,
                    onTap: viewModel.dispatch
                )
            case .settings:
                TerminalHintBar(modeLabel: "個人設定", hints: subScreenHints(adjustable: true), fontSize: barFontSize, onTap: viewModel.dispatch)
            case .boards:
                TerminalHintBar(modeLabel: "熱門看板", hints: subScreenHints(), fontSize: barFontSize, onTap: viewModel.dispatch)
            case .help:
                TerminalHintBar(modeLabel: "使用說明", hints: subScreenHints(confirmable: false), fontSize: barFontSize, onTap: viewModel.dispatch)
            }
        }
    }

    private var chatHints: [HintItem] {
        var hints: [HintItem] = []
        let isArticleMode = viewModel.targetArticle != nil
        if isArticleMode {
            hints.append(HintItem(key: "Q", label: "返回看板", command: .back))
        }
        hints.append(HintItem(key: "P", label: queueManager.isPaused ? "繼續" : "暫停", command: .pause))
        hints.append(HintItem(key: "F", label: "篩選", command: .filter))
        hints.append(HintItem(key: "0", label: "置頂", command: .scrollToTop))
        hints.append(HintItem(key: "$", label: "置底", command: .scrollToBottom))
        if !isArticleMode {
            hints.append(HintItem(key: "B", label: "看板", command: .boards))
        }
        hints += [
            HintItem(key: "L", label: "固定", command: .lock),
            HintItem(key: "T", label: "浮動", command: .top),
            HintItem(key: "S", label: "設定", command: .settings),
            HintItem(key: "?", label: "說明", command: .help),
            HintItem(key: "X", label: "離開", command: .quit),
        ]
        return hints
    }

    /// 子畫面提示列：`(↑↓)移動 (←→)調整 (Enter)確定 (Q)返回`。
    /// 用滑鼠點 `(↑↓)` 等同往下移、點 `(←→)` 等同往右調（皆會循環／步進）。
    private func subScreenHints(adjustable: Bool = false, confirmable: Bool = true) -> [HintItem] {
        var hints = [HintItem(key: "↑↓", label: "移動", command: .down)]
        if adjustable { hints.append(HintItem(key: "←→", label: "調整", command: .right)) }
        if confirmable { hints.append(HintItem(key: "Enter", label: "確定", command: .enter)) }
        hints.append(HintItem(key: "Q", label: "返回", command: .back))
        return hints
    }

    // MARK: - 中間區塊

    @ViewBuilder
    private var middleArea: some View {
        switch viewModel.screen {
        case .chat:
            chatBody
        case .settings:
            SettingsScreenView(viewModel: viewModel)
        case .boards:
            BoardListScreenView(viewModel: viewModel)
        case .help:
            HelpScreenView(viewModel: viewModel)
        }
    }

    private var chatBody: some View {
        GeometryReader { scrollGeo in
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // 頂部定位點（置頂用）
                            Color.clear
                                .frame(height: 1)
                                .id("top_anchor")

                            if viewModel.messages.isEmpty {
                                emptyStateView
                            } else if viewModel.filteredMessages.isEmpty {
                                Text("（目前沒有符合篩選的留言）")
                                    .font(TerminalTheme.font(viewModel.fontSize))
                                    .foregroundColor(TerminalTheme.time)
                                    .padding(.horizontal, 4)
                            } else {
                                let rows = ChatRow.build(
                                    from: viewModel.filteredMessages,
                                    showSeparators: viewModel.targetArticle == nil
                                )
                                ForEach(rows) { row in
                                    switch row {
                                    case .separator(_, let title, let url):
                                        TerminalSeparatorRow(title: title, url: url, fontSize: viewModel.fontSize)
                                    case .message(let message):
                                        TerminalMessageRow(
                                            message: message,
                                            fontSize: viewModel.fontSize,
                                            canLockArticle: viewModel.targetArticle == nil,
                                            onLockArticle: { title, url, board in
                                                viewModel.lockToArticle(title: title, url: url, board: board)
                                            }
                                        )
                                    }
                                }
                            }

                            // 底部定位點 (永久存在)
                            Color.clear
                                .frame(height: 1)
                                .id("bottom_anchor")
                                .background(
                                    GeometryReader { anchorGeo in
                                        Color.clear.preference(
                                            key: BottomAnchorDistanceKey.self,
                                            value: anchorGeo.frame(in: .named("scroll_container")).maxY
                                        )
                                    }
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                        .padding(.vertical, 4)
                        // 縮放視窗、改字級、新留言造成內容高度改變時，preference 也會回報
                        // 「離底部很遠」而誤判成使用者往上捲；這裡觀察底層 NSScrollView，
                        // 原本貼底時維持貼底，只有純捲動才算往上捲。
                        .background(ScrollBottomDistanceObserver { distance in
                            handleBottomDistance(distance)
                        })
                    }
                    .coordinateSpace(name: "scroll_container")
                    .onPreferenceChange(BottomAnchorDistanceKey.self) { bottomY in
                        handleBottomDistance(bottomY - scrollGeo.size.height)
                    }

                    if isUserScrolledUp {
                        newMessagesBar
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.dispatch(.scrollToBottom) }
                    }
                }
                .onReceive(viewModel.keyCommands) { cmd in
                    if cmd == .scrollToBottom { scrollToBottom(proxy) }
                    if cmd == .scrollToTop { scrollToTop(proxy) }
                }
                // 用最後一則的 id 偵測新留言：達到 150 則上限後 count 不再變動
                .onChange(of: viewModel.messages.last?.id) { lastId in
                    if isUserScrolledUp {
                        newMessagesWhileScrolledUp += 1
                    } else if lastId != nil {
                        scrollToBottom(proxy, delay: 0.05)
                    }
                }
                .onChange(of: viewModel.targetArticle) { _ in
                    scrollToBottom(proxy, delay: 0.1)
                }
                .onChange(of: viewModel.filterType) { _ in
                    scrollToBottom(proxy, delay: 0.05)
                }
                // 從子畫面返回時 ScrollView 會重建，回到底部
                .onAppear {
                    scrollToBottom(proxy, delay: 0.05)
                }
            }
        }
    }

    private var newMessagesBar: some View {
        let count = newMessagesWhileScrolledUp
        let text = count > 0 ? "▼ 有 \(count) 則新留言  ($)置底" : "▼ ($)置底"
        return Text(text)
            .font(TerminalTheme.font(barFontSize))
            .foregroundColor(TerminalTheme.highlightFg)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TerminalTheme.highlightBg)
    }

    /// 依「底部定位點距離可視範圍底部」判斷使用者是否往上捲（門檻 120pt／30pt）。
    private func handleBottomDistance(_ diff: CGFloat) {
        if diff > 120 {
            if !isProgrammaticScrolling && !isUserScrolledUp {
                isUserScrolledUp = true
            }
        } else if diff < 30 {
            if isUserScrolledUp {
                isUserScrolledUp = false
                newMessagesWhileScrolledUp = 0
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, delay: Double = 0) {
        isProgrammaticScrolling = true
        isUserScrolledUp = false
        newMessagesWhileScrolledUp = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            proxy.scrollTo("bottom_anchor", anchor: .bottom)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
            isProgrammaticScrolling = false
        }
    }

    /// 置頂：捲到最舊的留言，並暫停自動跟隨（與使用者往上捲相同）。
    private func scrollToTop(_ proxy: ScrollViewProxy) {
        isUserScrolledUp = true
        proxy.scrollTo("top_anchor", anchor: .top)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if let target = viewModel.targetArticle {
            Text("正在監聽【\(target.title)】，每 \(Int(viewModel.articleRefreshInterval)) 秒更新……")
                .font(TerminalTheme.font(viewModel.fontSize))
                .foregroundColor(TerminalTheme.content)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        } else {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let showCursor = Int(context.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
                (Text("正在連線到 \(viewModel.currentBoard.name) 看板……")
                    .foregroundColor(TerminalTheme.content)
                 + Text("█").foregroundColor(showCursor ? TerminalTheme.push : .clear))
                    .font(TerminalTheme.font(viewModel.fontSize))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 視窗右鍵選單

    @ViewBuilder
    private var windowContextMenu: some View {
        Button("使用說明與快捷鍵") {
            viewModel.screen = .help
        }

        Divider()

        if viewModel.targetArticle != nil {
            Button("解除單篇鎖定，返回看板") {
                viewModel.unlockTargetArticle()
            }
            Divider()
        }

        Button("切換看板") {
            viewModel.screen = .boards
        }

        Button(queueManager.isPaused ? "繼續播放" : "暫停推播") {
            viewModel.togglePause()
        }

        Button("清空畫面留言") {
            viewModel.clearMessages()
        }

        Divider()

        Button(viewModel.isAlwaysOnTop ? "取消視窗浮動 (點擊其他應用時允許被覆蓋)" : "開啟視窗浮動 (永遠在所有視窗之上)") {
            viewModel.isAlwaysOnTop.toggle()
        }

        Button(viewModel.isLocked ? "解除視窗固定" : "固定視窗位置 (防誤拖曳)") {
            viewModel.isLocked.toggle()
        }

        Divider()

        Button("結束應用程式") {
            NSApplication.shared.terminate(nil)
        }
    }
}

/// 觀察包住自己的 NSScrollView，回報「內容底部距離可視範圍底部」的距離（pt）。
private struct ScrollBottomDistanceObserver: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let view = ObserverView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        nsView.onChange = onChange
    }

    final class ObserverView: NSView {
        var onChange: ((CGFloat) -> Void)?
        private var tokens: [NSObjectProtocol] = []
        private weak var observedScrollView: NSScrollView?
        private var lastViewportSize: CGSize = .zero
        private var lastDocumentHeight: CGFloat = 0
        private var lastDistance: CGFloat = 0

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeTokens()
            guard window != nil, let scrollView = enclosingScrollView else { return }
            observedScrollView = scrollView
            let clipView = scrollView.contentView
            clipView.postsBoundsChangedNotifications = true
            clipView.postsFrameChangedNotifications = true
            var targets: [(NSNotification.Name, NSView)] = [
                (NSView.boundsDidChangeNotification, clipView),
                (NSView.frameDidChangeNotification, clipView),
            ]
            if let doc = scrollView.documentView {
                doc.postsFrameChangedNotifications = true
                targets.append((NSView.frameDidChangeNotification, doc))
            }
            tokens = targets.map { name, object in
                NotificationCenter.default.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                    self?.evaluate()
                }
            }
        }

        /// 只有「可視範圍與內容大小都沒變、但位置變了」才算使用者捲動。
        /// 內容或視窗大小改變（新留言、縮放視窗、改字級、切換篩選）時，若原本貼底就維持貼底。
        private func evaluate() {
            guard let scrollView = observedScrollView, let doc = scrollView.documentView else { return }
            let clipView = scrollView.contentView
            let visible = clipView.bounds
            let documentHeight = doc.frame.height
            let geometryChanged = visible.size != lastViewportSize || documentHeight != lastDocumentHeight
            let wasAtBottom = lastDistance < 30
            lastViewportSize = visible.size
            lastDocumentHeight = documentHeight

            if geometryChanged && wasAtBottom {
                let bottomY = doc.isFlipped ? max(0, documentHeight - visible.height) : 0
                if abs(visible.minY - bottomY) > 0.5 {
                    clipView.scroll(to: NSPoint(x: visible.minX, y: bottomY))
                    scrollView.reflectScrolledClipView(clipView)
                }
                lastDistance = 0
                // 回呼會寫入 @State，延到下一輪 runloop，避免在 layout 期間改狀態
                let callback = onChange
                DispatchQueue.main.async { callback?(0) }
                return
            }

            let distance = doc.isFlipped ? documentHeight - visible.maxY : visible.minY
            lastDistance = distance
            let callback = onChange
            DispatchQueue.main.async { callback?(distance) }
        }

        private func removeTokens() {
            tokens.forEach { NotificationCenter.default.removeObserver($0) }
            tokens = []
        }

        deinit {
            tokens.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}
