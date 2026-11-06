import AppKit
import SwiftUI
import Combine

public final class FloatingPanel: NSPanel {
    public override var canBecomeKey: Bool {
        return true
    }

    public override var canBecomeMain: Bool {
        return true
    }
}

@MainActor
public final class FloatingPanelController: ObservableObject {
    public static let shared = FloatingPanelController()

    private var panel: FloatingPanel?
    public let viewModel = ChatViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?

    private init() {
        setupBindings()
        setupHotkeys()
    }

    public func showWindow() {
        if panel == nil {
            createPanel()
        }
        panel?.orderFrontRegardless()
    }

    private func createPanel() {
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let initialWidth: CGFloat = 360
        let initialHeight: CGFloat = 520
        let initialX = screenRect.maxX - initialWidth - 24
        let initialY = screenRect.maxY - initialHeight - 40

        let initialFrame = NSRect(x: initialX, y: initialY, width: initialWidth, height: initialHeight)

        let newPanel = FloatingPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newPanel.isFloatingPanel = true
        newPanel.level = viewModel.isAlwaysOnTop ? .floating : .normal
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.backgroundColor = .clear
        newPanel.isOpaque = false
        newPanel.hasShadow = true
        newPanel.isReleasedWhenClosed = false
        newPanel.hidesOnDeactivate = false
        newPanel.minSize = NSSize(width: 280, height: 220)
        newPanel.titleVisibility = .hidden
        newPanel.titlebarAppearsTransparent = true

        // 自動儲存視窗在桌面上的大小與擺放位置
        newPanel.setFrameAutosaveName("PTTMarqueeMainWindow")

        let contentView = ChatOverlayView(viewModel: viewModel)
        newPanel.contentView = NSHostingView(rootView: contentView)

        self.panel = newPanel
    }

    private func setupBindings() {
        viewModel.$isLocked
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLocked in
                self?.panel?.isMovable = !isLocked
            }
            .store(in: &cancellables)

        viewModel.$isAlwaysOnTop
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAlwaysOnTop in
                guard let self = self, let panel = self.panel else { return }
                panel.level = isAlwaysOnTop ? .floating : .normal
                if isAlwaysOnTop {
                    panel.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)
    }

    private func setupHotkeys() {
        let handleKeyEvent: (NSEvent) -> Void = { [weak self] event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let char = event.charactersIgnoringModifiers?.lowercased()
            if flags == [.command, .shift] && (char == "l" || char == "p") {
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        self.viewModel.isLocked.toggle()
                    }
                }
            }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            handleKeyEvent(event)
            guard let self = self, self.panel?.isKeyWindow == true else { return event }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard let cmd = KeyCommand.from(
                characters: event.charactersIgnoringModifiers,
                keyCode: event.keyCode,
                modifiers: flags,
                isTextInputActive: self.viewModel.isTextInputActive
            ) else { return event }
            self.viewModel.dispatch(cmd)
            return nil
        }
    }
}
