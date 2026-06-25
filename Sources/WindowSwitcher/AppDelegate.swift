import AppKit
import SwiftUI
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let overlay = OverlayController()
    private var hotKey: GlobalHotKey?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let i = CommandLine.arguments.firstIndex(of: "--render"),
           i + 1 < CommandLine.arguments.count {
            let out = CommandLine.arguments[i + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.renderPreview(to: out)
                NSApp.terminate(nil)
            }
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--icon"),
           i + 1 < CommandLine.arguments.count {
            let out = CommandLine.arguments[i + 1]
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.renderIcon(to: out)
                NSApp.terminate(nil)
            }
            return
        }
        if CommandLine.arguments.contains("--bench") {
            let trusted = WindowManager.ensureAccessibility(prompt: false)
            for i in 1...3 {
                let t0 = ProcessInfo.processInfo.systemUptime
                let n = WindowManager.allWindows().count
                let ms = (ProcessInfo.processInfo.systemUptime - t0) * 1000
                print(String(format: "run %d: %d windows in %.1f ms (trusted=%@)",
                             i, n, ms, trusted ? "yes" : "no"))
            }
            NSApp.terminate(nil)
            return
        }
        if CommandLine.arguments.contains("--demo") {
            overlay.showDemo()
            return
        }
        setupStatusItem()

        // ⌥ Tab summons the switcher.
        hotKey = GlobalHotKey(
            keyCode: UInt32(kVK_Tab),
            modifiers: UInt32(optionKey)
        ) { [weak self] in
            self?.overlay.toggle()
        }

        // Prompt for Accessibility up front (non-blocking) so the first hotkey just works.
        if WindowManager.ensureAccessibility(prompt: true) {
            // Warm AX connections now so the first ⌥Tab doesn't pay cold-start latency.
            WindowManager.warmUp()
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.on.rectangle.angled",
            accessibilityDescription: "WindowSwitcher")

        let menu = NSMenu()
        menu.addItem(withTitle: "打开切换器 (⌥Tab)",
                     action: #selector(openSwitcher), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "辅助功能权限设置…",
                     action: #selector(openAccessibilitySettings), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 WindowSwitcher",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }

    @objc private func openSwitcher() { overlay.show() }

    /// Offscreen-render the populated keyboard over a wallpaper-like gradient to a PNG.
    @MainActor
    private func renderPreview(to path: String) {
        func dbg(_ s: String) {
            if let h = FileHandle(forWritingAtPath: "/tmp/render_dbg.txt") ?? {
                FileManager.default.createFile(atPath: "/tmp/render_dbg.txt", contents: nil)
                return FileHandle(forWritingAtPath: "/tmp/render_dbg.txt")
            }() {
                h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close()
            }
        }
        dbg("enter renderPreview")
        let model = OverlayModel()
        let windows = WindowManager.demoWindows()
        model.rows = KeyboardLayout.build(with: windows)
        model.windowCount = windows.count

        let size = NSSize(width: 1320, height: 700)
        let root = ZStack {
            LinearGradient(
                colors: [Color(red: 0.93, green: 0.55, blue: 0.32),
                         Color(red: 0.55, green: 0.45, blue: 0.78),
                         Color(red: 0.30, green: 0.42, blue: 0.72)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            KeyboardView(model: model)
        }
        .frame(width: size.width, height: size.height)

        dbg("built model, windows=\(windows.count)")
        let renderer = ImageRenderer(content: root)
        renderer.scale = 2
        dbg("made renderer, nsImage=\(renderer.nsImage != nil)")
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let bm = NSBitmapImageRep(data: tiff),
              let data = bm.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("render failed\n".utf8))
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("wrote \(path)\n".utf8))
    }

    /// Render the 1024×1024 app icon (gradient squircle + window cards + bolt) to a PNG.
    @MainActor
    private func renderIcon(to path: String) {
        let side: CGFloat = 1024
        let plate: CGFloat = 824          // Apple icon-grid plate within the 1024 canvas
        let radius: CGFloat = 185
        let blue = Color(red: 0.46, green: 0.62, blue: 1.0)
        let indigo = Color(red: 0.28, green: 0.40, blue: 0.92)

        let icon = ZStack {
            // Squircle plate with gradient + top gloss + hairline.
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [blue, indigo],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.28), .clear],
                                             startPoint: .top, endPoint: .center))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 3)
                )
                .frame(width: plate, height: plate)

            // Two window cards hinting "switch between windows".
            RoundedRectangle(cornerRadius: 70, style: .continuous)
                .fill(.white.opacity(0.16))
                .frame(width: 440, height: 330)
                .rotationEffect(.degrees(-9))
                .offset(x: -70, y: -50)
            RoundedRectangle(cornerRadius: 70, style: .continuous)
                .fill(.white.opacity(0.26))
                .frame(width: 440, height: 330)
                .rotationEffect(.degrees(7))
                .offset(x: 60, y: 50)

            // Lightning bolt = the in-app brand mark.
            Image(systemName: "bolt.fill")
                .font(.system(size: 380, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.20), radius: 22, y: 12)
        }
        .frame(width: side, height: side)

        let renderer = ImageRenderer(content: icon)
        renderer.scale = 1
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let bm = NSBitmapImageRep(data: tiff),
              let data = bm.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("icon render failed\n".utf8))
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write(Data("wrote icon \(path)\n".utf8))
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
