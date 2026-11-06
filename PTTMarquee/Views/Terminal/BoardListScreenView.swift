import SwiftUI

/// 【熱門看板】子畫面：PTT 看板列表樣式，● 標記目前看板；最後一行「自訂看板…」切到設定畫面。
struct BoardListScreenView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var cursor: Int = 0

    private let boards = PTTBoard.presetBoards
    /// 看板列 + 最後一行「自訂看板…」
    private var rowCount: Int { boards.count + 1 }
    private var customRowIndex: Int { boards.count }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(0..<rowCount, id: \.self) { index in
                        rowView(index)
                            .id(index)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: cursor) { index in
                proxy.scrollTo(index)
            }
        }
        .onAppear {
            cursor = boards.firstIndex(where: { $0.name == viewModel.currentBoard.name }) ?? 0
        }
        .onReceive(viewModel.keyCommands) { cmd in
            guard viewModel.screen == .boards else { return }
            switch cmd {
            case .up: cursor = (cursor - 1 + rowCount) % rowCount
            case .down: cursor = (cursor + 1) % rowCount
            case .enter: activate(cursor)
            case .back, .escape: viewModel.screen = .chat
            default: break
            }
        }
    }

    private func activate(_ index: Int) {
        guard !viewModel.isConfirmingQuit else { return }
        cursor = index
        if index == customRowIndex {
            viewModel.settingsStartsAtBoardInput = true
            viewModel.screen = .settings
        } else if boards.indices.contains(index) {
            viewModel.changeBoard(boards[index])
            viewModel.screen = .chat
        }
    }

    private func rowView(_ index: Int) -> some View {
        let selected = cursor == index
        return Text(lineText(index))
            .font(TerminalTheme.font(viewModel.fontSize))
            .foregroundColor(selected ? TerminalTheme.highlightFg : TerminalTheme.push)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? TerminalTheme.highlightBg : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { activate(index) }
    }

    /// 例如 `● 1  Gossiping      八卦板`；非目前看板以空白取代 `●`。
    private func lineText(_ index: Int) -> String {
        guard boards.indices.contains(index) else { return "  自訂看板…" }
        let board = boards[index]
        let mark = board.name == viewModel.currentBoard.name ? "●" : " "
        let number = String(index + 1).leftPadded(to: 2)
        let name = board.name.padding(toLength: 14, withPad: " ", startingAt: 0)
        return "\(mark)\(number)  \(name)\(shortName(board))"
    }

    /// 「八卦板 (Gossiping)」→「八卦板」
    private func shortName(_ board: PTTBoard) -> String {
        if let range = board.displayName.range(of: " (") {
            return String(board.displayName[..<range.lowerBound])
        }
        return board.displayName
    }
}

private extension String {
    func leftPadded(to length: Int) -> String {
        count >= length ? self : String(repeating: " ", count: length - count) + self
    }
}
