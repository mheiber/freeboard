import Cocoa
import Carbon

class GlobalHotkeyManager {
    var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private static weak var activeInstance: GlobalHotkeyManager?

    func start() {
        GlobalHotkeyManager.activeInstance = self
        register(keyCode: HotkeyChoice.current.keyCode)
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        GlobalHotkeyManager.activeInstance = nil
    }

    func register(keyCode: Int) {
        // Unregister existing hotkey if any
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        // Install event handler if not already installed
        if eventHandlerRef == nil {
            installEventHandler()
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x46524244), id: 1)
        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            print("Failed to register hotkey: \(status)")
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event = event else { return OSStatus(eventNotHandledErr) }

                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard err == noErr else { return err }

                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        GlobalHotkeyManager.activeInstance?.onHotkeyPressed?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}
