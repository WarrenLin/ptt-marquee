// 產生 app 圖示（telnet 風格：藍標題列 + 大「推」字 + 底線游標 + 青提示列）。
// 用法：swift scripts/AppIcon.swift <輸出 PNG 路徑>   （輸出 1024pt，Retina 下為 2048px）
// 通常透過 scripts/make-app-icon.sh 呼叫，它會再縮成各尺寸放進 AppIcon.appiconset。
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "AppIcon-1024.png"

// macOS Big Sur 圖示格線：1024 畫布、824 主體、圓角約 185
let S: CGFloat = 1024
let body = NSRect(x: 100, y: 100, width: S - 200, height: S - 200)
let radius: CGFloat = 185

func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
}
// 與 TerminalTheme 相同的 ANSI 色
let black = hex(0x000000), blue = hex(0x0000a8), cyan = hex(0x00a8a8), white = hex(0xffffff)

let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
black.setFill()
NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).fill()
ctx.restoreGState()

NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius).addClip()
black.setFill(); body.fill()
blue.setFill(); NSRect(x: body.minX, y: body.maxY - 110, width: body.width, height: 110).fill()
cyan.setFill(); NSRect(x: body.minX, y: body.minY, width: body.width, height: 90).fill()

let font = NSFont(name: "PingFangTC-Semibold", size: 470) ?? NSFont.systemFont(ofSize: 470, weight: .bold)
NSAttributedString(string: "推", attributes: [.font: font, .foregroundColor: white])
    .draw(at: NSPoint(x: body.minX + 95, y: body.minY + 150))
white.setFill(); NSRect(x: body.minX + 600, y: body.minY + 190, width: 120, height: 34).fill() // 底線游標

NSColor.white.withAlphaComponent(0.10).setStroke()
let border = NSBezierPath(roundedRect: body.insetBy(dx: 2, dy: 2), xRadius: radius - 2, yRadius: radius - 2)
border.lineWidth = 4; border.stroke()
img.unlockFocus()

let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print(out)
