# Plan: UI Integration Testing

## Problem

Unit tests can't catch UI-level issues like "Monaco editor opens but shows blank." We need automated tests that exercise the real UI: render views, verify visible content, detect blank screens.

## Approach: XCUITest (Xcode UI Testing)

macOS supports XCUITest for automated UI testing. This lets us:
- Launch the real app in a test harness
- Simulate keyboard/mouse events (Cmd+Shift+C to open, type text, Ctrl+E to edit)
- Query the accessibility tree to verify elements are visible and have expected content
- Take screenshots for visual regression

### What to test

1. **Basic flow**: Open popup, verify table view has content, verify search field exists
2. **Edit mode**: Select entry, Ctrl+E, verify editor view appears and has non-empty content
3. **Image expand**: Copy image, Tab to expand, verify image view dimensions are large
4. **Keyboard shortcuts**: Tab expand/collapse, Esc close, number keys quick-paste
5. **Empty state**: Launch with no clipboard history, verify empty hint text shows

### Implementation

1. Add a `FreeboardUITests` target to the Xcode project
2. Use `XCUIApplication` to launch the app
3. Use `XCUIElement` queries on accessibility labels (we already have good labels)
4. Assert element existence, visibility, and content

### Example test skeleton

```swift
func testEditorOpensWithContent() throws {
    let app = XCUIApplication()
    app.launch()
    // Simulate opening popup (via accessibility API or menu bar click)
    // Copy some text to clipboard first
    // Verify table has entries
    // Select first entry, press Ctrl+E
    // Verify Monaco editor view exists and is visible
    // Verify editor is not empty (accessibility check or screenshot comparison)
}
```

### Limitations

- XCUITest requires the app to be code-signed and have accessibility permissions
- Can't easily test WKWebView content (Monaco) via accessibility tree — may need screenshot comparison
- Test environment needs clipboard access
- Tests are slower than unit tests

### Alternative: Snapshot testing

For WKWebView content specifically, we could:
- In debug builds, add a JS bridge that reports editor state (has content, cursor position)
- The Swift test can query this bridge to verify the editor loaded and has content
- This avoids relying on accessibility tree for WKWebView internals

### Minimum viable version

Add one XCUITest that:
1. Launches the app
2. Puts text on the clipboard
3. Opens Freeboard
4. Verifies the clipboard entry is visible
5. Presses Ctrl+E
6. Verifies the editor view is present (not just a blank container)

This single test would have caught the blank editor bug.
