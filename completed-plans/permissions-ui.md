# Permissions UI Enhancement Plan

## Context

When Freeboard lacks macOS Accessibility permissions, it shows a solitary orange "⚠" emoji button in the bottom-right. This is easy to miss and unclear. The goal is to:
1. Show **"⚠ Needs Permissions"** (all orange) so the problem is immediately obvious
2. Add a **retro-themed hover tooltip** explaining what to do (replacing the default yellow macOS tooltip)

## Files to Modify

- `Freeboard/Localization.swift` — add button title string (10 languages)
- `Freeboard/ClipboardHistoryViewController.swift` — button title, tracking area, tooltip

## Edits

### 1. Localization.swift — Add button title string

**Add static accessor** (after line 133, near `permissionWarningLabel`):
```swift
static var permissionWarningButtonTitle: String { tr("permissionWarningButtonTitle") }
```

**Add dictionary entry** (after the `permissionWarningTooltip` block ending at line 459):
```swift
"permissionWarningButtonTitle": [
    .en: "Needs Permissions",
    .zh: "需要权限",
    .hi: "अनुमति चाहिए",
    .es: "Necesita permisos",
    .fr: "Permissions requises",
    .ar: "يلزم إذن",
    .bn: "অনুমতি দরকার",
    .pt: "Precisa de permissões",
    .ru: "Нужны разрешения",
    .ja: "許可が必要"
],
```

### 2. ClipboardHistoryViewController.swift — Add instance variable

**Add property** (line ~29, after `helpOverlay`):
```swift
private var permissionTooltipView: NSView?
```

### 3. ClipboardHistoryViewController.swift — Change button creation (lines 282-289)

**Replace** the current button setup:
```swift
permissionWarningButton = NSButton(title: "⚠", target: self, action: #selector(permissionWarningClicked))
permissionWarningButton.translatesAutoresizingMaskIntoConstraints = false
permissionWarningButton.isBordered = false
permissionWarningButton.font = retroFontSmall
permissionWarningButton.contentTintColor = NSColor.orange
permissionWarningButton.toolTip = L.permissionWarningTooltip
permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
permissionWarningButton.isHidden = true
```

**With:**
```swift
permissionWarningButton = NSButton(title: "", target: self, action: #selector(permissionWarningClicked))
permissionWarningButton.translatesAutoresizingMaskIntoConstraints = false
permissionWarningButton.isBordered = false
let warningAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: NSColor.orange,
    .font: retroFontSmall
]
permissionWarningButton.attributedTitle = NSAttributedString(
    string: "⚠ \(L.permissionWarningButtonTitle)",
    attributes: warningAttrs
)
permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
permissionWarningButton.isHidden = true

let warningTrackingArea = NSTrackingArea(
    rect: .zero,
    options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
    owner: self,
    userInfo: ["zone": "permissionWarning"]
)
permissionWarningButton.addTrackingArea(warningTrackingArea)
```

Key changes: `attributedTitle` with orange color instead of `title` + `contentTintColor`. Remove `.toolTip` (custom tooltip replaces it). Add tracking area for hover detection with `userInfo` to distinguish from the existing tableView tracking area.

### 4. ClipboardHistoryViewController.swift — Update refreshLocalization() (lines 180-181)

**Replace:**
```swift
permissionWarningButton.toolTip = L.permissionWarningTooltip
permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
```

**With:**
```swift
let warningAttrs: [NSAttributedString.Key: Any] = [
    .foregroundColor: NSColor.orange,
    .font: retroFontSmall
]
permissionWarningButton.attributedTitle = NSAttributedString(
    string: "⚠ \(L.permissionWarningButtonTitle)",
    attributes: warningAttrs
)
permissionWarningButton.setAccessibilityLabel(L.permissionWarningLabel)
```

### 5. ClipboardHistoryViewController.swift — Add mouseEntered override

There is NO existing `mouseEntered` override. Add after `mouseExited` (after line 1465):

```swift
override func mouseEntered(with event: NSEvent) {
    if let zone = event.trackingArea?.userInfo?["zone"] as? String, zone == "permissionWarning" {
        showPermissionTooltip()
        return
    }
    super.mouseEntered(with: event)
}
```

### 6. ClipboardHistoryViewController.swift — Modify mouseExited override (line 1458)

**Replace** the entire current override:
```swift
override func mouseExited(with event: NSEvent) {
    let oldRow = hoveredRow
    hoveredRow = nil
    mouseInIndicatorZone = false
    if let old = oldRow {
        tableView.reloadData(forRowIndexes: IndexSet(integer: old), columnIndexes: IndexSet(integer: 0))
    }
}
```

**With:**
```swift
override func mouseExited(with event: NSEvent) {
    if let zone = event.trackingArea?.userInfo?["zone"] as? String, zone == "permissionWarning" {
        dismissPermissionTooltip()
        return
    }
    let oldRow = hoveredRow
    hoveredRow = nil
    mouseInIndicatorZone = false
    if let old = oldRow {
        tableView.reloadData(forRowIndexes: IndexSet(integer: old), columnIndexes: IndexSet(integer: 0))
    }
}
```

### 7. ClipboardHistoryViewController.swift — Add tooltip show/dismiss methods

