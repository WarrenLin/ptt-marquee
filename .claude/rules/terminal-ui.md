---
paths:
  - "PTTMarquee/Views/**"
  - "PTTMarquee/ViewModels/**"
  - "PTTMarquee/WindowController.swift"
---

# 終端機 UI 與按鍵規範

設計依據：`docs/superpowers/specs/2026-11-06-telnet-style-design.md`。

## 外觀
- 只用 `TerminalTheme` 的 ANSI 色與 `TerminalTheme.font`（Menlo）；不要用 SF Symbols、圓角卡片、膠囊、原生 popover／sheet（右鍵選單除外）。
- 透明度只套在黑色背景，文字一律不透明。
- 只能用 macOS 13 的 API（例如不能用 `onKeyPress`）。
- 視窗最小寬度 280pt：提示列可以折行，但不能截斷或換成圖示；改版面後要在 280pt 檢查。
- 設定頁標籤欄寬 = 字級 × (`SettingsScreenView.maxLabelChars` + 1)，標籤最多 6 個中文字；`SettingsLabelTests` 會擋。新增設定列時把文字放在 `Row.title`。

## 新增或修改按鍵時，全部都要改
1. `KeyCommand.from(...)` 的對應，加上 `KeyCommandTests` 或對應測試。
2. `ChatViewModel.dispatch` / `handleChatCommand`（聊天畫面），或子畫面的 `.onReceive(viewModel.keyCommands)`。
3. 提示列的 `HintItem`（`ChatOverlayView`）——每個功能都必須能用滑鼠點到。
4. `HelpScreenView` 的說明文字與 README 的快捷鍵表。

## 路由不變式
- 鍵盤（local monitor）與滑鼠點提示列都只能走 `viewModel.dispatch(_:)`；`ChatViewModel` 不可訂閱自己的 `keyCommands`（會造成子畫面與聊天畫面重複處理同一個鍵）。
- 文字輸入期間（`isTextInputActive == true`）所有單鍵快捷鍵停用；任何離開輸入的路徑都要把它設回 false。
- 帶 ⌘⌃⌥ 的按鍵不得被當成單鍵吃掉。
