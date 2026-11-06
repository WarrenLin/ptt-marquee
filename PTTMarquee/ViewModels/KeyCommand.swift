import AppKit

public enum KeyCommand: Equatable {
    case pause, filter, boards, lock, top, settings, help, quit, back, scrollToBottom, scrollToTop
    case up, down, left, right, enter, escape, yes, no

    /// Maps a key event to a command. Returns nil for modified keys (⌘/⌃/⌥) and while a text field is active.
    /// Shift is allowed (needed for "?"); "/" with shift is also accepted as help.
    public static func from(characters: String?, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isTextInputActive: Bool) -> KeyCommand? {
        if isTextInputActive { return nil }
        if !modifiers.isDisjoint(with: [.command, .control, .option]) { return nil }

        switch keyCode {
        case 119: return .scrollToBottom
        case 115: return .scrollToTop
        case 126: return .up
        case 125: return .down
        case 123: return .left
        case 124: return .right
        case 36, 76: return .enter
        case 53: return .escape
        default: break
        }

        guard let c = characters?.lowercased(), c.count == 1 else { return nil }
        switch c {
        case "p": return .pause
        case "f": return .filter
        case "b": return .boards
        case "l": return .lock
        case "t": return .top
        case "s": return .settings
        case "?": return .help
        case "/": return modifiers.contains(.shift) ? .help : nil
        case "x": return .quit
        case "q": return .back
        case "g", "$": return .scrollToBottom
        case "0": return .scrollToTop
        case "y": return .yes
        case "n": return .no
        default: return nil
        }
    }
}
