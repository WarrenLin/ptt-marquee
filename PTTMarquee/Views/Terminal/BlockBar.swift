import Foundation

/// Pure value logic for the terminal-style block bar (■■■□□).
struct BlockBar {
    let range: ClosedRange<Double>
    let step: Double
    var cells: Int = 8

    init(range: ClosedRange<Double>, step: Double, cells: Int = 8) {
        self.range = range
        self.step = step
        self.cells = cells
    }

    /// Snap to the nearest step offset from lowerBound, then clamp to range.
    private func snap(_ value: Double) -> Double {
        let lower = range.lowerBound
        let snapped = lower + ((value - lower) / step).rounded() * step
        // Strip floating drift (e.g. 0.8999999 -> 0.9).
        let cleaned = (snapped * 1_000_000).rounded() / 1_000_000
        return min(max(cleaned, range.lowerBound), range.upperBound)
    }

    func filledCells(for value: Double) -> Int {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        let proportion = (value - range.lowerBound) / span
        return min(max(Int((proportion * Double(cells)).rounded()), 0), cells)
    }

    func stepped(_ value: Double, direction: Int) -> Double {
        snap(value + Double(direction) * step)
    }

    func value(forCell index: Int) -> Double {
        guard cells > 1 else { return range.upperBound }
        let i = min(max(index, 0), cells - 1)
        let span = range.upperBound - range.lowerBound
        return snap(range.lowerBound + Double(i) / Double(cells - 1) * span)
    }

    static let boardInterval = BlockBar(range: 5...30, step: 1)
    static let articleInterval = BlockBar(range: 2...15, step: 1)
    static let opacity = BlockBar(range: 0.25...1.0, step: 0.05)
    static let fontSize = BlockBar(range: 11...18, step: 1)
}
