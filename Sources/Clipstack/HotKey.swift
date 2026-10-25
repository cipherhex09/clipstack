import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut using the Carbon hot key API. It is old but
/// it is still the only way to get a global shortcut without Accessibility or
/// Input Monitoring permission.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static var nextID: UInt32 = 1
    private static var actions: [UInt32: () -> Void] = [:]
    private let id: UInt32

    init?(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.action = action
        id = HotKey.nextID
        HotKey.nextID += 1

        var carbonMods: UInt32 = 0
        if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonMods |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonMods |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            DispatchQueue.main.async { HotKey.actions[hk.id]?() }
            return noErr
        }, 1, &spec, nil, &handler)
        guard status == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_5053), id: id) // "CLPS"
        guard RegisterEventHotKey(keyCode, carbonMods, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr else {
            return nil
        }
        HotKey.actions[id] = action
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
        HotKey.actions[id] = nil
    }
}
