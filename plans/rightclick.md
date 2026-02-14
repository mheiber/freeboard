Add right-click support for nearly editing entries, favoriting, expanding, anything else that seems useful and doesn't clog up the UI too much or Overwhelm the user. Take inspiration from Tmux's right-click context menu. It's beautiful and simple, and even though Tmux can do hundreds and hundreds of things, it usually only has six or seven entries in it at most. We may be able to get away with even fewer.

---

# Implementation Plan: Right-Click Context Menu for Clipboard Entries

## Context

Freeboard's entry interactions are keyboard-driven (Enter, ⌘S, ⌘D, ^E, Tab, ⇧Enter). These are powerful but hard to discover. A right-click context menu exposes them naturally, without adding UI clutter. Inspired by tmux's minimal right-click menu: 4-7 items, context-sensitive, native NSMenu.

## Files to Modify

1. **`Freeboard/ClipboardHistoryViewController.swift`** — add NSMenuDelegate, context menu setup, action handlers (~100 lines)
2. **`Freeboard/Localization.swift`** — add 11 localized strings across 10 languages (~70 lines)

No other files need changes — all required data model properties and delegate methods already exist.

## Approach: NSMenu + NSMenuDelegate

Set `tableView.menu` to an empty `NSMenu` in `setupTableView()`. Implement `NSMenuDelegate.menuNeedsUpdate(_:)` to dynamically populate the menu based on the clicked row. This is the standard AppKit pattern that also gives VoiceOver users access via the Actions rotor for free.

---

## Step 1: Localization.swift

### Add static properties (after line 167, before `accessibleMinutesAgo`):

```swift
static var contextPaste: String { tr("contextPaste") }
static var contextPasteAsPlainText: String { tr("contextPasteAsPlainText") }
static var contextPasteAsRichText: String { tr("contextPasteAsRichText") }
static var contextPasteAsMarkdown: String { tr("contextPasteAsMarkdown") }
static var contextEdit: String { tr("contextEdit") }
static var contextExpand: String { tr("contextExpand") }
static var contextCollapse: String { tr("contextCollapse") }
static var contextStar: String { tr("contextStar") }
static var contextUnstar: String { tr("contextUnstar") }
static var contextDelete: String { tr("contextDelete") }
static var contextRevealInFinder: String { tr("contextRevealInFinder") }
```

### Add dictionary entries (inside `strings` dictionary, after the last entry before `]`):

```swift
"contextPaste": [
    .en: "Paste", .zh: "粘贴", .hi: "पेस्ट करें", .es: "Pegar", .fr: "Coller",
    .ar: "لصق", .bn: "পেস্ট", .pt: "Colar", .ru: "Вставить", .ja: "貼り付け"
],
"contextPasteAsPlainText": [
    .en: "Paste as Plain Text", .zh: "粘贴为纯文本", .hi: "सादा टेक्स्ट के रूप में पेस्ट करें",
    .es: "Pegar como texto plano", .fr: "Coller en texte brut",
    .ar: "لصق كنص عادي", .bn: "সাধারণ টেক্সট হিসেবে পেস্ট",
    .pt: "Colar como texto simples", .ru: "Вставить как текст", .ja: "テキストとして貼り付け"
],
"contextPasteAsRichText": [
    .en: "Paste as Rich Text", .zh: "粘贴为富文本", .hi: "रिच टेक्स्ट के रूप में पेस्ट करें",
    .es: "Pegar como texto enriquecido", .fr: "Coller en texte enrichi",
    .ar: "لصق كنص منسق", .bn: "রিচ টেক্সট হিসেবে পেস্ট",
    .pt: "Colar como texto formatado", .ru: "Вставить с форматированием", .ja: "リッチテキストとして貼り付け"
],
"contextPasteAsMarkdown": [
    .en: "Paste as Markdown", .zh: "粘贴为 Markdown", .hi: "Markdown के रूप में पेस्ट करें",
    .es: "Pegar como Markdown", .fr: "Coller en Markdown",
    .ar: "لصق كـ Markdown", .bn: "Markdown হিসেবে পেস্ট",
    .pt: "Colar como Markdown", .ru: "Вставить как Markdown", .ja: "Markdownとして貼り付け"
],
"contextEdit": [
    .en: "Edit", .zh: "编辑", .hi: "संपादित करें", .es: "Editar", .fr: "Modifier",
    .ar: "تحرير", .bn: "সম্পাদনা", .pt: "Editar", .ru: "Править", .ja: "編集"
],
"contextExpand": [
    .en: "Expand", .zh: "展开", .hi: "विस्तार करें", .es: "Expandir", .fr: "Développer",
    .ar: "توسيع", .bn: "প্রসারিত", .pt: "Expandir", .ru: "Развернуть", .ja: "展開"
],
"contextCollapse": [
    .en: "Collapse", .zh: "折叠", .hi: "संक्षिप्त करें", .es: "Contraer", .fr: "Réduire",
    .ar: "طي", .bn: "সঙ্কুচিত", .pt: "Recolher", .ru: "Свернуть", .ja: "折りたたむ"
],
"contextStar": [
    .en: "Star", .zh: "收藏", .hi: "स्टार करें", .es: "Destacar", .fr: "Ajouter aux favoris",
    .ar: "تمييز", .bn: "তারকা দিন", .pt: "Favoritar", .ru: "Отметить", .ja: "スターを付ける"
],
"contextUnstar": [
    .en: "Unstar", .zh: "取消收藏", .hi: "स्टार हटाएं", .es: "Quitar destacado", .fr: "Retirer des favoris",
    .ar: "إلغاء التمييز", .bn: "তারকা সরান", .pt: "Remover favorito", .ru: "Снять отметку", .ja: "スターを外す"
],
"contextDelete": [
    .en: "Delete", .zh: "删除", .hi: "हटाएं", .es: "Eliminar", .fr: "Supprimer",
    .ar: "حذف", .bn: "মুছুন", .pt: "Excluir", .ru: "Удалить", .ja: "削除"
],
"contextRevealInFinder": [
    .en: "Reveal in Finder", .zh: "在 Finder 中显示", .hi: "Finder में दिखाएं",
    .es: "Mostrar en Finder", .fr: "Afficher dans le Finder",
    .ar: "عرض في Finder", .bn: "Finder-এ দেখান",
    .pt: "Mostrar no Finder", .ru: "Показать в Finder", .ja: "Finderで表示"
],
```

