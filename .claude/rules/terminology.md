# UI 用詞（繁體中文）

這幾個詞曾經混用、讓使用者誤會功能「沒作用」，新增或修改 UI 文字時必須遵守：

| 用詞 | 意思 | 程式對應 | 按鍵 |
|---|---|---|---|
| 置頂 | 訊息列表捲到最上面（最舊的留言），自動捲動暫停 | `KeyCommand.scrollToTop` | `0` / Home |
| 置底 | 待播隊列一次全部顯示並捲到最下面 | `KeyCommand.scrollToBottom` + `queueManager.drainAll()` | `$` / End / `G` |
| 浮動 | 視窗永遠在所有視窗最上層 | `isAlwaysOnTop`（`.floating` level） | `T` |
| 固定 | 視窗位置固定、不能拖曳 | `isLocked`（`panel.isMovable = false`） | `L`、全域 ⌘⇧L/⌘⇧P |
| 鎖定 | **只**用於「鎖定此篇為實況聊天室」（單篇實況） | `lockToArticle(...)` / `targetArticle` | 右鍵選單 |

- 不要再用「置頂」描述視窗層級，也不要用「鎖定」描述視窗位置。
- 同一功能在提示列、設定頁、說明頁、右鍵選單、README 要用同一個詞。
- UI 文字、註解、文件一律繁體中文；不要在選單或提示列放 emoji。
