import Foundation

@MainActor
public final class MessageQueueManager: ObservableObject {
    @Published public private(set) var queuedCount: Int = 0
    @Published public var isPaused: Bool = false

    private var queue: [PTTMessage] = []
    private var seenKeys = Set<String>()
    private var timer: Timer?

    public var onMessageEmit: ((PTTMessage) -> Void)?

    public init() {}

    /// 標記一批訊息為已讀 (避免將既有舊推文重新排隊)
    public func markSeen(messages: [PTTMessage]) {
        for msg in messages {
            seenKeys.insert(msg.dedupKey)
        }
    }

    /// 加入一批抓取到的新推文（自動去重）
    public func enqueue(messages: [PTTMessage]) {
        var newArrivals: [PTTMessage] = []

        for msg in messages {
            if !seenKeys.contains(msg.dedupKey) {
                seenKeys.insert(msg.dedupKey)
                newArrivals.append(msg)
            }
        }

        if seenKeys.count > 10000 {
            seenKeys.removeAll(keepingCapacity: true)
            for msg in newArrivals {
                seenKeys.insert(msg.dedupKey)
            }
        }

        guard !newArrivals.isEmpty else { return }

        queue.append(contentsOf: Self.groupedByArticle(newArrivals))
        queuedCount = queue.count

        scheduleNextEmit()
    }

    /// 同一批推文依文章分組：組別依首次出現順序，組內保持原順序；articleUrl 為 nil 者歸為同一組
    nonisolated public static func groupedByArticle(_ messages: [PTTMessage]) -> [PTTMessage] {
        var order: [String] = []
        var groups: [String: [PTTMessage]] = [:]
        for msg in messages {
            let key = msg.articleUrl?.absoluteString ?? ""
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(msg)
        }
        return order.flatMap { groups[$0] ?? [] }
    }

    /// 立即取出所有待播訊息（置底用）；保留去重紀錄，停止目前的推播計時
    public func drainAll() -> [PTTMessage] {
        timer?.invalidate()
        timer = nil
        let drained = queue
        queue.removeAll()
        queuedCount = 0
        return drained
    }

    /// 清除所有隊列（如切換看板或單篇文章時）
    public func reset() {
        timer?.invalidate()
        timer = nil
        queue.removeAll()
        seenKeys.removeAll()
        queuedCount = 0
    }

    public func togglePause() {
        isPaused.toggle()
        if !isPaused {
            scheduleNextEmit()
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func scheduleNextEmit() {
        guard !isPaused, timer == nil, !queue.isEmpty else { return }

        let delay: TimeInterval
        let count = queue.count
        if count > 30 {
            delay = 0.25
        } else if count > 15 {
            delay = 0.5
        } else if count > 5 {
            delay = 0.8
        } else {
            delay = 1.2
        }

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.timer = nil
                self.popAndEmit()
            }
        }
    }

    private func popAndEmit() {
        guard !isPaused, !queue.isEmpty else { return }
        let message = queue.removeFirst()
        queuedCount = queue.count
        onMessageEmit?(message)

        if !queue.isEmpty {
            scheduleNextEmit()
        }
    }
}
