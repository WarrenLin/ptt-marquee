import SwiftUI
import AppKit

/// 看板模式的文章分隔線：`─── [問卦] 標題 ────────`，點擊在瀏覽器開啟原文。
/// PTT 文章標題本身已含 `[分類]`，所以不再額外加括號。
struct TerminalSeparatorRow: View {
    let title: String
    let url: URL?
    let fontSize: CGFloat

    private var line: String {
        "─── \(title) " + String(repeating: "─", count: 300)
    }

    var body: some View {
        // 以單一字元撐出行高，整條線疊在上面並裁切到視窗寬度，避免出現「…」。
        Text("─中") // 含中文字，行高才會與 PingFang 退回字型一致
            .font(TerminalTheme.font(fontSize))
            .foregroundColor(.clear)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                Text(line)
                    .font(TerminalTheme.font(fontSize))
                    .foregroundColor(TerminalTheme.separator)
                    .lineLimit(1)
                    .fixedSize()
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if let url { NSWorkspace.shared.open(url) }
            }
            .help(url == nil ? "" : "點擊在瀏覽器開啟原文")
    }
}
