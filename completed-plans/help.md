# Plan: Editing Help Screen + Help Button Label

## Context

Two related help UI improvements:

1. **Editing help screen**: Under Power Features in the main help overlay, add an "Editing →" link that opens a sub-screen explaining Ctrl+E to edit clipboard items, with a clickable toggle for vim-style editing. NOT accessible from the right-click status menu (unlike Markdown Support).

2. **Help button label**: Change `[?]` at bottom-right to `[Help]` — i18n'd and accessible.

## Files to Modify

- `Freeboard/Localization.swift` — 5 new keys + translations, no new accessors needed for help button (reuse `L.help`)
- `Freeboard/ClipboardHistoryViewController.swift` — editing help screen, help button label

## Step 1: Localization.swift — New keys

### Add static accessors (after `markdownHelpHr` on line 162):

```swift
static var editing: String { tr("editing") }
static var helpEditingLink: String { tr("helpEditingLink") }
static var editingHelpCtrlE: String { tr("editingHelpCtrlE") }
static var editingHelpVimEnable: String { tr("editingHelpVimEnable") }
static var editingHelpVimDisable: String { tr("editingHelpVimDisable") }
```

### Add dictionary entries (after `markdownHelpHr` entry, before closing `]`):

```swift
"editing": [
    .en: "Editing", .zh: "编辑", .hi: "संपादन", .es: "Edición", .fr: "Édition",
    .ar: "تحرير", .bn: "সম্পাদনা", .pt: "Edição", .ru: "Редактирование", .ja: "編集"
],
"helpEditingLink": [
    .en: "Editing →", .zh: "编辑 →", .hi: "संपादन →", .es: "Edición →", .fr: "Édition →",
    .ar: "→ تحرير", .bn: "সম্পাদনা →", .pt: "Edição →", .ru: "Редактирование →", .ja: "編集 →"
],
"editingHelpCtrlE": [
    .en: "Press Ctrl+E on any clipboard item to open the editor",
    .zh: "在任何剪贴板条目上按 Ctrl+E 打开编辑器",
    .hi: "किसी भी क्लिपबोर्ड आइटम पर Ctrl+E दबाकर एडिटर खोलें",
    .es: "Presiona Ctrl+E en cualquier elemento para abrir el editor",
    .fr: "Appuyez sur Ctrl+E sur un élément pour ouvrir l'éditeur",
    .ar: "اضغط Ctrl+E على أي عنصر لفتح المحرر",
    .bn: "যেকোনো ক্লিপবোর্ড আইটেমে Ctrl+E চাপুন এডিটর খুলতে",
    .pt: "Pressione Ctrl+E em qualquer item para abrir o editor",
    .ru: "Нажмите Ctrl+E на любом элементе для открытия редактора",
    .ja: "任意のクリップボード項目で Ctrl+E を押してエディタを開く"
],
"editingHelpVimEnable": [
    .en: "Click here to enable vim-style editing",
    .zh: "点击此处启用 Vim 风格编辑",
    .hi: "Vim शैली संपादन सक्षम करने के लिए यहां क्लिक करें",
    .es: "Haz clic aquí para activar la edición estilo Vim",
    .fr: "Cliquez ici pour activer l'édition style Vim",
    .ar: "انقر هنا لتفعيل تحرير بأسلوب Vim",
    .bn: "Vim স্টাইল সম্পাদনা সক্ষম করতে এখানে ক্লিক করুন",
    .pt: "Clique aqui para ativar edição estilo Vim",
    .ru: "Нажмите, чтобы включить редактирование в стиле Vim",
    .ja: "クリックして Vim スタイル編集を有効にする"
],
"editingHelpVimDisable": [
    .en: "Click here to disable vim-style editing",
    .zh: "点击此处禁用 Vim 风格编辑",
    .hi: "Vim शैली संपादन अक्षम करने के लिए यहां क्लिक करें",
    .es: "Haz clic aquí para desactivar la edición estilo Vim",
    .fr: "Cliquez ici pour désactiver l'édition style Vim",
    .ar: "انقر هنا لتعطيل تحرير بأسلوب Vim",
    .bn: "Vim স্টাইল সম্পাদনা নিষ্ক্রিয় করতে এখানে ক্লিক করুন",
    .pt: "Clique aqui para desativar edição estilo Vim",
    .ru: "Нажмите, чтобы отключить редактирование в стиле Vim",
    .ja: "クリックして Vim スタイル編集を無効にする"
],
```

## Step 2: ClipboardHistoryViewController.swift — Help button label

### 2a. `setupHelpLabel()` (line 270)

Replace:
```swift
helpButton = NSButton(title: "[?]", target: self, action: #selector(helpButtonClicked))
```
With:
```swift
helpButton = NSButton(title: "[\(L.help)]", target: self, action: #selector(helpButtonClicked))
```

