In help, add an entry for Settings.
It just says settings are now open in the menu bar context menu and an arrow is drawn on the screen pointing toward where that is.

## Implementation (2026-02-14)

Done. Added:

1. **"Settings ->" link** in the POWER FEATURES section of the help screen (alongside Markdown Support and Editing)
2. **Settings help sub-screen** that shows:
   - Title: "SETTINGS"
   - Instructions: "Right-click the [F] menu bar icon"
   - Available settings: "Language, keyboard shortcut, launch at login, vim mode"
   - A `[F]` label styled in the center as a visual reminder
3. **Arrow overlay window** (`SettingsArrowView`) that draws a dashed line with arrowhead from the top of the popup window up toward the `[F]` status item in the menu bar. The arrow:
   - Tries to find the actual status item window by scanning `NSApp.windows` for a status bar button containing "F"
   - Falls back to an approximate position in the top-right area of the screen if not found
   - Renders as a dashed green line with a filled arrowhead
   - Only appears when viewing the Settings help sub-screen
   - Is dismissed when leaving the settings help screen
4. **Localization** in all 10 languages (en, zh, hi, es, fr, ar, bn, pt, ru, ja)

### Arrow approach notes

The `findStatusItemWindow()` method searches through `NSApp.windows` for the status item's
window. Since `NSStatusItem` doesn't directly expose its window to other parts of the app,
this heuristic-based search may not always find it (e.g., on some macOS versions the status
item button may not be enumerable through `NSApp.windows`). The fallback places the arrow
target at an approximate position near the top-right of the screen, which is where status
items typically appear.
