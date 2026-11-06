# 驗證方式與注意事項

## 基本
- 改完跑完整測試：`xcodebuild -project PTTMarquee.xcodeproj -scheme PTTMarquee -destination 'platform=macOS' test`。新增/刪除檔案前先 `xcodegen generate`。
- Git repo（公開，github.com/WarrenLin/ptt-marquee）：只在使用者要求時 commit／push；公開前確認沒有個人路徑、帳號或密鑰。
- SourceKit 常回報「Cannot find type … in scope」或「No such module 'XCTest'」，那是索引雜訊；以 `xcodebuild` 結果為準。

## 不要用 GUI 自動化送按鍵或點擊
曾經用 osascript／cliclick 測試時，按鍵與點擊漏到使用者的瀏覽器。另外 `activate` 後浮動視窗**不會**變成 key window，單鍵也收不到。
需要看畫面時改用以下方式：
- **只啟動＋截圖**：`./run.sh` 後以 CoreGraphics 找視窗編號（owner name 是 `PTT Marquee`），再 `screencapture -x -o -l <windowNumber>`。
- **看子畫面（設定、說明等）**：寫一個暫時的 XCTest，在測試宿主裡設定 `FloatingPanelController.shared.viewModel.screen = .settings`、調整 `panel.setFrame` 寬度，寫出 ready 標記檔後停留幾秒；由 shell 背景執行測試、等標記檔出現再 `screencapture`。測試行程本身沒有螢幕錄製權限。用完刪掉暫時測試並 `xcodegen generate`。
- `ImageRenderer` 畫不出 `ScrollView` 內容（會全黑），不要用它驗證子畫面。

## UserDefaults（domain `com.pttmarquee.PTTMarquee`）
- 測試與 app 共用真實設定。改設定做實驗前先 `defaults read` 記下原值，結束後還原。
- **app 在執行時不要 `defaults write`**：app 結束時會把記憶體中的舊值寫回去。先確認 `pgrep -x PTTMarquee` 沒有輸出再寫。
- 視窗位置存在 `NSWindow Frame PTTMarqueeMainWindow`；測試若改了視窗大小要還原或刪掉這個 key。
