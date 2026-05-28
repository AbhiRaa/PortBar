import AppKit
import Carbon.HIToolbox

/// A single global hotkey. Default: ⌘⌥P (avoids VS Code's ⌘⇧P palette).
/// Calls `onPress` from the main thread.
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let onPress: () -> Void
    private static var shared: HotKey?

    init(keyCode: UInt32 = UInt32(kVK_ANSI_P),
         modifiers: UInt32 = UInt32(cmdKey | optionKey),
         onPress: @escaping () -> Void) {
        self.onPress = onPress
        HotKey.shared = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.shared?.onPress()
            return noErr
        }, 1, &eventType, nil, &handler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x50425254 /* "PBRT" */), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                            GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
