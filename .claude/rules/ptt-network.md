---
paths:
  - "PTTMarquee/Services/**"
  - "PTTMarquee/ViewModels/ChatViewModel.swift"
---

# PTT 網路特性

- www.ptt.cc（經 Cloudflare）實測約每兩分鐘卡住一次：15～30 秒沒有回應，或回 HTTP 525。關掉 app 量測一樣會發生，所以不是本工具請求太頻繁造成的。
- 請求逾時維持 10 秒。PTT 卡住時常常完全沒有回應，拉長逾時沒有幫助，只會拖慢輪詢。
- 錯誤顯示：`recordFetchFailure` 連續失敗 `fetchFailureThreshold`（3）次才顯示中文紅字；`recordFetchSuccess` 或暫停時清除。單次 timeout 不是 bug，不要為它加重試迴圈或改逾時。
- 只有看板列表頁失敗會顯示錯誤；各篇文章抓取失敗會被靜默略過（`fetchPushes` 用 `try?`）。
- 抓不到任何推文卻沒有錯誤時，先懷疑 `HTMLParser` 的 regex：PTT 改版會讓它靜默回傳空陣列。
- 診斷時用 curl 帶與 app 相同的 `Cookie: over18=1` 與 UA，量 `time_starttransfer` 至少 3 分鐘再下結論。
