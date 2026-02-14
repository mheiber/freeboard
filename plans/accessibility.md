# Accessibility Review: Freeboard

## Context

Freeboard is a macOS menu bar clipboard manager built with AppKit. It has a retro CRT aesthetic (green-on-black, scanlines, screen cracks). The UI consists of a popup window with a search field, table view of clipboard entries, and various interactive elements (star, delete, edit, expand). The app currently has good keyboard navigation but almost no VoiceOver/screen reader support.

---

## Findings

### 1. VoiceOver / Screen Reader Support (Critical)

**No accessibility labels or roles anywhere.** VoiceOver users cannot use this app.

Files affected: `ClipboardHistoryViewController.swift`, `AppDelegate.swift`

Specific issues:

- **Table view rows** (`tableView(_:viewFor:row:)`, line 441): Each row is a plain `NSView` built from scratch every render. No `setAccessibilityLabel`, `setAccessibilityRole`, or `setAccessibilityRoleDescription`. VoiceOver will see an opaque, unlabeled view.

- **Star indicator button** (line 466): `NSButton(title: "★"/"☆"/">"/..." )` — the title is a symbol character. VoiceOver will read "black star" or "greater than sign" instead of "Starred" / "Star this entry". Needs `setAccessibilityLabel("Star")` or `setAccessibilityLabel("Starred")` depending on state.

- **Delete button** (line 498): `NSButton(title: "×")` — VoiceOver will read "multiplication sign". Needs `setAccessibilityLabel("Delete")`.

- **Number labels** (line 477): `NSTextField(labelWithString: "[1]")` — VoiceOver will read "open bracket one close bracket". Needs `setAccessibilityLabel("Quick select 1")` or should be marked as `setAccessibilityElement(false)` (decorative).

- **Content labels** (line 565): No accessibility description distinguishing password-masked entries from normal ones. A masked entry shows "********" with no context.

- **Time labels** (line 489): `"5m ago"` is fine for sighted users but VoiceOver should read "5 minutes ago". The abbreviated format may confuse screen readers.

- **Search field** (line 134): Has a placeholder but no `setAccessibilityLabel`. The placeholder contains a cursor character "▌" that VoiceOver will try to read.

- **Help label** (line 204): Keyboard shortcut hints at the bottom — no structured accessibility. VoiceOver will read the raw text but it won't be navigable as individual shortcuts.

- **Quit button** (line 214): No accessibility label beyond the title text (which is fine, "Quit" is descriptive).

- **Empty state view** (line 244): ASCII art and hint labels have no accessibility descriptions. VoiceOver will attempt to read the ASCII art character by character.

- **Clear search button** (line 286): Title is "Clear Search (Esc)" which is acceptable.

### 2. Color Contrast (Moderate)

- **Unselected row text**: `retroDimGreen` (`rgb(0, 0.6, 0.15)` = `#009926`) on `retroBg` (`rgb(0.02, 0.02, 0.02)` ≈ `#050505`). Contrast ratio ≈ 4.0:1. **Fails WCAG AA** for normal text (requires 4.5:1). Passes for large text.

- **Help text at bottom**: `retroDimGreen.withAlphaComponent(0.4)` — very dim green on near-black. Estimated contrast ≈ 1.8:1. **Fails WCAG AA and AAA**.

- **Time labels**: `retroDimGreen.withAlphaComponent(0.4)` — same issue as help text.

- **Placeholder text**: `retroDimGreen.withAlphaComponent(0.5)` on dark background. Estimated contrast ≈ 2.2:1. **Fails WCAG AA**. (Placeholders are exempt from WCAG technically, but low contrast still hurts usability.)

- **Number labels `[1]`**: `retroGreen.withAlphaComponent(0.7)` — better but still marginal.

- **Empty state hotkey label**: `retroDimGreen.withAlphaComponent(0.35)` — extremely low contrast.

### 3. Keyboard Navigation (Good, with gaps)

Strengths:
- Number keys 1-9 for quick select
- Ctrl+N/P and arrow keys for navigation
- Tab for expand, Ctrl+E for edit, Cmd+S for star
- Esc for dismiss/clear
- Type-ahead search

Gaps:
- **Delete button is mouse-only.** There is no keyboard shortcut to delete an entry. The `×` button requires a mouse click (`deleteClicked` at line 644). Cmd+D should delete the selected entry. (Delete/Backspace key is unsuitable because it conflicts with the type-ahead search functionality.)
- **No focus ring visible.** `searchField.focusRingType = .none` (line 142) disables the standard macOS focus indicator. The custom selection highlight (green background) partially compensates for table rows, but the search field has no visible focus state.
- **Star button is mouse-only for non-selected rows.** Cmd+S only stars the *selected* row. The clickable star indicator on hover requires a mouse.

### 4. Reduce Motion / Reduce Transparency (Not Supported)

- **No `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` check.** The app doesn't have animations currently, but the CRT effects (scanlines, vignette, screen cracks) are purely visual and could be distracting. Users with `Reduce Transparency` enabled might expect the overlay dimming and retro effects to be toned down.

- **No `accessibilityDisplayShouldReduceTransparency` check.** The popup background is semi-transparent (`alpha: 0.88`). Users who enable Reduce Transparency in System Settings expect opaque backgrounds.

