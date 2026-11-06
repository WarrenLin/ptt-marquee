import SwiftUI
import AppKit

@main
struct PTTMarqueeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        FloatingPanelController.shared.showWindow()
    }

    // 關鍵修復：常駐浮動小工具不可因選單/子視窗關閉而自動結束
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        FloatingPanelController.shared.showWindow()
        return true
    }
}
