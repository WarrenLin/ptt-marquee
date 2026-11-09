# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概要

PTT Marquee：macOS 13+ 原生浮動聊天室小工具（SwiftUI + AppKit，Swift 5.9），爬取 www.ptt.cc 網頁版推文，以類實況聊天室的節奏逐筆推播。UI 為仿 PTT telnet 終端機風格。無第三方相依套件、無 linter；有單元測試 target `PTTMarqueeTests`。

## 常用指令

```bash
./run.sh                      # build + 開啟 app（xcodebuild 輸出被導到 /dev/null，失敗時改用下一行看錯誤）
xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' build
xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' test
# 只跑單一測試類別
xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' test -only-testing:PTTMarqueeTests/ChatRowTests
xcodegen generate             # 新增/刪除/搬移原始檔後必須執行
./scripts/make-app-icon.sh    # 依 scripts/AppIcon.swift 重新產生 AppIcon.appiconset 各尺寸
./scripts/package.sh          # Release universal 打包到 dist/（.dmg + .zip；ad-hoc 簽章、未公證）
```

- `project.yml`（XcodeGen）才是專案設定來源，`PTTMarquee.xcodeproj` 是產生物；改 build settings 請改 `project.yml` 再重新 generate，不要手改 pbxproj。
- Git repo，遠端為 github.com/WarrenLin/ptt-marquee（公開）；截圖放在 `docs/screenshots/`。
- `PTTMarqueeTests` target 與 scheme 的 test 設定同樣定義在 `project.yml`。測試以 app 為宿主（會開視窗、連 PTT、共用真實 UserDefaults）。
- 細部規範在 `.claude/rules/`：UI 用詞、按鍵與終端機 UI、驗證方式、PTT 網路特性。telnet 改版的設計與計畫在 `docs/superpowers/`。
- `.superpowers/` 是草圖與改版過程快照，可刪除，不屬於產品程式碼。

### 發版流程

1. `project.yml` 調 `MARKETING_VERSION` 與 `CURRENT_PROJECT_VERSION`，`xcodegen generate`。
2. `CHANGELOG.md` 最上方新增該版（繁中，寫使用者看得到的症狀與修正）。
3. 跑完整測試 → commit → push。
4. `./scripts/package.sh` 產生 `dist/PTTMarquee-<版本>.dmg/.zip`（版本從 build 出來的 Info.plist 讀，`dist/` 不進 git）。
5. `gh release create v<版本> dist/PTTMarquee-<版本>.dmg dist/PTTMarquee-<版本>.zip`，release notes 用 CHANGELOG 該版內容。發佈是公開動作，先取得使用者同意。
- 個人專案：不要用公司的簽章憑證；app 為 ad-hoc 簽章、未公證。

## 架構

資料流：`AppDelegate` → `FloatingPanelController.shared`（`WindowController.swift`）建立無邊框 `NSPanel`，以 `NSHostingView` 掛上 `ChatOverlayView`，並持有唯一的 `ChatViewModel`。

- **`ChatViewModel`**（`@MainActor`）是整個 app 的狀態中心：
  - 一條 `pollTask` 無限輪詢迴圈，依 `targetArticle` 是否為 nil 分成兩種模式：
    - **看板聚合模式**：`PTTCrawlerService.fetchLatestMessages` 抓看板最新 8 篇文章（不足時補抓上一頁）的推文，全部丟進 queue。
    - **單篇實況模式**（`targetArticle != nil`）：首次載入直接把最後 40 筆塞進 `messages`，並 `markSeen` 全部推文；之後的新推文才走 queue。
  - 每輪抓完才 `sleep` 設定的間隔（看板最少 4 秒、單篇最少 2 秒），所以實際週期 = 間隔 + PTT 回應時間。預設看板 8 秒、單篇 3 秒；預設看板名稱是 `PTTBoard.defaultBoardName`（Stock）。
  - `changeBoard` 選到目前看板時只會 `unlockTargetArticle()`（單篇實況中才清空並重抓），其餘情況改 `currentBoard` 觸發清空；`BoardSwitchTests` 會擋。
  - 切換模式／看板的固定手續：`pollTask?.cancel()` → `queueManager.reset()` → `messages.removeAll()` → `startPolling()`。新增任何切換入口都要照做，否則舊任務的結果會混進來。`currentBoard` 的 `didSet` 會自動觸發 `onBoardChanged()`。
  - 所有設定以 `PTTMarquee_*` key 存在 `UserDefaults`（在各屬性 `didSet` 寫入、`init` 讀回並套預設值）。視窗位置由 `setFrameAutosaveName("PTTMarqueeMainWindow")` 記憶。
  - `messages` 上限 150 筆；`filteredMessages` 依 `filterType` 篩選供畫面使用。
