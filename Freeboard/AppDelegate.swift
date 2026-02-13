import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, ClipboardManagerDelegate, ClipboardHistoryDelegate {

    private var statusItem: NSStatusItem!
    private var popupWindow: PopupWindow!
    private var historyVC: ClipboardHistoryViewController!
    private var clipboardManager: ClipboardManager!
    private var hotkeyManager: GlobalHotkeyManager!
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        setupClipboardManager()
        setupStatusItem()
        setupPopupWindow()
        setupHotkey()
    }

    // MARK: - Setup

    private func setupClipboardManager() {
        clipboardManager = ClipboardManager()
        clipboardManager.delegate = self
        clipboardManager.startMonitoring()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "📋"
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    private func setupPopupWindow() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowWidth: CGFloat = 620
        let windowHeight: CGFloat = 500
        let x = (screenFrame.width - windowWidth) / 2
        let y = (screenFrame.height - windowHeight) / 2 + 100

        popupWindow = PopupWindow(contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight))

        historyVC = ClipboardHistoryViewController()
        historyVC.clipboardManager = clipboardManager
        historyVC.historyDelegate = self
        popupWindow.contentViewController = historyVC
    }

    private func setupHotkey() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.togglePopup()
        }
        hotkeyManager.start()
    }

    // MARK: - Popup

    @objc private func statusItemClicked() {
        togglePopup()
    }

    private func togglePopup() {
        if popupWindow.isVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        // Remember the currently active app so we can paste into it later
        previousApp = NSWorkspace.shared.frontmostApplication

        historyVC.reloadEntries()

        // Position near status item if possible
        if let button = statusItem.button, let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            let windowWidth: CGFloat = 620
            let x = screenRect.midX - windowWidth / 2
            let y = screenRect.minY - 510
            popupWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }

        popupWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePopup() {
        popupWindow.orderOut(nil)
    }

    // MARK: - ClipboardManagerDelegate

    func clipboardManagerDidUpdateEntries(_ manager: ClipboardManager) {
        if popupWindow.isVisible {
            historyVC.reloadEntries()
        }
    }

    // MARK: - ClipboardHistoryDelegate

    func didSelectEntry(_ entry: ClipboardEntry) {
        clipboardManager.selectEntry(entry)
        hidePopup()

        // Give a moment for the window to hide, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.simulatePaste()
        }
    }

    func didDeleteEntry(_ entry: ClipboardEntry) {
        clipboardManager.deleteEntry(id: entry.id)
    }

    func didDismiss() {
        hidePopup()
    }

    // MARK: - Paste simulation

    private func simulatePaste() {
        // Bring previous app to front
        if let app = previousApp {
            app.activate()
        }

        // Simulate Cmd-V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let source = CGEventSource(stateID: .combinedSessionState)

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
            keyDown?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)

            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
            keyUp?.flags = .maskCommand
            keyUp?.post(tap: .cghidEventTap)
        }
    }
}
