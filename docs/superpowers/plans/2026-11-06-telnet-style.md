# PTT Marquee telnet 終端機風格改版 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把主畫面、設定、看板清單與說明全部改成 telnet PTT 風格（黑底、ANSI 色、藍色標題列、青色按鍵提示列、整頁子畫面、鍵盤加滑鼠操作），並讓推播依文章分組。

**Architecture:**
- 鍵盤事件統一由 `FloatingPanelController` 的 local monitor 轉成 `KeyCommand`，再透過 `ChatViewModel.keyCommands`（`PassthroughSubject`）廣播。
- 畫面依 `ChatViewModel.screen`（`TerminalScreen`）切換聊天、設定、看板、說明四頁。
- 可以單元測試的邏輯抽成純函式：分隔線列 `ChatRow.build`、推播分組 `MessageQueueManager.groupedByArticle`、按鍵對應 `KeyCommand.from`、方塊條數值 `BlockBar`，放進新增的 XCTest target 測試。
- 其餘 View 以 build 成功加手動目測驗證。

**Tech Stack:** Swift 5.9、SwiftUI + AppKit、macOS 13、XcodeGen 2.44、XCTest

**Spec:** `docs/superpowers/specs/2026-11-06-telnet-style-design.md`（每個 task 都要對照 spec 的對應段落）

## Global Constraints

- macOS 13.0 deployment target；不得使用 macOS 14+ API，例如 `onKeyPress`、`onScrollGeometryChange`。
- 不引入第三方套件。
- 新增或刪除檔案後執行 `xcodegen generate`；不手改 `project.pbxproj`。
- 配色固定為：推 `#ffffff` 粗體、噓 `#ff5555`、→ `#a80000`、ID `#ffff55`、內文 `#a8a800`、時間 `#808080`、標題列底 `#0000a8` 白字、提示列底 `#00a8a8` 黑字、按鍵區塊底 `#a8a8a8`、反白底 `#00a8a8` 黑字、錯誤紅字 `#ff5555`。
- 字型：等寬，`Font.custom("Menlo", size:)`；中文由系統退回 PingFang TC。字體大小沿用 `viewModel.fontSize`（11～18）。
- 畫面上不得出現 SF Symbols 圖示、圓角卡片、膠囊、原生 popover 或 sheet（右鍵選單除外）。
- 所有功能都必須能用滑鼠操作。
- 這個專案**不是 git repo**，所以計畫裡沒有 commit 步驟；每個 task 結束時以「build 與測試通過」作為檢查點。
- 通用 build 指令：`xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' build 2>&1 | tail -5`，預期最後出現 `** BUILD SUCCEEDED **`。
- 通用測試指令：`xcodebuild test -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' 2>&1 | tail -15`，預期出現 `** TEST SUCCEEDED **`。

## Review Focus

1. 在設定的輸入欄打 `Stock` 或貼上網址時，S、T、O、C、K 都不能觸發快捷鍵，中文輸入法組字也不能被吃掉。→ Task 3 的 `test_textInputActive_returnsNil`。
2. 帶 ⌘、⌃、⌥ 的按鍵（⌘Q、⌘C、⌘V）不能被當成單鍵 Q、C、V 吞掉。→ Task 3 的 `test_modifiedKeys_returnNil`。
3. 切換篩選（只看噓）後，分隔線要依篩選後的相鄰關係重新計算，而且最上面第一則前面一定有分隔線。→ Task 2 的 `test_filteredList_recomputesSeparators`、`test_firstMessage_alwaysHasSeparator`。
4. 推播分組只能在同一批之內重排，不能動隊列中已有的推文，去重也要照舊；`articleUrl` 為 nil 的推文要各自歸成同一組，不能 crash。→ Task 1 的 `test_enqueue_doesNotReorderExistingQueue`、`test_grouping_nilUrlGroupedTogether`。
5. 視窗縮到最小寬度 280pt 時，提示列要折成兩行，每個按鍵都看得到、點得到。→ Task 5 的手動驗證步驟。