---

## Step 2: ClipboardHistoryViewController.swift

### 2a. Add `NSMenuDelegate` to class declaration (line 12)

```swift
// BEFORE:
class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate, NSGestureRecognizerDelegate, MonacoEditorDelegate {

// AFTER:
class ClipboardHistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSTextViewDelegate, NSGestureRecognizerDelegate, MonacoEditorDelegate, NSMenuDelegate {
```

### 2b. Set up context menu in `setupTableView()` (add before closing brace, after the tracking area code at line 256)

```swift
// Context menu for right-click on rows
let contextMenu = NSMenu()
contextMenu.delegate = self
tableView.menu = contextMenu
```

### 2c. Add NSMenuDelegate implementation (new MARK section, after the `mouseExited` method around line 1465)

Shortcut hints are baked into the menu item titles tmux-style (e.g. `"Paste  (Enter)"`) rather than using NSMenuItem's `keyEquivalent`. This avoids conflicts with the local key monitor and looks more like tmux.

```swift
// MARK: - NSMenuDelegate

func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()

    // Don't show context menu while editing
    if editingIndex != nil || monacoEditorView != nil { return }

    let row = tableView.clickedRow
    guard row >= 0, row < filteredEntries.count else { return }

    let entry = filteredEntries[row]

    // Visually select the right-clicked row
    selectedIndex = row
    tableView.reloadData()
    updateHelpLabel()

    // Helper to add a menu item with an inline shortcut hint, tmux-style
    func addItem(_ title: String, hint: String? = nil, action: Selector) {
        let label = hint != nil ? "\(title)  (\(hint!))" : title
        let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
        item.tag = row
        item.target = self
        menu.addItem(item)
    }

    // 1. Paste (always)
    addItem(L.contextPaste, hint: "Enter", action: #selector(contextMenuPaste(_:)))

    // 2. Alternate paste (conditional on format category)
    if entry.entryType == .text && !entry.isPassword {
        switch entry.formatCategory {
        case .richText:
            addItem(L.contextPasteAsPlainText, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
        case .plainMarkdown:
            addItem(L.contextPasteAsRichText, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
        case .richMarkdown:
            addItem(L.contextPasteAsMarkdown, hint: "⇧Enter", action: #selector(contextMenuPasteAlternate(_:)))
        case .plainText:
            break
        }
    }

    menu.addItem(NSMenuItem.separator())

    // 3. Edit (not for passwords)
    if !entry.isPassword {
        addItem(L.contextEdit, hint: "^E", action: #selector(contextMenuEdit(_:)))
    }

    // 4. Expand/Collapse
    let expandTitle = expandedIndex == row ? L.contextCollapse : L.contextExpand
    addItem(expandTitle, hint: "Tab", action: #selector(contextMenuToggleExpand(_:)))

    // 5. Star/Unstar
    let starTitle = entry.isStarred ? L.contextUnstar : L.contextStar
    addItem(starTitle, hint: "⌘S", action: #selector(contextMenuToggleStar(_:)))

    menu.addItem(NSMenuItem.separator())

    // 6. Reveal in Finder (file URL entries only)
    if entry.entryType == .fileURL, entry.fileURL != nil {
        addItem(L.contextRevealInFinder, action: #selector(contextMenuRevealInFinder(_:)))
    }

    // 7. Delete (always, last)
    addItem(L.contextDelete, hint: "⌘D", action: #selector(contextMenuDelete(_:)))
}
```

No `keyEquivalent` is set on any item — the shortcut hints are purely visual, just like tmux. This completely avoids conflicts with the local key monitor in `viewDidAppear`.

### 2d. Add context menu action methods (after `deleteSelected()` around line 1436)