After line 274 (`helpButton.contentTintColor = ...`), add:
```swift
helpButton.setAccessibilityLabel(L.help)
```

### 2b. `refreshLocalization()` (line 176)

Replace:
```swift
helpButton.title = "[?]"
```
With:
```swift
helpButton.title = "[\(L.help)]"
helpButton.setAccessibilityLabel(L.help)
```

## Step 3: ClipboardHistoryViewController.swift — Add "Editing →" link to `showHelp()`

### 3a. Create editingLinkButton (after `markdownLinkButton.setAccessibilityLabel` at line 373)

```swift
let editingLinkButton = NSButton(title: "", target: self, action: #selector(editingLinkClicked))
editingLinkButton.translatesAutoresizingMaskIntoConstraints = false
editingLinkButton.isBordered = false
editingLinkButton.attributedTitle = NSAttributedString(string: L.helpEditingLink, attributes: linkAttrs)
editingLinkButton.setAccessibilityLabel(L.editing)
```

### 3b. Add editingLinkButton to overlay subviews (after line 385 `overlay.addSubview(markdownLinkButton)`)

```swift
overlay.addSubview(editingLinkButton)
```

### 3c. Update constraints — !AXIsProcessTrusted() branch (lines 418-424)

Add after markdownLinkButton constraints:
```swift
editingLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
editingLinkButton.topAnchor.constraint(equalTo: markdownLinkButton.bottomAnchor, constant: 4),
```

### 3d. Update constraints — else branch (lines 426-432)

Add after markdownLinkButton constraints:
```swift
editingLinkButton.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
editingLinkButton.topAnchor.constraint(equalTo: markdownLinkButton.bottomAnchor, constant: 4),
```

## Step 4: ClipboardHistoryViewController.swift — Editing help screen

### 4a. Add action methods (after `markdownBackClicked()` at line 491)

```swift
@objc private func editingLinkClicked() {
    dismissHelp()
    showEditingHelp()
}

@objc private func editingBackClicked() {
    dismissHelp()
    showHelp()
}

@objc private func editingVimToggleClicked() {
    let current = UserDefaults.standard.bool(forKey: "vimModeEnabled")
    UserDefaults.standard.set(!current, forKey: "vimModeEnabled")
    // Refresh to reflect new state
    dismissHelp()
    showEditingHelp()
}
```

### 4b. Add `showEditingHelp()` method (after the action methods above)

Follow the exact same pattern as `showMarkdownHelp()` (line 498-654):

- Same overlay setup (dark background, back button using `L.markdownHelpBack`, same fonts)
- Title: `L.editing.uppercased()` (same pattern as markdown uses `L.markdownSupport.uppercased()`)
- KEYBINDINGS section header (reuse `L.markdownHelpBindings`)
- Body text: `L.editingHelpCtrlE`
- Vim toggle: clickable NSButton with underline style
  - Text is dynamic: `L.editingHelpVimDisable` if `UserDefaults.standard.bool(forKey: "vimModeEnabled")` is true, otherwise `L.editingHelpVimEnable`
  - Action: `#selector(editingVimToggleClicked)`
  - Accessibility label: `L.vimStyleEditing`
- Dismiss label at bottom: reuse `makeDismissString()`
- Click gesture to dismiss: reuse `helpOverlayClicked` pattern
- No scroll view needed (content is short)

Layout:
```
┌──────────────────────────────────┐
│ ← Help                          │
│                                  │
│   EDITING                        │
│                                  │
│   KEYBINDINGS                    │
│                                  │
│   Press Ctrl+E on any clipboard  │
│   item to open the editor        │
│                                  │
│   Click here to enable           │
│   vim-style editing              │
│                                  │
│       Esc to close help          │
└──────────────────────────────────┘
```

Constraints:
- backButton: top 16, leading 24
- helpContent (NSTextField): top = backButton.bottom + 12, leading 60, trailing -60
- vimToggleButton: top = helpContent.bottom + 16, leading 60
- dismissLabel: centerX, bottom -24

## Step 5: Do NOT add to AppDelegate menu

The editing help screen is only reachable from the Power Features section of the main help screen. No menu item in the status bar right-click menu.

## Verification

1. `make build` — verify it compiles
2. `xcodebuild -scheme Freeboard -configuration Debug build-for-testing && xcodebuild -scheme Freeboard -configuration Debug test-without-building` — verify all 112 tests pass
3. Manual testing:
   - Open help (press `?`) → verify `[Help]` button label at bottom-right (not `[?]`)
   - Verify "POWER FEATURES" section shows both "Markdown Support →" and "Editing →"
   - Click "Editing →" → verify editing help screen opens with back button, title, keybinding, and vim toggle
   - Click vim toggle → verify text changes between enable/disable
   - Click "← Help" → verify returns to main help
   - Press Esc → verify help dismisses
   - Change language → verify all strings update
   - VoiceOver: verify help button has accessibility label, editing screen elements are navigable
