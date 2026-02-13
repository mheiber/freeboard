import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate, ClipboardManagerDelegate, ClipboardHistoryDelegate {

    private var statusItem: NSStatusItem!
    private var popupWindow: PopupWindow!
    private var historyVC: ClipboardHistoryViewController!
    private var clipboardManager: ClipboardManager!
    private var hotkeyManager: GlobalHotkeyManager!
    private var previousApp: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
            ]
            button.attributedTitle = NSAttributedString(string: "[F]", attributes: attrs)
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopupWindow() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let windowWidth: CGFloat = 900
        let windowHeight: CGFloat = 750
        let x = (screenFrame.width - windowWidth) / 2
        let y = (screenFrame.height - windowHeight) / 2

        popupWindow = PopupWindow(contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight))
        popupWindow.isOpaque = false
        popupWindow.backgroundColor = .clear

        historyVC = ClipboardHistoryViewController()
        historyVC.clipboardManager = clipboardManager
        historyVC.historyDelegate = self
        popupWindow.contentViewController = historyVC

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: popupWindow
        )
    }

    @objc private func windowDidResignKey(_ notification: Notification) {
        hidePopup()
    }

    private func setupHotkey() {
        hotkeyManager = GlobalHotkeyManager()
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.togglePopup()
        }
        hotkeyManager.start()
    }

    // MARK: - Popup

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePopup()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()

        // Language submenu
        let langItem = NSMenuItem(title: L.current == .zh ? "语言" : "Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()

        let enItem = NSMenuItem(title: L.english, action: #selector(switchToEnglish), keyEquivalent: "")
        enItem.target = self
        if L.current == .en { enItem.state = .on }
        langMenu.addItem(enItem)

        let zhItem = NSMenuItem(title: L.chinese, action: #selector(switchToChinese), keyEquivalent: "")
        zhItem.target = self
        if L.current == .zh { zhItem.state = .on }
        langMenu.addItem(zhItem)

        langItem.submenu = langMenu
        menu.addItem(langItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L.quitFreeboard, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.menu = nil
        }
    }

    @objc private func switchToEnglish() {
        L.current = .en
        historyVC.refreshLocalization()
    }

    @objc private func switchToChinese() {
        L.current = .zh
        historyVC.refreshLocalization()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func togglePopup() {
        if popupWindow.isVisible {
            hidePopup()
        } else {
            showPopup()
        }
    }

    private func showPopup() {
        previousApp = NSWorkspace.shared.frontmostApplication
        historyVC.reloadEntries()

        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let windowFrame = popupWindow.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        popupWindow.setFrameOrigin(NSPoint(x: x, y: y))

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
        if let app = previousApp {
            app.activate()
        }

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
