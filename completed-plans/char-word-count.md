# Plan: Character and Word Count on Expand

## Description

When an entry is expanded (via `Tab`), show a character count and word count at the bottom-right of the expanded row. Displayed in dim green text, like `142 chars  28 words` or `142c 28w` for compactness. For image entries, show image dimensions instead (e.g., `1920x1080`). For file entries, show file size if available (e.g., `2.4 MB`).

## Why it fits the values

- **Terminal soul**: Character counts are a terminal staple (`wc -c`, `wc -w`). Displaying them in the same dim green as timestamps feels native to the aesthetic.
- **Simplicity over features**: No interaction, no configuration. The information appears when you expand and disappears when you collapse. Zero cognitive overhead.
- **Keyboard-first**: Triggered by the existing `Tab` expand action. No new shortcuts needed.
- **One window, one purpose**: No new windows or overlays. Just a small text label within the existing expanded row.

## Use cases

- Developer checking if a string fits a length limit (API field, database column, tweet/post).
- Writer checking word count of a copied paragraph.
- Designer checking screenshot dimensions before sharing.
- Anyone checking file size before attaching.

## Implementation approach

### ClipboardHistoryViewController.swift

In `tableView(_:viewFor:row:)`, when `isExpanded` is true and `!isEditing`, add a stats label:

```swift
if isExpanded && !isEditing {
    let statsText: String
    switch entry.entryType {
    case .text:
        let charCount = entry.content.count
        let wordCount = entry.content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
        statsText = "\(charCount)c \(wordCount)w"
    case .image:
        if let data = entry.imageData, let image = NSImage(data: data) {
            let w = Int(image.size.width)
            let h = Int(image.size.height)
            statsText = "\(w)x\(h)"
        } else {
            statsText = ""
        }
    case .fileURL:
        if let url = entry.fileURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? UInt64 {
            statsText = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        } else {
            statsText = ""
        }
    }

    if !statsText.isEmpty {
        let statsLabel = NSTextField(labelWithString: statsText)
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = retroFontSmall
        statsLabel.textColor = retroDimGreen.withAlphaComponent(0.4)
        statsLabel.backgroundColor = .clear
        statsLabel.isBezeled = false
        statsLabel.alignment = .right
        statsLabel.setAccessibilityLabel(statsText)
        cell.addSubview(statsLabel)

        NSLayoutConstraint.activate([
            statsLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -6),
            statsLabel.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -4),
        ])
    }
}
```

### Accessibility

The stats label gets an accessibility label so VoiceOver reads "142 characters, 28 words" instead of "142c 28w":
```swift
// For text:
statsLabel.setAccessibilityLabel("\(charCount) characters, \(wordCount) words")
// For image:
statsLabel.setAccessibilityLabel("\(w) by \(h) pixels")
// For file:
statsLabel.setAccessibilityLabel(statsText) // ByteCountFormatter already produces accessible text
```

## Testing

1. Manual test:
   - Copy a paragraph of text, open Freeboard, press Tab to expand, verify char/word count appears.
   - Copy a screenshot, expand, verify dimensions appear.
   - Copy a file, expand, verify file size appears.
   - Collapse (Tab again), verify the stats label disappears.
2. VoiceOver: Navigate to expanded entry, verify stats are read aloud in accessible format.
3. Edge cases:
   - Empty text entry (0c 0w) -- should still display.
   - Very long text (100000c 15000w) -- verify label does not overflow.
   - File that no longer exists -- verify no crash, no stats shown.