```swift
// MARK: - Context menu actions

@objc private func contextMenuPaste(_ sender: NSMenuItem) {
    selectCurrent(at: sender.tag)
}

@objc private func contextMenuPasteAlternate(_ sender: NSMenuItem) {
    selectCurrentAlternateFormat(at: sender.tag)
}

@objc private func contextMenuEdit(_ sender: NSMenuItem) {
    let row = sender.tag
    guard row < filteredEntries.count else { return }
    selectedIndex = row
    enterEditMode()
}

@objc private func contextMenuToggleExpand(_ sender: NSMenuItem) {
    let row = sender.tag
    guard row < filteredEntries.count else { return }
    selectedIndex = row
    toggleExpand()
}

@objc private func contextMenuToggleStar(_ sender: NSMenuItem) {
    let row = sender.tag
    guard row < filteredEntries.count else { return }
    clipboardManager?.toggleStar(id: filteredEntries[row].id)
}

@objc private func contextMenuDelete(_ sender: NSMenuItem) {
    let row = sender.tag
    guard row < filteredEntries.count else { return }
    historyDelegate?.didDeleteEntry(filteredEntries[row])
}

@objc private func contextMenuRevealInFinder(_ sender: NSMenuItem) {
    let row = sender.tag
    guard row < filteredEntries.count else { return }
    guard let url = filteredEntries[row].fileURL else { return }
    NSWorkspace.shared.activateFileViewerSelecting([url])
}
```

---

## Menu Structure Per Entry Type

**Text (rich):** 6 items
```
Paste  (Enter)
Paste as Plain Text  (⇧Enter)
─────────────────────────────────
Edit  (^E)
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Delete  (⌘D)
```

**Text (plain, no markdown):** 5 items
```
Paste  (Enter)
─────────────────────────────────
Edit  (^E)
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Delete  (⌘D)
```

**Text (markdown):** 6 items
```
Paste  (Enter)
Paste as Rich Text  (⇧Enter)
─────────────────────────────────
Edit  (^E)
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Delete  (⌘D)
```

**Image:** 5 items
```
Paste  (Enter)
─────────────────────────────────
Edit  (^E)
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Delete  (⌘D)
```

**File URL:** 6 items
```
Paste  (Enter)
─────────────────────────────────
Edit  (^E)
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Reveal in Finder
Delete  (⌘D)
```

**Password:** 4 items
```
Paste  (Enter)
─────────────────────────────────
Expand  (Tab)
Star  (⌘S)
─────────────────────────────────
Delete  (⌘D)
```

4-6 items per menu. Tmux-minimal.

---

## Edge Cases & Debugging Notes

### PopupWindow losing key status
NSMenu display blocks the run loop and does NOT cause the parent window to resign key status in the standard case. The `windowDidResignKey` observer in AppDelegate should not fire. If it does (popup closes when right-clicking), the fix is:
1. Add `private var isShowingContextMenu = false` to the view controller
2. Set it in `menuWillOpen(_:)` / `menuDidClose(_:)` (add these NSMenuDelegate methods)
3. Expose it as a property or use NotificationCenter so AppDelegate can check it before calling `hidePopup()`

### Key equivalents — not used (tmux-style hints instead)
Shortcut hints are baked into the title string (e.g. `"Star  (⌘S)"`), not set as `keyEquivalent` on the NSMenuItem. This completely eliminates the conflict with the local key monitor in `viewDidAppear` (lines 141-153) that intercepts ⌘S and ⌘D. No key equivalents, no conflicts.

### Right-click during search
Works correctly: `filteredEntries` is used for row lookup, so the context menu acts on the visible filtered entry.

### Right-click on empty area
`tableView.clickedRow` returns -1 when clicking outside rows. The `guard row >= 0` check handles this — menu stays empty, which AppKit suppresses (no menu appears).

### Right-click during editing
The early return `if editingIndex != nil || monacoEditorView != nil { return }` prevents context menu during edit mode.

---

## Verification

1. **Build**: `xcodebuild -scheme Freeboard -configuration Debug build` (or open Xcode and ⌘B)
2. **Manual test matrix** — right-click each entry type:
   - Plain text entry → Paste, Edit, Expand, Star, Delete (5 items)
   - Rich text entry → Paste, Paste as Plain Text, Edit, Expand, Star, Delete (6 items)
   - Markdown entry → Paste, Paste as Rich Text, Edit, Expand, Star, Delete (6 items)
   - Image entry → Paste, Edit, Expand, Star, Delete (5 items)
   - File URL entry → Paste, Edit, Expand, Star, Reveal in Finder, Delete (6 items)
   - Password entry → Paste, Expand, Star, Delete (4 items)
   - Starred entry → verify "Unstar" appears instead of "Star"
   - Expanded entry → verify "Collapse" appears instead of "Expand"
3. **Action verification**: click each menu item and verify it does the same thing as the keyboard shortcut
4. **Edge cases**: right-click during edit mode (no menu), right-click empty area (no menu), right-click during search (correct filtered entry)
5. **VoiceOver**: focus a row, use Control+Option+Shift+M to open Actions menu, verify context menu appears
6. **Window stability**: verify popup doesn't close when right-click menu appears
