import Cocoa
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, ClipboardManagerDelegate, ClipboardHistoryDelegate {

    private var statusItem: NSStatusItem!
    private var popupWindow: PopupWindow!
    private var overlayWindow: ScreenOverlayWindow!
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
            button.setAccessibilityLabel("Freeboard")
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

        overlayWindow = ScreenOverlayWindow(screen: NSScreen.main ?? NSScreen.screens[0])

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

        // Open item
        let openItem = NSMenuItem(title: L.open, action: #selector(openApp), keyEquivalent: HotkeyChoice.current.rawValue)
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        // Language submenu
        let langItem = NSMenuItem(title: L.language, action: nil, keyEquivalent: "")
        langItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Language")
        let langMenu = NSMenu()
        for lang in Lang.allCases {
            let item = NSMenuItem(title: lang.nativeName, action: #selector(switchLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang
            if lang == L.current { item.state = .on }
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // Shortcut submenu
        let shortcutItem = NSMenuItem(title: L.shortcut, action: nil, keyEquivalent: "")
        let shortcutMenu = NSMenu()
        for choice in HotkeyChoice.allCases {
            let item = NSMenuItem(title: choice.displayName, action: #selector(switchHotkey(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            if choice == HotkeyChoice.current { item.state = .on }
            shortcutMenu.addItem(item)
        }
        shortcutItem.submenu = shortcutMenu
        menu.addItem(shortcutItem)

        // Launch at Login
        let loginItem = NSMenuItem(title: L.launchAtLogin, action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        menu.addItem(loginItem)

        // Vim mode toggle
        let vimItem = NSMenuItem(title: L.vimStyleEditing, action: #selector(toggleVimMode(_:)), keyEquivalent: "")
        vimItem.target = self
        vimItem.state = UserDefaults.standard.bool(forKey: "vimModeEnabled") ? .on : .off
        menu.addItem(vimItem)

        menu.addItem(NSMenuItem.separator())
        let helpItem = NSMenuItem(title: L.help, action: #selector(showHelp), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

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

    @objc private func switchLanguage(_ sender: NSMenuItem) {
        guard let lang = sender.representedObject as? Lang else { return }
        L.current = lang
        historyVC.refreshLocalization()
    }

    @objc private func switchHotkey(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? HotkeyChoice else { return }
        HotkeyChoice.current = choice
        hotkeyManager.register(keyCode: choice.keyCode)
        historyVC.refreshLocalization()
    }

    @objc private func openApp() {
        togglePopup()
    }

    @objc private func showHelp() {
        if !popupWindow.isVisible {
            showPopup()
        }
        historyVC.toggleHelp()
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

        overlayWindow.orderFront(nil)
        popupWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hidePopup() {
        popupWindow.orderOut(nil)
        overlayWindow.orderOut(nil)
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

        let canPaste = AXIsProcessTrusted()
        if !canPaste {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        hidePopup()

        if let app = previousApp {
            app.activate()
        }

        if canPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.simulatePaste()
            }
        }
    }

    func didSelectEntryAsPlainText(_ entry: ClipboardEntry) {
        clipboardManager.selectEntryAsPlainText(entry)

        let canPaste = AXIsProcessTrusted()
        if !canPaste {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        hidePopup()

        if let app = previousApp {
            app.activate()
        }

        if canPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.simulatePaste()
            }
        }
    }

    func didSelectEntryAsRenderedMarkdown(_ entry: ClipboardEntry) {
        clipboardManager.selectEntryAsRenderedMarkdown(entry)

        let canPaste = AXIsProcessTrusted()
        if !canPaste {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }

        hidePopup()

        if let app = previousApp {
            app.activate()
        }

        if canPaste {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.simulatePaste()
            }
        }
    }

    func didDeleteEntry(_ entry: ClipboardEntry) {
        clipboardManager.deleteEntry(id: entry.id)
    }

    func didDismiss() {
        hidePopup()
    }

    // MARK: - Launch at Login

    @objc private func toggleVimMode(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: "vimModeEnabled")
        UserDefaults.standard.set(!current, forKey: "vimModeEnabled")
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    try service.register()
                }
            } catch {
                NSSound.beep()
            }
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    // MARK: - Paste simulation

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            .permitLocalMouseEvents,
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgSessionEventTap)
        keyUp?.post(tap: .cgSessionEventTap)
    }
}
