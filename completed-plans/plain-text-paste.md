# Plan: Rich Paste

Make rich text copy/paste work. Give option to paste rich text as plain.

## Description

Currently Freeboard only stores the `.string` (plain text) representation of clipboard content. When a user copies formatted text from a browser, email client, or word processor, the rich formatting (HTML, RTF) is lost. This plan preserves all pasteboard representations so that pasting from Freeboard restores the original formatting. Additionally, provide a "paste as plain text" shortcut (`Shift+Enter`) to strip formatting on demand.

## Why it fits the values

- **Simplicity over features**: The default behavior (Enter to paste) "just works" -- it preserves whatever the user originally copied. The plain text option is a single modifier key (`Shift+Enter`), not a menu or setting.
- **Keyboard-first**: `Enter` = paste with formatting. `Shift+Enter` = paste as plain text. Two muscle-memory bindings.
- **Terminal soul**: The UI does not change. Rich text entries are displayed as plain text in the green-on-black list (rendering formatted text in a CRT terminal would look absurd). The formatting is invisible until paste time.
- **Privacy by architecture**: All data stays in memory. No difference from storing plain text.

## Implementation approach

### ClipboardEntry.swift

Add a field to store the raw pasteboard representations:
```swift
struct ClipboardEntry {
    // ... existing fields ...
    let pasteboardData: [NSPasteboard.PasteboardType: Data]?  // nil for image/file entries
}
```

Update the initializer to accept this optional field (default `nil`).

### ClipboardManager.swift

In `checkForChanges()`, when processing text entries, also capture rich text data if present:

```swift
// After getting the plain text content:
var richData: [NSPasteboard.PasteboardType: Data] = [:]
let richTypes: [NSPasteboard.PasteboardType] = [.rtf, .html,
    NSPasteboard.PasteboardType("public.rtf"),
    NSPasteboard.PasteboardType("public.html")]
for richType in richTypes {
    if let data = pasteboard.data(forType: richType) {
        richData[richType] = data
    }
}
// Always store the plain string too
richData[.string] = content.data(using: .utf8)

let entry = ClipboardEntry(content: content, isPassword: isPassword, isStarred: wasStarred,
                            pasteboardData: richData.isEmpty ? nil : richData)
```

In `selectEntry()`, when pasting text entries, restore all representations:
```swift
case .text:
    if let pbData = entry.pasteboardData {
        for (type, data) in pbData {
            if type == .string {
                _ = pasteboard.setString(entry.content, forType: .string)
            } else {
                _ = pasteboard.setData(data, forType: type)
            }
        }
    } else {
        _ = pasteboard.setString(entry.content, forType: .string)
    }
```

Add a new method for plain-text-only paste:
```swift
func selectEntryAsPlainText(_ entry: ClipboardEntry) {
    pasteboard.clearContents()
    _ = pasteboard.setString(entry.content, forType: .string)
    lastChangeCount = pasteboard.changeCount
}
```

### ClipboardHistoryDelegate protocol

Add a new delegate method:
```swift
func didSelectEntryAsPlainText(_ entry: ClipboardEntry)
```

### AppDelegate.swift

Implement the new delegate method:
```swift
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
```

### ClipboardHistoryViewController.swift

In `keyDown(with:)`, modify the Enter handler:
```swift
if event.keyCode == 36 { // Enter
    if editingIndex != nil { return }
    if event.modifierFlags.contains(.shift) {
        selectCurrentAsPlainText()
    } else {
        handleEnter()
    }
    return
}
```

Add:
```swift
private func selectCurrentAsPlainText(at index: Int? = nil) {
    let idx = index ?? selectedIndex
    guard idx < filteredEntries.count else { return }
    historyDelegate?.didSelectEntryAsPlainText(filteredEntries[idx])
}
```

Also support `Shift+number` for plain text quick paste:
```swift
// In the number key handler:
if let chars = event.charactersIgnoringModifiers, let digit = chars.first, digit >= "1" && digit <= "9" {
    let index = Int(String(digit))! - 1
    if flags == .shift {
        selectCurrentAsPlainText(at: index)
    } else if flags.isEmpty {
        selectCurrent(at: index)
    }
    return
}
```

### PasteboardProviding protocol

Add a `setData` method to the protocol (needed for writing rich data back):
```swift
protocol PasteboardProviding: AnyObject {
    // ... existing methods ...
    func setData(_ data: Data, forType dataType: NSPasteboard.PasteboardType) -> Bool
}
```

`NSPasteboard` already conforms to this.

### Visual indicator

No visual indicator for rich text entries in the list. The user does not need to know whether an entry has formatting -- the formatting is preserved transparently. This keeps the UI clean and avoids the complexity of distinguishing entry types visually.

### Memory considerations

Rich text data is typically small (a few KB for HTML/RTF). For the 50-entry cap, the additional memory is negligible. No size cap needed for rich text data specifically.

### Help bar / Localization

Add hint text for Shift+Enter. In `makeHelpString()` or the `?` help overlay:
- en: "Shift+Enter paste as plain text"
- Add translations for all 10 languages.

## Testing

1. Add test in `ClipboardManagerTests.swift`:
   - Set up mock pasteboard with both `.string` and `.rtf` data.
   - Call `checkForChanges()`, verify entry has `pasteboardData` with both types.
   - Call `selectEntry()`, verify pasteboard has both `.string` and `.rtf` data.
   - Call `selectEntryAsPlainText()`, verify pasteboard has only `.string` data.
2. Manual test:
   - Copy formatted text from Safari (select text on a webpage, Cmd+C).
   - Open Freeboard, press Enter, paste into TextEdit (rich text mode) -- verify formatting is preserved.
   - Repeat, but press Shift+Enter -- verify text pastes without formatting.
   - Copy plain text from Terminal, paste from Freeboard -- verify no change in behavior.
3. Edge cases:
   - Password entries: `pasteboardData` should be nil (we do not store rich data for passwords).
   - Image/file entries: Not affected by this change (they do not have pasteboard data).
4. VoiceOver: No accessibility changes needed.
