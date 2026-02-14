# Themes Feature Implementation Plan

## Context

Freeboard currently has a single hardcoded retro-green terminal theme. Colors are defined as four `private let` properties in `ClipboardHistoryViewController.swift:40-43` and used ~30 times across that file. We want to extract these into a theme system supporting four themes: **Retro Green** (current default), **Synth Wave** (matching ~/superhoarse), **Ayu Light**, and **Notepad**. The screen crack effect (`ScreenOverlayWindow.swift`) stays independent of themes.

## Files to Create

### `Freeboard/Theme.swift` — Theme struct + four static definitions

A `Theme` struct with these color slots (derived from auditing every color reference in `ClipboardHistoryViewController.swift`):

| Property | Current value | Used at |
|---|---|---|
| `windowBackground` | `retroBg` (0.02, 0.02, 0.02, 0.88) | line 61 |
| `windowBorderColor` | `retroGreen @ 0.3 alpha` | line 63 |
| `windowGlowColor` | `retroGreen @ 0.6 alpha` | line 67 |
| `windowGlowRadius: CGFloat` | `15` | line 68 |
| `primaryColor` | `retroGreen` (0, 1, 0.25) | lines 145, 320, 354, 449, 529, 539, 574, 576, 627 |
| `secondaryColor` | `retroDimGreen` (0, 0.6, 0.15) | lines 126, 154, 267, 278, 331, 340, 350, 453, 551, 561, 627 |
| `selectionBackground` | `retroSelectionBg` (0, 0.2, 0.05, 0.9) | line 510 |
| `searchFieldBackground` | hardcoded (0.05, 0.05, 0.05, 0.85) | line 146 |
| `editBackground` | hardcoded (0.05, 0.08, 0.05, 0.9) | line 575 |
| `showRetroEffects: Bool` | `true` (implicit) | controls `effectsView.isHidden` |

Plus `name: String` (display name), `key: String` (UserDefaults persistence).

Four static themes: `.retroGreen`, `.synthWave`, `.ayuLight`, `.notepad`, plus `static let allThemes: [Theme]`.

**Theme color palettes:**

- **Retro Green**: Current values unchanged
- **Synth Wave**: Deep purple background (0.08, 0, 0.18, 0.92), magenta primary (1, 0, 1), cyan secondary (0, 0.8, 1), magenta glow/border — from ~/superhoarse. `showRetroEffects: true`
- **Ayu Light**: Warm cream background (0.98, 0.97, 0.95), charcoal primary (0.24, 0.24, 0.26), gray secondary (0.55, 0.55, 0.57), light blue selection, subtle shadow. `showRetroEffects: false`
- **Notepad**: White background, black primary, dark gray secondary, blue selection highlight, minimal shadow. `showRetroEffects: false`

### `Freeboard/ThemeManager.swift` — Persistence singleton

Follows the exact pattern of `HotkeyChoice.current` in `Localization.swift:27-40`: a `static var current` with get/set backed by `UserDefaults.standard` using key `"freeboard_theme"`. Falls back to `.retroGreen` if key is missing or invalid.

### `FreeboardTests/ThemeTests.swift` — Tests

Tests following existing patterns in `EmptyStateTests.swift` and `ClipboardManagerTests.swift`:
- All themes have unique keys and unique names
- Four themes exist in `allThemes`
- Default is retro green when no UserDefaults key set
- Persistence round-trips for all themes
- Invalid key falls back to default
- Missing key falls back to default
- Dark themes have `showRetroEffects: true`, light themes have `false`
- Theme equality is by key

## Files to Modify

### `Freeboard/ClipboardHistoryViewController.swift`

1. **Remove** lines 40-43 (the four hardcoded color `let` properties)
2. **Add** `private var theme: Theme { ThemeManager.shared.current }`
3. **Replace** all ~30 color references: `retroGreen` → `theme.primaryColor`, `retroDimGreen` → `theme.secondaryColor`, `retroBg` → `theme.windowBackground`, `retroSelectionBg` → `theme.selectionBackground`, plus the two hardcoded `NSColor(red:...)` for search/edit backgrounds → `theme.searchFieldBackground` / `theme.editBackground`
4. **Add** `applyTheme()` private method that updates container chrome, search field, help label, quit button, empty state colors, and sets `effectsView.isHidden = !theme.showRetroEffects`, then reloads table
5. **Add** `refreshTheme()` public method that calls `applyTheme()` — called by AppDelegate on theme switch
6. **Not touched**: accessibility banner colors (lines 175, 181) stay hardcoded for accessibility contrast

### `Freeboard/AppDelegate.swift`

Add a "Theme" submenu in `showStatusMenu()` after the Shortcut submenu (line 157), following the identical pattern of the Language/Shortcut submenus:
- Loop over `Theme.allThemes`, create menu items with `.on` state for current theme
- `@objc func switchTheme(_:)` handler sets `ThemeManager.shared.current` and calls `historyVC.refreshTheme()`

### `Freeboard.xcodeproj/project.pbxproj`

Add PBXFileReference, PBXBuildFile, PBXGroup children, and PBXSourcesBuildPhase entries for Theme.swift, ThemeManager.swift (both targets), and ThemeTests.swift (test target only). Follow existing ID numbering convention.

## Implementation Steps

1. Create `Theme.swift` with struct and four theme definitions. Update pbxproj. Build.
2. Create `ThemeManager.swift` with persistence. Update pbxproj. Build.
3. Create `ThemeTests.swift`. Update pbxproj. Run tests.
4. Refactor `ClipboardHistoryViewController.swift` — remove hardcoded colors, use `theme.*`, add `applyTheme()`/`refreshTheme()`. Build. App should look identical (default = retro green).
5. Add theme submenu to `AppDelegate.swift`. Build. Manually test switching.
6. Full test pass.

## What Stays Unchanged

- `ScreenOverlayWindow.swift` — crack effect is theme-independent
- `RetroEffectsView.swift` — no code changes; visibility controlled by `theme.showRetroEffects` from the view controller
- Accessibility banner colors — hardcoded for contrast
- Fonts — all themes use Menlo (existing `retroFont` computed property)

## Verification

1. `xcodebuild test` — all existing + new ThemeTests pass
2. Launch app → default theme looks identical to current
3. Right-click status bar → Theme submenu appears with 4 options, current has checkmark
4. Switch to each theme → colors update immediately, scanlines/vignette hidden for light themes
5. Quit and relaunch → selected theme persists
6. Screen cracks visible on all themes
