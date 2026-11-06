import SwiftUI

/// 【個人設定】子畫面：↑↓ 移動、←→ 調整、Enter 確定或進入輸入、Q／Esc 返回。
/// 滑鼠點任一行等同移到該行並按 Enter；點方塊條某一格直接跳到該值。
struct SettingsScreenView: View {
    @ObservedObject var viewModel: ChatViewModel

    enum Row: Int, CaseIterable {
        case alwaysOnTop, locked, boardInterval, articleInterval, opacity, fontSize
        case boardInput, articleInput, clear, quit

        /// 標籤欄文字；清空／結束兩列是整行文字，不佔標籤欄。
        var title: String? {
            switch self {
            case .alwaysOnTop: return "視窗浮動"
            case .locked: return "固定視窗位置"
            case .boardInterval: return "看板抓取間隔"
            case .articleInterval: return "單篇抓取間隔"
            case .opacity: return "背景透明度"
            case .fontSize: return "字體大小"
            case .boardInput: return "前往看板："
            case .articleInput: return "鎖定文章："
            case .clear, .quit: return nil
            }
        }
    }

    /// 標籤欄最多容納的中文字數（欄寬 = 字級 × (此值 + 1 字間隔)）。
    static let maxLabelChars = 6

    enum Field: Hashable {
        case board, url
    }

    @State private var cursor: Row = .alwaysOnTop
    @State private var boardInput = ""
    @State private var urlInput = ""
    @FocusState private var focusedField: Field?

