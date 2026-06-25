import AppKit

/// Detects a quick double-tap of the Fn / 🌐 (Globe) key system-wide.
///
/// The Fn key is a modifier, not an ordinary key, so it can't be a Carbon hot key.
/// Instead we watch `.flagsChanged` events: the physical Fn key toggles the
/// `.function` modifier flag, and only the Fn key produces a `flagsChanged` carrying
/// it (arrow / function keys emit `keyDown`, not `flagsChanged`), so a rising edge of
/// `.function` on a `flagsChanged` event is an unambiguous Fn press.
final class FnDoubleTap {
    private let interval: TimeInterval
    private let onDoubleTap: () -> Void

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var fnWasDown = false
    private var lastTapTime: TimeInterval = 0

    init(interval: TimeInterval = 0.4, onDoubleTap: @escaping () -> Void) {
        self.interval = interval
        self.onDoubleTap = onDoubleTap

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
            [weak self] event in
            self?.handle(event)
            return event
        }
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }

    private func handle(_ event: NSEvent) {
        // `.function` is the only modifier we expect on an Fn-triggered flagsChanged;
        // ignore changes that also carry other modifiers to avoid false positives.
        let onlyFunction = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask) == .function
        let fnDown = onlyFunction && event.modifierFlags.contains(.function)

        defer { fnWasDown = fnDown }
        guard fnDown, !fnWasDown else { return }   // rising edge only

        let now = event.timestamp
        if now - lastTapTime <= interval {
            lastTapTime = 0
            onDoubleTap()
        } else {
            lastTapTime = now
        }
    }
}