### 5. Increase Contrast (Not Supported)

- **No `accessibilityDisplayShouldIncreaseContrast` check.** macOS has a system-wide "Increase Contrast" setting. The app should respond by boosting the dim green colors to full brightness.

### 6. Dynamic Type / Text Size (Not Supported)

- All font sizes are hardcoded (16pt, 12pt, 14pt, etc.). macOS supports dynamic text sizing. Users who set larger text in System Settings > Accessibility > Display > Text Size won't see any change in Freeboard.

### 7. Window and Panel Accessibility

- **PopupWindow** (line 3): `NSPanel` with `nonactivatingPanel` style. This can cause issues with VoiceOver focus — VoiceOver may not automatically focus the panel when it appears. Should post `NSAccessibility.Notification.windowCreated` or similar.

- **ScreenOverlayWindow** (line 5): `ignoresMouseEvents = true` — good, but has no accessibility role set. It should be marked as decorative (`setAccessibilityRole(.unknown)` or hidden from accessibility tree).

### 8. Status Bar Item

- Status bar button uses `[F]` as its title (line 34). This is acceptable but could benefit from `setAccessibilityLabel("Freeboard clipboard manager")` to give VoiceOver users more context.

### 9. Right-Click Context Menu

- The right-click menu on the status item (`showStatusMenu`, line 92) is built with standard `NSMenu`/`NSMenuItem` which are inherently accessible. This is fine.

---

## Recommended Changes (Priority Order)

### P0 — VoiceOver basics

**File: `ClipboardHistoryViewController.swift`**

1. **Add accessibility labels to table row elements** in `tableView(_:viewFor:row:)`:
   - Star button: `indicator.setAccessibilityLabel(entry.isStarred ? "Starred" : "Star")`
   - Delete button: `deleteButton.setAccessibilityLabel("Delete clipboard entry")`
   - Content label: `contentLabel.setAccessibilityLabel(entry.isPassword ? "Password (hidden)" : entry.content)`
   - Number label: `nl.setAccessibilityElement(false)` (decorative, shortcut info conveyed elsewhere)
   - Time label: provide full text via `setAccessibilityLabel` (e.g., "5 minutes ago" instead of "5m ago")

2. **Set accessibility role on row cells**: `cell.setAccessibilityRole(.row)` and `cell.setAccessibilityRoleDescription("clipboard entry")`

3. **ASCII art in empty state**: `asciiLabel.setAccessibilityElement(false)` — it's decorative

4. **Search field**: `searchField.setAccessibilityLabel("Search clipboard history")`

5. **RetroEffectsView and CrackedOverlayView**: Already return `nil` from `hitTest` — also add `setAccessibilityElement(false)` to hide from VoiceOver tree

**File: `AppDelegate.swift`**

6. **Status bar button**: `button.setAccessibilityLabel("Freeboard")`

### P1 — Keyboard accessibility

**File: `ClipboardHistoryViewController.swift`**

7. **Add Cmd+D shortcut** to delete the selected entry. Add handling in the local key monitor (alongside Cmd+S) and in `keyDown(with:)`. Also **add "⌘D delete"** to the help hint bar in `makeHelpString()` and update the `L` struct in `Localization.swift` with a `delete` string.

8. **Restore focus ring** on search field (remove `focusRingType = .none` or add a custom visible focus indicator)

### P2 — System accessibility settings

**File: `ClipboardHistoryViewController.swift`**

9. **Respond to Increase Contrast**: Check `NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast` and boost dim alpha values (0.4 → 1.0, 0.5 → 1.0, etc.)

10. **Respond to Reduce Transparency**: Check `NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency` and make `retroBg` fully opaque

**File: `RetroEffectsView.swift`, `ScreenOverlayWindow.swift`**

11. **Respond to Reduce Motion/Transparency**: Disable CRT effects and screen crack overlay when reduce-motion or reduce-transparency is enabled

### P3 — Color contrast

12. **Boost `retroDimGreen` base brightness** from `(0, 0.6, 0.15)` to at least `(0, 0.75, 0.19)` to meet WCAG AA 4.5:1 on the dark background
13. **Raise minimum alpha** on dim text from 0.4 to 0.6 for help text and time labels

### P4 — Localized accessibility

**File: `ClipboardEntry.swift`**

14. **Add `accessibleTimeAgo` property** that returns unabbreviated strings ("5 minutes ago" vs "5m ago") for use in accessibility labels

---

## Verification

1. **Build the app** — `make build` or Xcode build
2. **Run tests** — `make test` or `./test.sh`
3. **Manual VoiceOver testing**:
   - Enable VoiceOver (Cmd+F5)
   - Open Freeboard popup via hotkey
   - Navigate table with VO+arrows — verify each row announces content, star state, and time
   - Verify search field is announced as "Search clipboard history"
   - Verify delete and star buttons are announced with meaningful labels
   - Verify empty state announces hint text, not ASCII art
4. **Accessibility Inspector** (Xcode > Open Developer Tool > Accessibility Inspector):
   - Point at each UI element and verify roles/labels are set
   - Run the audit feature to catch remaining issues
5. **System settings checks**:
   - Enable Increase Contrast — verify dim text gets brighter
   - Enable Reduce Transparency — verify background becomes opaque
   - Enable Reduce Motion — verify CRT effects are disabled
