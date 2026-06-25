import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hot key via Carbon and invokes a closure when pressed.
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false
    private let id: UInt32

    /// - Parameters:
    ///   - keyCode: a virtual key code (e.g. `kVK_Tab`).
    ///   - modifiers: Carbon modifier mask (e.g. `optionKey`).
    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.id = UInt32(Self.handlers.count + 1)
        Self.handlers[id] = handler
        Self.installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: OSType(0x53574348), id: id) // 'SWCH'
        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        Self.handlers[id] = nil
    }

    private static func installHandlerIfNeeded() {
        guard !installed else { return }
        installed = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed))

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, _ -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                GlobalHotKey.handlers[hkID.id]?()
                return noErr
            },
            1, &spec, nil, nil)
    }
}