---

### Task 1: 測試 target 與推播分組

**Files:**
- Modify: `project.yml`（新增 `PTTMarqueeTests` target 與 `schemes:`）
- Create: `PTTMarqueeTests/MessageQueueGroupingTests.swift`
- Modify: `PTTMarquee/Services/MessageQueueManager.swift:31-55`（`enqueue`）

**Interfaces:**
- Produces: `public static func groupedByArticle(_ messages: [PTTMessage]) -> [PTTMessage]`（`MessageQueueManager` 上的 static 方法）；測試 target `PTTMarqueeTests`。

- [ ] **Step 1：在 `project.yml` 新增測試 target 與 scheme**

```yaml
  PTTMarqueeTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: PTTMarqueeTests
    dependencies:
      - target: PTTMarquee
schemes:
  PTTMarquee:
    build:
      targets:
        PTTMarquee: all
        PTTMarqueeTests: [test]
    test:
      targets:
        - PTTMarqueeTests
```

`PTTMarqueeTests:` 放在 `targets:` 底下，`schemes:` 放在檔案最外層。

- [ ] **Step 2：寫會失敗的測試** `PTTMarqueeTests/MessageQueueGroupingTests.swift`，用 `@testable import PTTMarquee`，並寫一個 helper `msg(_ article: String?, _ user: String) -> PTTMessage`，其中 article 為 nil 時 `articleUrl = nil`。

```swift
func test_grouping_ordersByFirstAppearance_keepsInnerOrder() {
    let input = [msg("A","1"), msg("B","2"), msg("A","3"), msg("C","4"), msg("B","5")]
    XCTAssertEqual(MessageQueueManager.groupedByArticle(input).map(\.userId), ["1","3","2","5","4"])
}
func test_grouping_nilUrlGroupedTogether() {
    let input = [msg(nil,"1"), msg("A","2"), msg(nil,"3")]
    XCTAssertEqual(MessageQueueManager.groupedByArticle(input).map(\.userId), ["1","3","2"])
}
@MainActor func test_enqueue_doesNotReorderExistingQueue() async {
    let q = MessageQueueManager()
    var emitted: [String] = []
    q.onMessageEmit = { emitted.append($0.userId) }
    q.togglePause()                                   // 暫停，讓隊列不自動推出
    q.enqueue(messages: [msg("A","1"), msg("B","2")])
    q.enqueue(messages: [msg("B","3"), msg("A","4"), msg("B","5")])
    q.enqueue(messages: [msg("A","1")])               // 重複的推文，應被去重
    XCTAssertEqual(q.queuedCount, 5)
    q.togglePause()
    try? await Task.sleep(nanoseconds: 7_000_000_000)
    XCTAssertEqual(emitted, ["1","2","3","5","4"])
}
```

- [ ] **Step 3：執行測試，確認它會失敗**

先執行 `xcodegen generate`，再執行通用測試指令。預期 FAIL，錯誤為 `type 'MessageQueueManager' has no member 'groupedByArticle'`。

- [ ] **Step 4：實作**

在 `MessageQueueManager` 加上 `groupedByArticle`，以 `articleUrl?.absoluteString ?? ""` 作為分組 key，確保排序穩定。`enqueue` 在 `queue.append(contentsOf:)` 前改成 `queue.append(contentsOf: Self.groupedByArticle(newArrivals))`。

- [ ] **Step 5：執行測試，確認通過**

執行通用測試指令，預期 `** TEST SUCCEEDED **`。

---

### Task 2: 終端機主題與分隔線列模型

**Files:**
- Create: `PTTMarquee/Views/Terminal/TerminalTheme.swift`
- Create: `PTTMarquee/ViewModels/ChatRow.swift`
- Modify: `PTTMarquee/Models/PTTMessage.swift:15-26`（刪除 `badgeColor`，以及因此不再需要的 `import SwiftUI`）
- Create: `PTTMarqueeTests/ChatRowTests.swift`

