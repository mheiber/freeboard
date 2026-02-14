# Plan: Programmer-Friendly Text Editor (Ctrl+E)

## Description

Replace the current text editing experience (Ctrl+E) with a Monaco-based editor. The editor should feel natural to programmers: no line numbers, efficient use of screen real estate (as large as possible without exceeding the window), a familiar dark theme, and auto-detected syntax highlighting. The editor uses a two-stage exit: first Esc (or `jk`) exits to normal mode within the editor, second Esc (or `:w<Enter>`) saves and closes editing. Vim keybindings are off by default but can be enabled via right-click on the menu bar icon > "Vim-style editing".

## Why it fits the values

- **Keyboard-first**: `jk` and Esc for mode transitions mirror terminal muscle memory. Two-stage exit (normal mode, then close) prevents accidental data loss without adding confirmation dialogs.
- **Terminal Power**: Monaco with a dark theme and syntax highlighting gives programmers the editing environment they expect. No chrome, no toolbar — just code.
- **Simplicity over features**: No settings panel needed. The only toggle (vim mode) lives in the existing right-click menu. Auto-detect syntax highlighting means zero configuration.
- **One window, one purpose**: The editor replaces the entry row in-place. No new windows or panels.
- **Efficient screen real estate**: Editor fills as much of the popup window as possible, unlike the current small editing area.

## Behavior

### Opening
- Ctrl+E on a text entry opens the Monaco editor in-place, taking up as much space as possible within the window.

### Editing
- Syntax highlighting auto-detected from content (JSON, XML, SQL, shell scripts, code snippets, plain text fallback).
- No line numbers displayed.
- Familiar dark theme (VS Code Dark+ or similar).
- Editor fills available window space — maximize height and width without going outside the popup bounds.

### Exiting
1. **First Esc** (or typing `jk` in insert mode): Enters normal mode within the editor. Cursor changes to block. Movement keys work (`h`, `j`, `k`, `l`, `w`, `b`, etc.) but only if vim mode is enabled. If vim mode is disabled, first Esc saves and closes immediately.
2. **Second Esc** (or `:w<Enter>` in normal mode): Saves content back to the clipboard entry and closes the editor. Returns to the normal list view.

### Vim mode toggle
- Right-click the Freeboard menu bar icon.
- Menu item: "Vim-style editing" with a checkmark when enabled.
- When disabled (default): standard editor keybindings. Single Esc saves and closes.
- When enabled: vim keybindings active. `jk` exits insert mode. Two-stage Esc. `:w<Enter>` saves and closes.
- Preference stored in UserDefaults (acceptable since it's a UI preference, not user data).

## Implementation approach

### Monaco integration
- Use WKWebView to host Monaco editor.
- Bundle a minimal Monaco HTML/JS page in the app resources.
- Communicate between Swift and Monaco via `WKScriptMessageHandler` (Swift → JS for setting content/theme/language, JS → Swift for save/close events).

### Editor sizing
- When editing, collapse other rows and expand the editor cell to fill available window height minus minimal padding.
- Width fills the popup width minus standard margins.

### Syntax detection
- Inspect content for common patterns:
  - Starts with `{` or `[` → JSON
  - Starts with `<` → XML/HTML
  - Contains `SELECT`, `INSERT`, `CREATE TABLE` → SQL
  - Starts with `#!/bin/` or contains common shell patterns → Shell
  - Contains `def `, `import `, `class ` → Python
  - Contains `func `, `let `, `var ` with Swift patterns → Swift
  - Contains `function`, `const`, `=>` → JavaScript/TypeScript
  - Fallback → plain text

### Menu bar integration
- Add "Vim-style editing" item to the existing right-click context menu on the status bar icon.
- Use `NSMenuItem` with `state = .on/.off` for checkmark.
- Store preference in `UserDefaults.standard` under key `"vimModeEnabled"`.

## Testing

1. **Manual test**:
   - Copy a JSON snippet, Ctrl+E, verify syntax highlighting and no line numbers.
   - Copy plain text, Ctrl+E, verify editor opens large and fills available space.
   - Press Esc with vim mode off — verify editor saves and closes immediately.
   - Enable vim mode via right-click menu, Ctrl+E, type text, type `jk` — verify enters normal mode. Press Esc — verify saves and closes.
   - Type `:w<Enter>` in normal mode — verify saves and closes.
2. **Edge cases**:
   - Very long text (10k+ characters) — verify editor handles without lag.
   - Empty text entry — verify editor opens with empty content, can type and save.
   - Binary-looking content — verify falls back to plain text highlighting.
3. **VoiceOver**: Verify the editor is announced and content is accessible.
4. **Vim mode persistence**: Enable vim mode, quit app, relaunch — verify vim mode is still enabled.
