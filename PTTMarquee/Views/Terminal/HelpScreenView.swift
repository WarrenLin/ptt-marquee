import SwiftUI

/// 【使用說明】子畫面：純文字分段，可捲動；↑↓ 逐段捲動，Q／Esc 返回。
struct HelpScreenView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var section: Int = 0

    private struct Section {
        let title: String
        let lines: [(key: String, text: String)]
    }

    private let sections: [Section] = [
        Section(title: "主畫面按鍵", lines: [
            ("P", "暫停／繼續推播"),
            ("F", "篩選：全部 → 只看推 → 只看噓"),
            ("B", "進入看板清單"),
            ("L", "固定／解除固定視窗位置（防誤拖曳）"),
            ("T", "視窗浮動在最上層／取消浮動"),
            ("S", "進入個人設定"),
            ("?", "進入使用說明"),
            ("X", "離開；出現「確定要離開嗎？(Y/N)」，按 Y 離開，N 或 Esc 取消"),
            ("Q", "單篇實況中：返回看板串流"),
            ("0／Home", "置頂：捲到最舊的留言（自動捲動會暫停）"),
            ("$／End／G", "置底：待播留言一次全部顯示並捲到最下面"),
            ("", "單鍵只在視窗是焦點時有效；提示列上的每個按鍵也都可以用滑鼠點。"),
        ]),
        Section(title: "子畫面按鍵（設定／看板清單／說明）", lines: [
            ("↑↓", "移動選項"),
            ("←→", "調整數值、切換開關"),
            ("Enter", "確定，或進入輸入欄"),
            ("Q／Esc", "返回聊天室"),
            ("", "滑鼠點選項等同移到該項並按 Enter；點方塊條的某一格會直接設成那個值。"),
            ("", "輸入欄輸入期間停用所有單鍵快捷鍵，按 Enter 送出、Esc 取消。"),
            ("", "在子畫面期間推文仍在背景抓取與排隊，返回後接著播放。"),
        ]),
        Section(title: "視窗操作", lines: [
            ("", "拖曳藍色標題列可以移動視窗；固定視窗位置後無法拖曳。"),
            ("⌘⇧L／⌘⇧P", "全域切換固定視窗位置，App 不在前景時也有效（需要在「系統設定 → 隱私權與安全性 → 輔助使用」允許 PTT Marquee）。"),
        ]),
        Section(title: "留言閱讀", lines: [
            ("", "新留言出現時自動捲到最底部。"),
            ("", "往上捲閱讀時自動捲動會暫停，並出現「▼ 有 N 則新留言 ($)置底」，點它或按 $／End／G 置底。"),
            ("", "看板模式下，換篇時會插入灰色分隔線 ─── [分類] 標題 ───，點分隔線會在瀏覽器開啟原文。"),
        ]),
        Section(title: "右鍵選單", lines: [
            ("", "在留言上按右鍵：鎖定此篇為實況聊天室、在瀏覽器開啟文章、複製文章網址、複製留言內文、複製使用者 ID。"),
            ("", "在視窗其他地方按右鍵：使用說明、切換看板、暫停推播、清空畫面留言、視窗浮動、固定視窗、結束應用程式。"),
        ]),
        Section(title: "單篇實況", lines: [
            ("", "適合球賽、大事件直播。在留言上按右鍵選「鎖定此篇為實況聊天室」，或在設定的「鎖定文章」貼上 PTT 文章網址後按 Enter。"),
            ("", "實況期間標題列顯示文章標題，只播這一篇的推文。"),
            ("", "按 Q（或點提示列的 (Q)返回看板），或在設定的「鎖定文章」那一列按 Enter，即可退出實況、回到看板串流。"),
        ]),
        Section(title: "設定自動保存", lines: [
            ("", "視窗浮動、固定位置、抓取間隔、透明度、字體大小、看板與視窗位置都會自動保存，下次開啟時沿用。"),
        ]),
    ]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: viewModel.fontSize * 0.8) {
                    ForEach(sections.indices, id: \.self) { index in
                        sectionView(sections[index])
                            .id(index)
                    }
                }
                .font(TerminalTheme.font(viewModel.fontSize))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: section) { index in
                proxy.scrollTo(index, anchor: .top)
            }
        }
        .onReceive(viewModel.keyCommands) { cmd in
            guard viewModel.screen == .help else { return }
            switch cmd {
            case .up: section = max(section - 1, 0)
            case .down: section = min(section + 1, sections.count - 1)
            case .back, .escape: viewModel.screen = .chat
            default: break
            }
        }
    }

    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("【\(section.title)】")
                .font(TerminalTheme.font(viewModel.fontSize, bold: true))
                .foregroundColor(TerminalTheme.userId)
            ForEach(section.lines.indices, id: \.self) { i in
                let line = section.lines[i]
                Group {
                    if line.key.isEmpty {
                        Text("  " + line.text)
                            .foregroundColor(TerminalTheme.content)
                    } else {
                        (Text("  ")
                         + Text(line.key).foregroundColor(TerminalTheme.push).bold()
                         + Text("  " + line.text).foregroundColor(TerminalTheme.content))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
