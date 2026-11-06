import SwiftUI

enum TerminalTheme {
    private static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xff) / 255,
              green: Double((v >> 8) & 0xff) / 255,
              blue: Double(v & 0xff) / 255)
    }

    static let push = hex(0xffffff)
    static let boo = hex(0xff5555)
    static let arrow = hex(0xa80000)
    static let userId = hex(0xffff55)
    static let content = hex(0xa8a800)
    static let time = hex(0x808080)
    static let titleBarBg = hex(0x0000a8)
    static let titleBarFg = hex(0xffffff)
    static let hintBarBg = hex(0x00a8a8)
    static let hintBarFg = hex(0x000000)
    static let keyChipBg = hex(0xa8a8a8)
    static let highlightBg = hex(0x00a8a8)
    static let highlightFg = hex(0x000000)
    static let error = hex(0xff5555)
    static let separator = hex(0x808080)

    static func color(for tag: PushTag) -> Color {
        switch tag {
        case .push: return push
        case .boo: return boo
        case .arrow: return arrow
        case .other: return time
        }
    }

    static func font(_ size: CGFloat, bold: Bool = false) -> Font {
        let f = Font.custom("Menlo", size: size)
        return bold ? f.bold() : f
    }
}
