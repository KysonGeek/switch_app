import AppKit
import ApplicationServices

/// A single openable window discovered through the Accessibility API.
struct WindowInfo: Identifiable {
    let id = UUID()
    let pid: pid_t
    let appName: String
    let appIcon: NSImage?
    let title: String
    let isMinimized: Bool
    let axElement: AXUIElement

    /// What to show under the key cap.
    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? appName : t
    }
}

enum WindowManager {

    // MARK: Accessibility permission

    /// Returns true if we are trusted. Pass `prompt: true` to show the system dialog once.
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Enumeration

    /// All standard windows of every regular (Dock-visible) application.
    ///
    /// Apps are queried in parallel: establishing the AX connection to each app is
    /// the dominant cost, so doing them concurrently turns a multi-second cold start
    /// into a fraction of a second. Result order still follows app launch order.
    static func allWindows() -> [WindowInfo] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated && $0.processIdentifier != selfPID
        }

        var perApp = [[WindowInfo]](repeating: [], count: apps.count)
        DispatchQueue.concurrentPerform(iterations: apps.count) { idx in
            perApp[idx] = windows(of: apps[idx])   // distinct indices → no data race
        }
        return perApp.flatMap { $0 }
    }

    /// Prime AX connections in the background so the first hot-key press is instant.
    static func warmUp() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = allWindows()
        }
    }

    /// Per-element messaging timeout (seconds) so a hung app can't block enumeration.
    private static let axTimeout: Float = 0.2

    /// Standard windows of a single application.
    private static func windows(of app: NSRunningApplication) -> [WindowInfo] {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, axTimeout)
        guard let wins = copyWindows(appElement) else { return [] }
        return wins.compactMap { windowInfo($0, app: app, pid: pid) }
    }

    /// Read a window's attributes in a single round-trip and map it to `WindowInfo`.
    private static func windowInfo(
        _ win: AXUIElement, app: NSRunningApplication, pid: pid_t
    ) -> WindowInfo? {
        AXUIElementSetMessagingTimeout(win, axTimeout)

        let attrs = [kAXSubroleAttribute, kAXTitleAttribute, kAXMinimizedAttribute] as CFArray
        var raw: CFArray?
        let err = AXUIElementCopyMultipleAttributeValues(
            win, attrs, AXCopyMultipleAttributeOptions(rawValue: 0), &raw)
        guard err == .success, let values = raw as? [AnyObject], values.count == 3 else {
            return nil
        }

        // Keep only document windows / dialogs; drop palettes, sheets, popovers.
        if let subrole = values[0] as? String,
           subrole != (kAXStandardWindowSubrole as String),
           subrole != (kAXDialogSubrole as String) {
            return nil
        }

        let title = values[1] as? String ?? ""
        let minimized = (values[2] as? Bool) ?? false

        return WindowInfo(
            pid: pid,
            appName: app.localizedName ?? "App",
            appIcon: app.icon,
            title: title,
            isMinimized: minimized,
            axElement: win)
    }

    /// Mock windows built from running apps (icons + fake titles) for UI previews. No AX needed.
    static func demoWindows() -> [WindowInfo] {
        let titles = ["项目说明.md", "收件箱", "Pull Request #42", "设计稿", "终端",
                      "会议纪要", "Dashboard", "main.swift", "聊天", "草稿"]
        var out: [WindowInfo] = []
        var i = 0
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && !app.isTerminated {
            let el = AXUIElementCreateApplication(app.processIdentifier)
            out.append(WindowInfo(
                pid: app.processIdentifier,
                appName: app.localizedName ?? "App",
                appIcon: app.icon,
                title: titles[i % titles.count],
                isMinimized: false,
                axElement: el))
            i += 1
            if i >= 26 { break }
        }
        return out
    }

    // MARK: Activation

    /// Bring the given window to the front and focus it.
    static func activate(_ window: WindowInfo) {
        if let app = NSRunningApplication(processIdentifier: window.pid) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
        if window.isMinimized {
            AXUIElementSetAttributeValue(
                window.axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementSetAttributeValue(
            window.axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)
    }

    // MARK: AX helpers

    private static func copyWindows(_ appElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            appElement, kAXWindowsAttribute as CFString, &value)
        guard err == .success else { return nil }
        return value as? [AXUIElement]
    }
}
