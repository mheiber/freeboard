# Plan: Launch at Login

## Description

Add a "Launch at Login" toggle in the right-click status menu. When enabled, Freeboard starts automatically when the user logs in. Uses the modern `SMAppService` API (macOS 13+) or `SMLoginItemSetEnabled` for older systems.

## Why it fits the values

- **Simplicity over features**: A single menu toggle. No preferences window. The expected behavior is obvious.
- **One window, one purpose**: No new windows. Just a menu item with a checkmark.
- **Keyboard-first**: Not applicable (this is a one-time setup action), but it does not interfere with keyboard flow.
- **Instant and ephemeral**: The launch-at-login registration is the one necessary exception to "no disk writes." The OS manages the login item state, not the app. Freeboard itself still stores nothing on disk.

## Implementation approach

### AppDelegate.swift

Add a menu item in `showStatusMenu()`, between the Shortcut submenu and Help:
```swift
let loginItem = NSMenuItem(title: L.launchAtLogin, action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
loginItem.target = self
loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
menu.addItem(loginItem)
```

Add the toggle handler:
```swift
import ServiceManagement

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
```

### Localization.swift

Add `launchAtLogin` string:
- en: "Launch at Login"
- zh: "登录时启动"
- hi: "लॉगिन पर शुरू करें"
- es: "Iniciar al acceder"
- fr: "Ouvrir au démarrage"
- ar: "التشغيل عند تسجيل الدخول"
- bn: "লগইনে চালু করুন"
- pt: "Abrir ao iniciar sessão"
- ru: "Запускать при входе"
- ja: "ログイン時に起動"

### Entitlements

No additional entitlements needed for `SMAppService`. It works with the app's existing sandbox/hardened runtime configuration.

## Testing

1. Manual test:
   - Right-click `[F]`, verify "Launch at Login" appears.
   - Click it, verify checkmark appears.
   - Log out and log in, verify Freeboard starts automatically.
   - Right-click `[F]`, click "Launch at Login" again, verify checkmark disappears.
   - Log out and log in, verify Freeboard does NOT start.
2. Verify the menu item state persists across app restarts (OS manages this, not the app).
3. VoiceOver: Verify the menu item is accessible with its state (checked/unchecked).