Add near `updatePermissionWarning()` (after line 758):

```swift
private func showPermissionTooltip() {
    guard permissionTooltipView == nil else { return }

    let tooltip = NSView()
    tooltip.translatesAutoresizingMaskIntoConstraints = false
    tooltip.wantsLayer = true
    tooltip.layer?.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.95).cgColor
    tooltip.layer?.borderColor = NSColor.orange.withAlphaComponent(0.4).cgColor
    tooltip.layer?.borderWidth = 1
    tooltip.layer?.cornerRadius = 4

    let label = NSTextField(labelWithString: L.permissionWarningTooltip)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.font = retroFontSmall
    label.textColor = NSColor.orange.withAlphaComponent(0.85)
    label.backgroundColor = .clear
    label.isBezeled = false
    label.isEditable = false
    label.maximumNumberOfLines = 0
    label.lineBreakMode = .byWordWrapping
    label.preferredMaxLayoutWidth = 400

    tooltip.addSubview(label)
    containerView.addSubview(tooltip, positioned: .below, relativeTo: effectsView)

    NSLayoutConstraint.activate([
        label.topAnchor.constraint(equalTo: tooltip.topAnchor, constant: 8),
        label.bottomAnchor.constraint(equalTo: tooltip.bottomAnchor, constant: -8),
        label.leadingAnchor.constraint(equalTo: tooltip.leadingAnchor, constant: 10),
        label.trailingAnchor.constraint(equalTo: tooltip.trailingAnchor, constant: -10),

        tooltip.bottomAnchor.constraint(equalTo: permissionWarningButton.topAnchor, constant: -4),
        tooltip.trailingAnchor.constraint(equalTo: permissionWarningButton.trailingAnchor),
    ])

    permissionTooltipView = tooltip
}

private func dismissPermissionTooltip() {
    permissionTooltipView?.removeFromSuperview()
    permissionTooltipView = nil
}
```

Tooltip styling rationale:
- **Background** `(0.05, 0.05, 0.05, 0.95)`: near-black, slightly lighter than main bg for contrast
- **Border**: orange at 40% alpha — subtle, matches warning theme
- **Text**: orange at 85% alpha — readable, consistent with button
- **Corner radius 4**: minimal rounding for retro feel
- **Positioned `.below` effectsView**: CRT scanline effects render on top (same pattern as help overlay at line 437)
- **Anchored above button**: `bottomAnchor = button.topAnchor - 4`, trailing-aligned to button

### 8. ClipboardHistoryViewController.swift — Dismiss tooltip when warning hides

**Replace** `updatePermissionWarning()` (lines 755-758):
```swift
private func updatePermissionWarning() {
    let hasItems = !(clipboardManager?.entries.isEmpty ?? true)
    permissionWarningButton?.isHidden = AXIsProcessTrusted() || !hasItems
}
```

**With:**
```swift
private func updatePermissionWarning() {
    let hasItems = !(clipboardManager?.entries.isEmpty ?? true)
    let shouldHide = AXIsProcessTrusted() || !hasItems
    permissionWarningButton?.isHidden = shouldHide
    if shouldHide {
        dismissPermissionTooltip()
    }
}
```

### 9. ClipboardHistoryViewController.swift — Dismiss tooltip in Monaco editor (line 1555)

After `permissionWarningButton.isHidden = true` at line 1555, add:
```swift
dismissPermissionTooltip()
```

### 10. ClipboardHistoryViewController.swift — Dismiss tooltip in viewWillDisappear (line 158)

After `dismissHelp()` at line 158, add:
```swift
dismissPermissionTooltip()
```

## Testing

### Build verification
```bash
make build
```

### Manual testing
1. **Revoke accessibility permission** for Freeboard in System Settings > Privacy & Security > Accessibility (uncheck or remove Freeboard)
2. Open Freeboard, copy some text so there are clipboard entries
3. Verify the bottom-right shows **"⚠ Needs Permissions"** in orange (not just "⚠")
4. **Hover** over the warning text — a dark retro tooltip should appear above it with the instructions
5. **Move mouse away** — tooltip should disappear
6. **Click** the warning text — should open System Settings to the Accessibility pane
7. **Grant permission** — the warning and tooltip should both disappear
8. **Change language** via the status menu — verify the button text updates to the new language
9. **Open Monaco editor** (Ctrl-E on an entry) — verify the warning and any visible tooltip are hidden

### Unit tests
No new test file needed. The existing test patterns don't test UI views directly (they test models, managers, and state computation). The permission warning is inherently tied to `AXIsProcessTrusted()` which can't be mocked without swizzling. Manual testing above covers the changes.

### Debugging notes
- If the tooltip doesn't appear on hover: verify the tracking area is attached by checking `permissionWarningButton.trackingAreas` in the debugger. The `userInfo["zone"]` must be `"permissionWarning"`.
- If the tooltip appears behind the CRT effects: verify the `positioned: .below, relativeTo: effectsView` call. It should be the same pattern as the help overlay at line 437.
- If the button text is too wide for certain languages: check `permissionWarningButton.intrinsicContentSize` in the debugger. The button is trailing-anchored so it grows leftward. The help label on the left can overlap — this is by design.