    private var fontSize: CGFloat { viewModel.fontSize }
    private var labelWidth: CGFloat { fontSize * CGFloat(Self.maxLabelChars + 1) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Row.allCases, id: \.self) { row in
                        rowView(row)
                            .id(row)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: cursor) { row in
                proxy.scrollTo(row)
            }
        }
        .onAppear {
            if viewModel.settingsStartsAtBoardInput {
                cursor = .boardInput
                viewModel.settingsStartsAtBoardInput = false
            }
        }
        .onDisappear {
            viewModel.isTextInputActive = false
        }
        .onChange(of: focusedField) { field in
            viewModel.isTextInputActive = field != nil
            // 直接點輸入欄取得焦點時，游標也移到該列
            if field == .board { cursor = .boardInput }
            if field == .url { cursor = .articleInput }
        }
        .onReceive(viewModel.keyCommands) { cmd in
            guard viewModel.screen == .settings else { return }
            // 輸入期間鍵盤事件不會經過 dispatch，能進來的只有滑鼠點提示列：
            // 點 (Enter) 等同送出，點其他按鍵先結束輸入再照常處理。
            if let field = focusedField {
                if cmd == .enter {
                    field == .board ? submitBoard() : submitUrl()
                    return
                }
                focusedField = nil
            }
            handle(cmd)
        }
    }

    // MARK: - 按鍵處理

    private func handle(_ cmd: KeyCommand) {
        switch cmd {
        case .up: moveCursor(-1)
        case .down: moveCursor(1)
        case .left: adjust(cursor, direction: -1)
        case .right: adjust(cursor, direction: 1)
        case .enter: activate(cursor)
        case .back, .escape: viewModel.screen = .chat
        default: break
        }
    }

    private func moveCursor(_ delta: Int) {
        let count = Row.allCases.count
        let next = (cursor.rawValue + delta + count) % count
        cursor = Row(rawValue: next) ?? .alwaysOnTop
    }

    private func adjust(_ row: Row, direction: Int) {
        switch row {
        case .alwaysOnTop: viewModel.isAlwaysOnTop.toggle()
        case .locked: viewModel.isLocked.toggle()
        case .boardInterval:
            viewModel.boardRefreshInterval = BlockBar.boardInterval.stepped(viewModel.boardRefreshInterval, direction: direction)
        case .articleInterval:
            viewModel.articleRefreshInterval = BlockBar.articleInterval.stepped(viewModel.articleRefreshInterval, direction: direction)
        case .opacity:
            viewModel.windowOpacity = BlockBar.opacity.stepped(viewModel.windowOpacity, direction: direction)
        case .fontSize:
            viewModel.fontSize = CGFloat(BlockBar.fontSize.stepped(Double(viewModel.fontSize), direction: direction))
        default: break
        }
    }

    private func activate(_ row: Row) {
        guard !viewModel.isConfirmingQuit else { return }
        // 點其他列時先結束輸入，避免鍵盤焦點留在輸入欄（輸入列會在下方重新聚焦）
        focusedField = nil
        cursor = row
        switch row {
        case .alwaysOnTop, .locked: adjust(row, direction: 1)
        case .boardInterval, .articleInterval, .opacity, .fontSize: break
        case .boardInput: focusedField = .board
        case .articleInput:
            if viewModel.targetArticle != nil {
                viewModel.unlockTargetArticle()
            } else {
                focusedField = .url
            }
        case .clear: viewModel.clearMessages()
        case .quit: viewModel.isConfirmingQuit = true
        }
    }

    private func setBar(_ row: Row, cell: Int) {
        guard !viewModel.isConfirmingQuit else { return }
        focusedField = nil
        cursor = row
        switch row {
        case .boardInterval: viewModel.boardRefreshInterval = BlockBar.boardInterval.value(forCell: cell)
        case .articleInterval: viewModel.articleRefreshInterval = BlockBar.articleInterval.value(forCell: cell)
        case .opacity: viewModel.windowOpacity = BlockBar.opacity.value(forCell: cell)
        case .fontSize: viewModel.fontSize = CGFloat(BlockBar.fontSize.value(forCell: cell))
        default: break
        }
    }

    // MARK: - 送出輸入

    private func submitBoard() {
        let name = boardInput.trimmingCharacters(in: .whitespacesAndNewlines)
        // 空白：不動作，留在原畫面
        guard !name.isEmpty else { return }
        // 含非法字元：提示列顯示紅字錯誤，保留輸入與焦點讓使用者修改
        guard name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            viewModel.errorMessage = "無效的看板名稱"
            return
        }
        if let preset = PTTBoard.presetBoards.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            viewModel.changeBoard(preset)
        } else {
            viewModel.setCustomBoard(name: name)
        }
        finishInput()
    }

    private func submitUrl() {
        let text = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // 先清掉舊錯誤，才能用 errorMessage 判斷這次是否成功
        viewModel.errorMessage = nil
        viewModel.lockToArticle(byUrlString: text)
        guard viewModel.errorMessage == nil else {
            // 無效網址：紅字錯誤已由 viewModel 設定，保留輸入與焦點讓使用者修改
            return
        }
        finishInput()
    }

    private func finishInput() {
        boardInput = ""
        urlInput = ""
        focusedField = nil
        viewModel.isTextInputActive = false
        viewModel.screen = .chat
    }

    // MARK: - 列

    private func rowView(_ row: Row) -> some View {
        let selected = cursor == row
        return HStack(spacing: 0) {
            Text(selected ? "▶ " : "  ")
            content(for: row, selected: selected)
            Spacer(minLength: 0)
        }
        .font(TerminalTheme.font(fontSize))
        .foregroundColor(selected ? TerminalTheme.highlightFg : baseColor(row))
        .lineLimit(1)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? TerminalTheme.highlightBg : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { activate(row) }
    }

    private func baseColor(_ row: Row) -> Color {
        switch row {
        case .clear: return TerminalTheme.userId
        case .quit: return TerminalTheme.error
        default: return TerminalTheme.push
        }
    }

    @ViewBuilder
    private func content(for row: Row, selected: Bool) -> some View {
        switch row {
        case .alwaysOnTop:
            label(row.title!)
            Text(viewModel.isAlwaysOnTop ? "[ON ]" : "[OFF]")
        case .locked:
            label(row.title!)
            Text(viewModel.isLocked ? "[ON ]" : "[OFF]")
        case .boardInterval:
            barRow(row.title!, row, BlockBar.boardInterval, value: viewModel.boardRefreshInterval,
                   valueText: String(format: " %2d 秒", Int(viewModel.boardRefreshInterval)))
        case .articleInterval:
            barRow(row.title!, row, BlockBar.articleInterval, value: viewModel.articleRefreshInterval,
                   valueText: String(format: " %2d 秒", Int(viewModel.articleRefreshInterval)))
        case .opacity:
            barRow(row.title!, row, BlockBar.opacity, value: viewModel.windowOpacity,
                   valueText: String(format: " %3d%%", Int((viewModel.windowOpacity * 100).rounded())))
        case .fontSize:
            barRow(row.title!, row, BlockBar.fontSize, value: Double(viewModel.fontSize),
                   valueText: String(format: " %2dpt", Int(viewModel.fontSize)))
        case .boardInput:
            label(row.title!)
            inputField(text: $boardInput, placeholder: "看板英文名稱", field: .board, selected: selected, onSubmit: submitBoard)
        case .articleInput:
            if let target = viewModel.targetArticle {
                Text("目前：\(target.title)")
                    .truncationMode(.tail)
                    .layoutPriority(-1)
                Text("  (Enter)退出實況")
                    .fixedSize()
            } else {
                label(row.title!)
                inputField(text: $urlInput, placeholder: "貼上 PTT 文章網址", field: .url, selected: selected, onSubmit: submitUrl)
            }
        case .clear:
            Text("清空畫面留言")
        case .quit:
            Text("結束應用程式")
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .frame(width: labelWidth, alignment: .leading)
    }

    /// 標籤 + 方塊條 + 數值；視窗太窄（例如 280pt 配 17pt 字）放不下一行時，方塊條與數值折到第二行。
    private func barRow(_ title: String, _ row: Row, _ blockBar: BlockBar, value: Double, valueText: String) -> some View {
        let barAndValue = HStack(spacing: 0) {
            bar(row, blockBar, value: value)
            Text(valueText).fixedSize()
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                label(title)
                barAndValue
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                barAndValue
            }
        }
    }

    private func bar(_ row: Row, _ blockBar: BlockBar, value: Double) -> some View {
        let filled = blockBar.filledCells(for: value)
        return HStack(spacing: 0) {
            ForEach(0..<blockBar.cells, id: \.self) { i in
                Text(i < filled ? "■" : "□")
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded { setBar(row, cell: i) })
            }
        }
        .fixedSize()
    }

    private func inputField(text: Binding<String>, placeholder: String, field: Field, selected: Bool, onSubmit: @escaping () -> Void) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(TerminalTheme.font(fontSize))
            .foregroundColor(selected ? TerminalTheme.highlightFg : TerminalTheme.userId)
            .focused($focusedField, equals: field)
            .onSubmit(onSubmit)
            .onExitCommand { focusedField = nil }
            .padding(.bottom, 1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(selected ? TerminalTheme.highlightFg : TerminalTheme.content)
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
    }
}