**Interfaces:**
- Produces:
  - `enum TerminalTheme`：
    - 顏色 static 常數 `push, boo, arrow, userId, content, time, titleBarBg, titleBarFg, hintBarBg, hintBarFg, keyChipBg, highlightBg, highlightFg, error, separator`。
    - `static func color(for tag: PushTag) -> Color`，`.other` 回傳 `time` 的灰色。
    - `static func font(_ size: CGFloat, bold: Bool = false) -> Font`，使用 Menlo。
  - `enum ChatRow: Identifiable`，包含兩種 case：
    - `case separator(id: String, title: String, url: URL?)`
    - `case message(PTTMessage)`
  - `static func build(from messages: [PTTMessage], showSeparators: Bool) -> [ChatRow]`
  - 分隔線的 id 為 `"sep-\(第一則訊息的 id)"`，確保在列表中穩定不變。

- [ ] **Step 1：寫會失敗的測試** `ChatRowTests.swift`

```swift
func test_firstMessage_alwaysHasSeparator()      // [A1] → [sep(A), A1]
func test_separatorOnlyWhenArticleChanges()      // [A1,A2,B3,A4] → [sep A,A1,A2,sep B,B3,sep A,A4]
func test_noSeparatorsInSingleArticleMode()      // showSeparators:false → 只有 message
func test_filteredList_recomputesSeparators()    // 篩選掉 B3 後的 [A1,A2,A4] → [sep A,A1,A2,A4]
func test_separatorTitleAndUrlComeFromMessage()  // sep 的 title == articleTitle、url == articleUrl
```

每個測試都比對 `rows.map { 簡寫字串 }`，例如 `"sep:A"`、`"msg:1"`。

- [ ] **Step 2：執行測試，確認失敗**（`ChatRow` 尚未定義）
- [ ] **Step 3：實作 `TerminalTheme`、`ChatRow.build`，並刪除 `badgeColor`**

`MessageRowView.swift` 會因為 `badgeColor` 被刪而編譯失敗。這一步先暫時改成 `TerminalTheme.color(for:)`，Task 5 會整個重寫這個檔案。

- [ ] **Step 4：執行測試，確認通過**

---

### Task 3: 按鍵指令與鍵盤路由

**Files:**
- Create: `PTTMarquee/ViewModels/KeyCommand.swift`
- Modify: `PTTMarquee/WindowController.swift:94-117`（`setupHotkeys` 的 local monitor）
- Modify: `PTTMarquee/ViewModels/ChatViewModel.swift`（新增屬性與方法，見下方）
- Create: `PTTMarquee/ViewModels/TerminalScreen.swift`
- Create: `PTTMarqueeTests/KeyCommandTests.swift`

**Interfaces:**
- Produces:
  - `enum KeyCommand: Equatable`，包含：`pause, filter, boards, lock, top, settings, help, quit, back, scrollToBottom, up, down, left, right, enter, escape, yes, no`。
  - `static func from(characters: String?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isTextInputActive: Bool) -> KeyCommand?`
    - 字元對應（不分大小寫）：p→pause、f→filter、b→boards、l→lock、t→top、s→settings、?→help、x→quit、q→back、g→scrollToBottom、y→yes、n→no。
    - keyCode 對應：119→scrollToBottom、126→up、125→down、123→left、124→right、36 或 76→enter、53→escape。
    - modifiers 包含 `.command`、`.control` 或 `.option` 時回傳 nil；`.shift` 允許，因為打 `?` 需要按 Shift。
    - `isTextInputActive == true` 時一律回傳 nil。
  - `enum TerminalScreen: Equatable { case chat, settings, boards, help }`
  - `ChatViewModel` 新增：
    - `@Published var screen: TerminalScreen = .chat`
    - `@Published var isTextInputActive = false`
    - `@Published var isConfirmingQuit = false`
    - `let keyCommands = PassthroughSubject<KeyCommand, Never>()`
    - `func cycleFilter()`：依序 all → pushOnly → booOnly → all
    - `func handleChatCommand(_ cmd: KeyCommand)`：只在 `screen == .chat` 時處理。
      - pause/filter/lock/top 對應現有功能。
      - boards/settings/help 切換 `screen`。
      - quit 把 `isConfirmingQuit` 設為 true。
      - 確認離開狀態下，yes 結束 app，no 或 escape 取消。
      - back 在單篇模式下呼叫 `unlockTargetArticle()`。
      - scrollToBottom 交給 View 處理（見 Task 5）。