- **`MessageQueueManager`**：以 `PTTMessage.dedupKey`（board + 文章路徑 + userId + 內容 + ipDateTime）去重的 FIFO，依 queue 長度動態調整推出間隔（0.25s～1.2s），透過 `onMessageEmit` callback 回寫 ViewModel。`seenKeys` 超過 10000 會整個清空。
- **`PTTCrawlerService`**（`actor`）：`URLSession` 帶 `over18=1` cookie 與瀏覽器 UA 抓 HTML，**停用 URLCache**（文章頁 `max-age=900` 會讓輪詢讀到 15 分鐘前的舊頁面）。PTT 網頁版（Cloudflare 後）常間歇性卡住 15～30 秒或回 525，請求逾時為 10 秒；`ChatViewModel.recordFetchFailure` 連續失敗 `fetchFailureThreshold`（3）次才顯示中文紅字，成功或暫停時清除——單次失敗屬正常，下一輪會自動重試。
- **`HTMLParser`**：純 regex 解析 PTT 網頁（文章列表、`r-list-sep` 置底公告切除、上一頁連結、推文、文章 meta）。PTT 網頁 markup 一變就會靜默回傳空陣列——抓不到推文時先懷疑這裡。
- **`FloatingPanelController`** 用 Combine 訂閱 `viewModel.$isLocked` / `$isAlwaysOnTop` 同步到 panel 的 `isMovable` / `level`；並註冊 global + local keyDown monitor，兩者都經 `handleKeyEvent` 處理 `⌘⇧L`（或 `⌘⇧P`）切換固定視窗位置（`isLocked`）；local monitor 另外在 panel 為 key window 時把按鍵經 `KeyCommand.from(...)` 轉成指令後交給 `viewModel.dispatch`。
- **按鍵路由**：`KeyCommand`（`ViewModels/KeyCommand.swift`）是按鍵到指令的純函式對應（P/F/B/L/T/S/?/X/Q、0/Home 置頂、$/G/End 置底、方向鍵、Enter、Esc、Y/N；有 ⌘⌃⌥ 修飾鍵或 `isTextInputActive == true` 時回傳 nil，所以設定頁的文字輸入框不會觸發單鍵快捷）。`ChatViewModel.dispatch` 是鍵盤與滑鼠點擊的單一入口：`isConfirmingQuit` 時只處理 Y/N/Esc；`screen == .chat` 時走 `handleChatCommand`（切換暫停/篩選/固定/視窗浮動/畫面、X 進入離開確認、Q 解除單篇、`.scrollToBottom` 先以 `queueManager.drainAll()` 把待播訊息一次加入 `messages`）；其他子畫面則透過 `keyCommands` publisher 轉給該畫面自己處理。`scrollToBottom`／`scrollToTop` 的實際捲動由 `ChatOverlayView` 訂閱 `keyCommands` 執行（`bottom_anchor`／`top_anchor`；置頂會把 `isUserScrolledUp` 設為 true 以暫停自動跟隨）。UI 用詞（置頂／置底／浮動／固定／鎖定）見 `.claude/rules/terminology.md`。
- **`TerminalScreen`**（`chat/settings/boards/help`）存於 `viewModel.screen`，`ChatOverlayView` 依此切換主畫面與子畫面（`SettingsScreenView`、`BoardListScreenView`、`HelpScreenView`）；`settingsStartsAtBoardInput` 讓設定畫面一開始把游標移到「前往看板」那一列（只移游標，不聚焦輸入框）。
- **`ChatRow`**：`ChatRow.build(from:showSeparators:)` 依 `articleUrl` 變化在留言間插入文章分隔線（單篇模式不插入）。`MessageQueueManager.groupedByArticle` 則在入隊前把同批推文依文章分組（組別依首次出現順序、組內保持原序），讓分隔線不會零碎重複。
- **`Views/Terminal/`**：`TerminalTheme`（色票與等寬字）、`TerminalBars`（藍底標題列、青底提示列與可點 `(K)` 區塊、離開確認列）、`TerminalSeparatorRow`（點擊開啟文章）、`BlockBar`（設定頁的方塊進度條）、三個子畫面。`TerminalMessageRow` 負責單則留言，右鍵選單提供鎖定單篇／開啟／複製。
- **`ChatOverlayView`** 的「往上捲暫停自動捲動」有兩個來源經 `handleBottomDistance` 寫入 `isUserScrolledUp`（>120pt 視為使用者往上捲、<30pt 視為回到底部）：`BottomAnchorDistanceKey` preference 量底部錨點距離，以及 `ScrollBottomDistanceObserver`（AppKit 觀察 NSScrollView 的 clip view bounds／frame 與 document view frame，算出內容底部距可視範圍底部的距離；內容或視窗大小改變時若原本貼底會維持貼底，回呼以 `DispatchQueue.main.async` 延後送出），並以 `isProgrammaticScrolling` 排除程式捲動造成的誤判；調整這段時注意閃爍問題。往上捲時顯示「▼ 有 N 則新留言 ($)置底」提示列，點擊走 `dispatch(.scrollToBottom)`。
- 單篇鎖定入口：留言右鍵選單呼叫 `lockToArticle(title:url:board:)`；設定畫面貼網址則走 `lockToArticle(byUrlString:)`，會正規化 `//`、`www.ptt.cc`、`/bbs/` 開頭的輸入。

## 慣例

- UI 文字、註解與 README 皆為繁體中文。
