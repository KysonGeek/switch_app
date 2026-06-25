import AppKit
import SwiftUI

/// Borderless panel that is allowed to become key so it can receive key presses.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Owns the overlay window, builds the keyboard on demand, and routes key/click selection.
final class OverlayController: NSObject {
    private var panel: KeyablePanel?
    private let model = OverlayModel()
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    var isVisible: Bool { panel?.isVisible ?? false }

    override init() {
        super.init()
        model.onSelect = { [weak self] window in
            self?.select(window)
        }
        model.onClose = { [weak self] window in
            self?.closeWindow(window)
        }
    }

    // MARK: Toggle

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard WindowManager.ensureAccessibility(prompt: false) else {
            presentPermissionAlert()
            return
        }

        let windows = WindowManager.allWindows()
        model.rows = KeyboardLayout.build(with: windows)
        model.windowCount = windows.count

        let panel = panel ?? makePanel()
        self.panel = panel

        // Size to fit the SwiftUI content, then center on the active screen.
        if let host = panel.contentView {
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            panel.setContentSize(size)
        }
        centerOnMouseScreen(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        installClickMonitor()
    }

    /// Show the overlay populated with mock data (for UI previews only, skips Accessibility).
    func showDemo() {
        let windows = WindowManager.demoWindows()
        model.rows = KeyboardLayout.build(with: windows)
        model.windowCount = windows.count
        let panel = panel ?? makePanel()
        self.panel = panel
        if let host = panel.contentView {
            host.layoutSubtreeIfNeeded()
            panel.setContentSize(host.fittingSize)
        }
        centerOnMouseScreen(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeKeyMonitor()
        removeClickMonitor()
        panel?.orderOut(nil)
    }

    // MARK: Panel construction

    private func makePanel() -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let host = NSHostingView(rootView: KeyboardView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = true
        panel.contentView = host
        return panel
    }

    private func centerOnMouseScreen(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.frame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2)
        panel.setFrameOrigin(origin)
    }

    // MARK: Keyboard handling

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
    }

    // MARK: Click-outside handling

    /// A mouse-down anywhere outside our app dismisses the overlay.
    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeClickMonitor() {
        if let m = clickMonitor {
            NSEvent.removeMonitor(m)
            clickMonitor = nil
        }
    }

    /// Returns true if the event was consumed.
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Escape
            hide()
            return true
        }
        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let first = chars.first else { return false }

        let key = String(first)
        for row in model.rows {
            for cap in row where cap.char == key {
                if let win = cap.window {
                    select(win)
                    return true
                }
            }
        }
        return false
    }

    private func select(_ window: WindowInfo) {
        hide()
        WindowManager.activate(window)
    }

    /// Close the window and remove it from the grid, leaving the other keys in place.
    /// The overlay stays open so several windows can be closed in a row.
    private func closeWindow(_ window: WindowInfo) {
        WindowManager.close(window)
        for r in model.rows.indices {
            for c in model.rows[r].indices where model.rows[r][c].window?.id == window.id {
                model.rows[r][c].window = nil
            }
        }
        model.windowCount = max(0, model.windowCount - 1)
    }

    // MARK: Permission UX

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「辅助功能」权限"
        alert.informativeText = """
        窗口闪切 需要辅助功能权限才能列出并切换其他应用的窗口。
        请在 系统设置 ▸ 隐私与安全性 ▸ 辅助功能 中勾选 窗口闪切，然后再次按下快捷键。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string:
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - NSWindowDelegate

extension OverlayController: NSWindowDelegate {
    /// Dismiss when the overlay loses focus (e.g. the user switches apps with the keyboard).
    func windowDidResignKey(_ notification: Notification) {
        hide()
    }
}