- 路由規則：local monitor 先處理既有的 ⌘⇧L/P。接著若 `panel.isKeyWindow`，且 `KeyCommand.from(...)` 不為 nil，就 `viewModel.keyCommands.send(cmd)`，回傳 `nil` 以避免 NSBeep；否則回傳原本的 event。`ChatViewModel` 在 init 裡用 `keyCommands.sink` 呼叫 `handleChatCommand`；子畫面的 View 自己用 `.onReceive(viewModel.keyCommands)` 處理。

- [ ] **Step 1：寫會失敗的測試** `KeyCommandTests.swift`

```swift
func test_letterKeys_mapCaseInsensitive()   // "p","P" → .pause；"?"(shift) → .help；"g" → .scrollToBottom
func test_specialKeyCodes()                 // 119 → .scrollToBottom、53 → .escape、36 → .enter、126 → .up
func test_modifiedKeys_returnNil()          // "q"+.command、"c"+.command、"v"+.control、"p"+.option → nil
func test_textInputActive_returnsNil()      // "s"、"t"、keyCode 36，isTextInputActive:true → nil
func test_unknownKey_returnsNil()           // "z" → nil
@MainActor func test_cycleFilter()          // all → pushOnly → booOnly → all
@MainActor func test_quitRequiresConfirm()  // handleChatCommand(.quit) → isConfirmingQuit == true；.no → false
```

- [ ] **Step 2：執行測試，確認失敗**
- [ ] **Step 3：實作 `KeyCommand`、`TerminalScreen`，以及 `ChatViewModel` 的新增成員與路由**

`yes` 會呼叫 `NSApplication.shared.terminate`，測試時不要送 `.yes`。

- [ ] **Step 4：執行測試，確認通過；再 build 一次確認 app 本體可編譯**

---

### Task 4: 方塊條數值邏輯

**Files:**
- Create: `PTTMarquee/Views/Terminal/BlockBar.swift`
- Create: `PTTMarqueeTests/BlockBarTests.swift`

**Interfaces:**
- Produces：`struct BlockBar`，欄位為 `range: ClosedRange<Double>`、`step: Double`、`cells: Int = 8`，方法如下：
  - `func filledCells(for value: Double) -> Int`：四捨五入，最小為 0，最大為 cells。
  - `func stepped(_ value: Double, direction: Int) -> Double`：加減一個 step，並夾在 range 之內。
  - `func value(forCell index: Int) -> Double`：index 從 0 開始，第 cells−1 格等於 `range.upperBound`，結果要對齊 step。
  - 四組設定值（照 spec 和現有 Slider）：
    - `static let boardInterval = BlockBar(range: 5...30, step: 1)`
    - `static let articleInterval = BlockBar(range: 2...15, step: 1)`
    - `static let opacity = BlockBar(range: 0.25...1.0, step: 0.05)`
    - `static let fontSize = BlockBar(range: 11...18, step: 1)`

- [ ] **Step 1：寫會失敗的測試**

```swift
func test_stepped_clampsToRange()      // boardInterval.stepped(30, +1) == 30；stepped(5, -1) == 5；stepped(8, +1) == 9
func test_opacityStep()                // opacity.stepped(0.85, +1) ≈ 0.90（accuracy 0.001）
func test_filledCells()                // boardInterval：5 → 0、30 → 8；fontSize：13 → 2
func test_valueForCell_lastIsUpperBound_andSnapsToStep()  // boardInterval.value(forCell:7) == 30；value(forCell:0) == 5；結果 % 1 == 0
```

