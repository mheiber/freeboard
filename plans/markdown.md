# Markdown & Rich Text Conversion Plan

## One-Sentence Summary

**Shift+Enter converts between markdown and rich text when pasting.**

## Problem

Users copy markdown from editors and want to paste it as formatted rich text (into Slack, email, Notion). Users also copy rich text and want the markdown source. Currently, Shift+Enter only strips to plain text — it doesn't convert between formats.

## Entry Classification

Every text entry falls into one of four categories:

| | Has rich pasteboard data (RTF/HTML) | No rich pasteboard data |
|---|---|---|
| **Looks like markdown** | C: Rich Markdown | B: Plain Markdown |
| **Not markdown** | A: Rich Text | D: Plain Text |

Detection uses two existing signals:
1. Check `entry.pasteboardData` for `.rtf` or `.html` keys (binary, no heuristics)
2. Use `MonacoEditorView.detectLanguage()` markdown scoring (threshold >= 3 for paste conversion)

## Paste Behavior Matrix

| Category | Enter | Shift+Enter |
|---|---|---|
| A: Rich Text | Paste with formatting (existing) | Paste as plain text (existing) |
| B: Plain Markdown | Paste as plain text (existing) | **Convert to rich text, paste** |
| C: Rich Markdown | Paste with formatting (existing) | Paste as plain markdown source (existing) |
| D: Plain Text | Paste as plain text (existing) | Paste as plain text (existing, no-op) |

**Key insight:** Enter never changes. Shift+Enter means "the other format."

## Dynamic Help Bar

The help bar updates based on the selected entry's category:

- Category A: `Enter paste  ⇧ plain`
- Category B: `Enter paste  ⇧ rich`
- Category C: `Enter paste  ⇧ markdown`
- Category D: `Enter paste` (no shift hint)

## Values Alignment

- **Keyboard-first:** No new key bindings. Extends existing Shift+Enter.
- **Simplicity:** One-sentence explanation. Enter never changes behavior.
- **Instant:** Conversion at paste time, no extra steps.
- **Privacy:** All conversion in-memory, no network.
- **One window:** No new UI, just a dynamic help bar label.
- **Accessible:** VoiceOver labels updated, help bar announced.

## Implementation Phases

### Phase 1: Classification & Dynamic Help Bar (commit 1)

Add format classification to entries and make the help bar dynamic.

**Files changed:**
- `ClipboardEntry.swift` — Add `FormatCategory` enum and computed property
- `ClipboardHistoryViewController.swift` — Update `makeHelpString()` to accept entry
- `Localization.swift` — Add "plain", "rich", "markdown" localization keys

### Phase 2: Markdown-to-Rich-Text Conversion (commit 2)

Add the ability to convert markdown to HTML and paste as rich text.

**Files changed:**
- `ClipboardManager.swift` — Add `selectEntryAsRenderedMarkdown()` method
- `ClipboardHistoryViewController.swift` — Route Shift+Enter through classification

### Phase 3: Update Delegate Protocol (commit 3)

Wire up the full paste flow through the delegate.

**Files changed:**
- `ClipboardHistoryViewController.swift` — Update delegate calls for smart paste
- `AppDelegate.swift` — Handle new delegate method

### Phase 4: Tests (commit 4)

Comprehensive tests for classification, conversion, and paste routing.

**Files changed:**
- `FreeboardTests/MarkdownConversionTests.swift` — New test file
- `FreeboardTests/ClipboardManagerTests.swift` — Additional rich text tests

### Phase 5: VoiceOver & Accessibility (commit 5)

Update accessibility labels to communicate format category.

**Files changed:**
- `ClipboardHistoryViewController.swift` — Update cell accessibility labels
- `Localization.swift` — Add accessible format descriptions

## Deferred (Phase 2 of Feature — Not in This Plan)

- Editor conversion: editing rich text as markdown in Monaco
- Bundling Turndown.js/marked.js for HTML↔Markdown round-trip
- Visual indicator in list view for conversion-available entries

## Risks & Mitigations

1. **False positive markdown detection:** Use threshold >= 3 (stricter than Monaco's >= 2). Help bar previews what Shift will do, so user is never surprised.
2. **Markdown-to-HTML quality:** Start with NSAttributedString-based conversion (built-in). Upgrade to JS library later if needed.
3. **Enter behavior unchanged:** The default paste path is never affected. All risk is isolated to the Shift path.
