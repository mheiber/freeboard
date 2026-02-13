import Cocoa
import Carbon.HIToolbox

class GlobalHotkeyManager {
    var onHotkeyPressed: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var globalMonitor: Any?

    func start() {
        tryCreateEventTap()
        setupGlobalMonitorFallback()

        if eventTap == nil {
            promptForAccessibility()
            // Retry periodically until permissions are granted and tap succeeds
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.retryEventTapIfNeeded()
            }
        }
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func tryCreateEventTap() {
        guard eventTap == nil else { return }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// NSEvent global monitor as fallback when CGEvent tap isn't available.
    /// Can't consume the event, but at least the hotkey works.
    private func setupGlobalMonitorFallback() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            // Only use fallback if event tap isn't active
            guard self.eventTap == nil else { return }

            if event.modifierFlags.contains(.command) &&
                event.modifierFlags.contains(.shift) &&
                event.keyCode == 9 {
                DispatchQueue.main.async {
                    self.onHotkeyPressed?()
                }
            }
        }
    }

    private func retryEventTapIfNeeded() {
        guard eventTap == nil else {
            retryTimer?.invalidate()
            retryTimer = nil
            return
        }

        if AXIsProcessTrusted() {
            tryCreateEventTap()
            if eventTap != nil {
                retryTimer?.invalidate()
                retryTimer = nil
            }
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let vKeyCode: Int64 = 9

        if keyCode == vKeyCode &&
            flags.contains(.maskCommand) &&
            flags.contains(.maskShift) {
            DispatchQueue.main.async { [weak self] in
                self?.onHotkeyPressed?()
            }
            return nil // Consume the event
        }

        return Unmanaged.passRetained(event)
    }

    private func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