- [ ] **Step 2：執行測試，確認失敗**
- [ ] **Step 3：實作 `BlockBar`**
- [ ] **Step 4：執行測試，確認通過**

---

### Task 5: 主畫面（聊天室）改版

**Files:**
- Create: `PTTMarquee/Views/Terminal/TerminalBars.swift`
  - `TerminalTitleBar(title: String, status: String, isDraggable: Bool)`
  - `TerminalHintBar(modeLabel: String, hints: [HintItem])`
  - `struct HintItem: Identifiable { key: String; label: String; command: KeyCommand }`
  - `FlowLayout: Layout`：寬度不夠時自動換行
- Rewrite: `PTTMarquee/Views/MessageRowView.swift`（改名為 `TerminalMessageRow`，檔名同步改成 `TerminalMessageRow.swift`）
- Create: `PTTMarquee/Views/Terminal/TerminalSeparatorRow.swift`
- Rewrite: `PTTMarquee/Views/ChatOverlayView.swift`
- Delete: `PTTMarquee/Views/OverlayToolbarView.swift`（`WindowDragArea` 搬到 `TerminalBars.swift`）

**Interfaces:**
- Consumes：`TerminalTheme`、`ChatRow.build`、`KeyCommand`、`TerminalScreen`、`viewModel.keyCommands`、`viewModel.isConfirmingQuit`（Task 2、3）。
- Produces：
  - `TerminalTitleBar`、`TerminalHintBar`、`HintItem`，Task 6 的子畫面會沿用。
  - `ChatOverlayView` 依 `viewModel.screen` 決定中間區塊顯示 `chatBody`、`SettingsScreenView`、`BoardListScreenView` 或 `HelpScreenView`；子畫面在 Task 6 實作，這個 task 先放 `Text("TODO")` 占位。

這個 task 要符合的 spec 細節（實作者依此判斷）：
- **背景**：`TerminalTheme` 黑色乘上 `viewModel.windowOpacity`，只套在背景；整個 View 不再套 `.opacity`。拿掉 `VisualEffectBackground` 和黑色疊層，視窗圓角改為 4pt 以下。
- **標題列**：
  - 看板模式顯示 `【看板】<name>`；單篇模式顯示 `【實況】<文章標題>`，取代原本的橘色橫幅。
  - 狀態依序以空白分隔串成一行：`● 待播 N`（N > 0 時才顯示）、`暫停`、`已固定`、`只看推`／`只看噓`。
  - `isDraggable = !viewModel.isLocked`，可拖曳時疊上 `WindowDragArea`。
- **留言行**：
  - `HStack(alignment: .firstTextBaseline)`，依序為：標籤、`ID:`、內文（可換行，`fixedSize(horizontal:false, vertical:true)`，自然形成懸掛縮排）、`Spacer`、時間。
  - 時間只取 `MM/dd HH:mm`，沿用原本的 `displayTime` 邏輯。
  - hover 時整行改用反白底色加反白前景色；不加 transition 動畫。
  - 點擊留言行不做任何事。
  - 右鍵選單沿用原本的項目，但拿掉 emoji。「鎖定此篇為實況聊天室」只在看板模式顯示。
- **分隔線**：`─── [標題] ` 後面接重複的 `─`，用 `lineLimit(1)` 截斷到填滿寬度，顏色用 `separator` 灰。點擊時用 `NSWorkspace.shared.open(url)` 開啟原文。
- **列表**：用 `ChatRow.build(from: viewModel.filteredMessages, showSeparators: viewModel.targetArticle == nil)`。保留原本 `BottomAnchorDistanceKey` 的往上捲偵測（門檻 120pt 和 30pt）與 `isProgrammaticScrolling`。
- **新留言提示**：往上捲時，在提示列上方顯示一行反白的 `▼ 有 N 則新留言  (End)回到底部`（N = 0 時不顯示「有 N 則新留言」），點擊後捲到底部。`.onReceive(viewModel.keyCommands)` 收到 `.scrollToBottom` 時做同樣的事。
- **錯誤列**：`viewModel.errorMessage` 不為 nil 時，在提示列上方顯示一行紅字。
- **提示列**：
  - 看板模式：`看板串流`，按鍵為 `(P)暫停／繼續 (F)篩選 (B)看板 (L)鎖定 (T)置頂 (S)設定 (?)說明 (X)離開`。
  - 單篇模式：`單篇實況`，在上述按鍵前加上 `(Q)返回看板`，並拿掉 `(B)`。
  - `isConfirmingQuit` 時整列改成 `確定要離開嗎？(Y/N)`，Y、N 也可以點。
  - 點任何 HintItem 都等同 `viewModel.keyCommands.send(item.command)`。
