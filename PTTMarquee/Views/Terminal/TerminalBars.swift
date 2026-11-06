import SwiftUI
import AppKit

/// 支援無邊框視窗平滑拖曳的輔助 View
public struct WindowDragArea: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragNSView {
        return DragNSView()
    }

    public func updateNSView(_ nsView: DragNSView, context: Context) {}

    public final class DragNSView: NSView {
        public override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// 藍底標題列：左側標題、右側狀態；可拖曳時疊上 WindowDragArea 作為視窗把手。
struct TerminalTitleBar: View {
    let title: String
    let status: String
    let isDraggable: Bool
    var fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(TerminalTheme.font(fontSize, bold: true))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if !status.isEmpty {
                Text(status)
                    .font(TerminalTheme.font(fontSize))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .foregroundColor(TerminalTheme.titleBarFg)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(TerminalTheme.titleBarBg)
        .overlay {
            if isDraggable {
                WindowDragArea()
            }
        }
    }
}

/// 提示列中的一個可點按鍵，例如 `(P)暫停`。
struct HintItem: Identifiable {
    let key: String
    let label: String
    let command: KeyCommand

    var id: String { key + label }
}

/// 青底提示列：模式名稱 + 一排可點的按鍵提示，寬度不夠時自動換行。
struct TerminalHintBar: View {
    let modeLabel: String
    let hints: [HintItem]
    var fontSize: CGFloat = 12
    let onTap: (KeyCommand) -> Void

    var body: some View {
        FlowLayout(spacing: 3, lineSpacing: 2) {
            Text(modeLabel)
                .font(TerminalTheme.font(fontSize, bold: true))
                .foregroundColor(TerminalTheme.hintBarFg)
                .fixedSize()
            ForEach(hints) { item in
                HintChip(item: item, fontSize: fontSize)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(item.command) }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TerminalTheme.hintBarBg)
    }
}

private struct HintChip: View {
    let item: HintItem
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Text("(\(item.key))")
                .background(TerminalTheme.keyChipBg)
            Text(item.label)
        }
        .font(TerminalTheme.font(fontSize))
        .foregroundColor(TerminalTheme.hintBarFg)
        .fixedSize()
    }
}

/// 離開確認列：`確定要離開嗎？(Y/N)`，Y、N 可點。
struct TerminalQuitConfirmBar: View {
    var fontSize: CGFloat = 12
    var onTap: (KeyCommand) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("確定要離開嗎？(")
            Text("Y")
                .background(TerminalTheme.keyChipBg)
                .contentShape(Rectangle())
                .onTapGesture { onTap(.yes) }
            Text("/")
            Text("N")
                .background(TerminalTheme.keyChipBg)
                .contentShape(Rectangle())
                .onTapGesture { onTap(.no) }
            Text(")")
            Spacer(minLength: 0)
        }
        .font(TerminalTheme.font(fontSize, bold: true))
        .foregroundColor(TerminalTheme.hintBarFg)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TerminalTheme.hintBarBg)
    }
}

/// 由左而右排列子 View，寬度不夠時換到下一行。
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 2

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(for subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var result: [Line] = []
        var current = Line()
        for (i, view) in subviews.enumerated() {
            let size = view.sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if !current.indices.isEmpty && needed > maxWidth {
                result.append(current)
                current = Line()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(i)
        }
        if !current.indices.isEmpty { result.append(current) }
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let ls = lines(for: subviews, maxWidth: maxWidth)
        let width = ls.map(\.width).max() ?? 0
        let height = ls.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(ls.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ls = lines(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for line in ls {
            var x = bounds.minX
            for i in line.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }
}