- **空狀態**：
  - 看板模式：`正在連線到 <board> 看板……` 加閃爍的 `█` 游標。
  - 單篇模式：`正在監聽【<title>】，每 <Int(articleRefreshInterval)> 秒更新……`。
  - `messages` 不為空但 `filteredMessages` 為空時：`（目前沒有符合篩選的留言）`。
- **視窗右鍵選單**：
  - 「使用說明」改成 `viewModel.screen = .help`。
  - 拿掉 emoji。
  - 「切換看板」改成 `viewModel.screen = .boards`。
  - 拿掉 `.sheet`。

- [ ] **Step 1：搬移、新增、刪除檔案後執行 `xcodegen generate`**
- [ ] **Step 2：完成上述 View，執行通用 build 指令，預期 BUILD SUCCEEDED**
- [ ] **Step 3：執行通用測試指令，確認前面 task 的測試仍然通過**
- [ ] **Step 4：手動驗證**

先執行 `./run.sh`，再逐項確認：
- (a) 畫面上沒有任何 SF Symbol 圖示或圓角卡片。
- (b) 看板模式有分隔線，點分隔線會開瀏覽器，點留言行不會開。
- (c) 往上捲時出現 `▼` 提示，按 G 會回到底部。
- (d) 把視窗拉到最窄（280pt），提示列折成兩行，每個按鍵都點得到。
- (e) 按 F 依序切換篩選，標題列顯示篩選狀態。
- (f) 按 X 出現確認訊息，按 N 取消。
- (g) 把透明度調到 25%，文字仍清楚。

---

### Task 6: 設定、看板清單、說明子畫面

**Files:**
- Create: `PTTMarquee/Views/Terminal/SettingsScreenView.swift`
- Create: `PTTMarquee/Views/Terminal/BoardListScreenView.swift`
- Create: `PTTMarquee/Views/Terminal/HelpScreenView.swift`
- Delete: `PTTMarquee/Views/SettingsSheetView.swift`、`PTTMarquee/Views/HelpSheetView.swift`
- Modify: `PTTMarquee/Views/ChatOverlayView.swift`（把 Task 5 的 TODO 占位換成這三個 View）

**Interfaces:**
- Consumes：`TerminalTitleBar`、`TerminalHintBar`、`HintItem`（Task 5）；`BlockBar`（Task 4）；`KeyCommand`、`viewModel.keyCommands`、`viewModel.screen`、`viewModel.isTextInputActive`（Task 3）。
- 三個子畫面的共通規則：
  - 標題列顯示 `【個人設定】`、`【熱門看板】`、`【使用說明】`。
  - 提示列為 `(↑↓)移動 (←→)調整 (Enter)確定 (Q)返回`；看板清單和說明不需要 `(←→)`。
  - 收到 `.back` 或 `.escape` 時，設定 `viewModel.screen = .chat`。
  - 用 `.onReceive(viewModel.keyCommands)` 處理按鍵，並用 `guard viewModel.screen == <自己>` 擋掉其他畫面的事件。

規格要點：
- **設定畫面的項目順序**：
  1. 置頂 `[ON ]`／`[OFF]`
  2. 固定位置
  3. 看板抓取間隔 `■■■□□□□□  8 秒`
  4. 單篇抓取間隔
  5. 背景透明度 `85%`
  6. 字體大小 `13pt`
  7. 前往看板：輸入欄
  8. 鎖定文章：輸入欄。單篇模式下改成顯示 `目前：<title>  (Enter)退出實況`，按 Enter 呼叫 `unlockTargetArticle()`。
  9. 清空畫面留言（黃色）
  10. 結束應用程式（紅色），按下後進入與主畫面相同的 Y/N 確認。
- **設定畫面的操作**：
  - 目前選到的那一行前面加 `▶`，並整行反白。
  - ↑↓ 移動選項並循環；←→ 對方塊條呼叫 `BlockBar.stepped`，對開關則切換。
  - 點方塊條的第 i 格，設為 `value(forCell:i)`。
  - 點任一行，等同把游標移到那一行並按 Enter。
- **輸入欄**：
  - 使用 `TextField`，`.textFieldStyle(.plain)`，加上底線。
  - 在該列按 Enter 時，用 `@FocusState` 讓輸入欄取得焦點；焦點變化同步到 `viewModel.isTextInputActive`。
  - `onSubmit` 時：看板欄呼叫 `setCustomBoard`，網址欄呼叫 `lockToArticle(byUrlString:)`。成功後清空輸入、取消焦點，並回到 `.chat`；網址無效時 `errorMessage` 已由 viewModel 設定，留在原畫面。
  - `onExitCommand` 時取消焦點，不送出。
- **看板清單**：
  - 每行格式為 `  1  Gossiping      八卦板`，目前看板以 `●` 標記。
  - ↑↓ 移動選項，Enter 或點擊時呼叫 `changeBoard`，然後回到 `.chat`。
  - 清單最後一行是 `  自訂看板…`，選了之後切到設定畫面，並把游標定位在「前往看板」那一列。
- **說明畫面**：純文字分段，可以捲動，內容是新的按鍵表（照 spec 的按鍵對照表），加上「右鍵選單」「單篇實況」「⌘⇧L／⌘⇧P 全域鎖定（需要輔助使用權限）」「設定會自動保存」各一段。

- [ ] **Step 1：新增或刪除檔案後執行 `xcodegen generate`**
- [ ] **Step 2：完成三個子畫面，執行通用 build 和測試指令，兩者都要通過**
- [ ] **Step 3：手動驗證**

執行 `./run.sh`，逐項確認：
- (a) 按 S 進入設定，用 ↑↓←→ 調整透明度和字體，聊天室立即反映。
- (b) 在「前往看板」輸入 `Stock` 時，不會觸發暫停、置頂或設定等快捷鍵；按 Enter 會切到 Stock 看板並回到聊天室。
- (c) 輸入無效網址會顯示紅字錯誤。
- (d) 按 B 進入看板清單，用 Enter 切換看板。
- (e) 按 ? 進入說明，按 Q 返回。
- (f) 在設定畫面停留 10 秒後返回，推文會接續播放。
- (g) 每一項都能只用滑鼠完成。

---

### Task 7: 文件更新

**Files:**
- Modify: `README.md`（「核心特色」第 5、6 點，以及「常用快捷操作」整張表）
- Modify: `CLAUDE.md`（架構段落：新增 `KeyCommand` 的路由方式、`TerminalScreen` 子畫面、`ChatRow` 分隔線、推播分組、測試 target 與測試指令）

- [ ] **Step 1：把 README 的快捷表改成 spec 的按鍵對照表，拿掉圖釘、鎖頭、齒輪、膠囊等描述，在「從原始碼建置」補上測試指令**
- [ ] **Step 2：更新 CLAUDE.md 的常用指令（加上 `xcodebuild test` 與只跑單一測試的 `-only-testing:PTTMarqueeTests/ChatRowTests`）和架構段落**
- [ ] **Step 3：執行 `grep -n "圖釘\|齒輪\|膠囊\|popover\|OverlayToolbarView\|SettingsSheetView\|HelpSheetView" README.md CLAUDE.md`，預期沒有任何輸出**
