# Plan: Smarter Deduplication

## Description

Improve clipboard entry deduplication so that trivially different copies do not create duplicate entries. Currently, deduplication is exact-match only: the content string must be byte-for-byte identical. This plan adds normalization for common cases where the "same" content appears with minor variations.

## Why it fits the values

- **Simplicity over features**: This is invisible to the user. No new UI, no new shortcuts, no settings. The clipboard history just has less noise.
- **Instant and ephemeral**: Fewer duplicate entries means the 50-item history holds more useful content, extending the effective memory of the clipboard.
- **Privacy by architecture**: No data leaves the app. 

## What to normalize


DO NOT NORMALIZE ANYTHING. prioritize simplicity and predictability


## Implementation approach

### ClipboardManager.swift

Add a normalization function:
```swift
private func normalizedForDedup(_ text: String) -> String {
    // Strip trailing whitespace and newlines only
    var s = text
    while s.last?.isWhitespace == true || s.last?.isNewline == true {
        s.removeLast()
    }
    return s
}
```

Modify `checkForChanges()` text deduplication:
```swift
// Current:
entries.removeAll { $0.content == content && $0.entryType == .text }

// New:
let normalizedContent = normalizedForDedup(content)
let wasStarred = entries.first(where: {
    $0.entryType == .text && normalizedForDedup($0.content) == normalizedContent
})?.isStarred ?? false
entries.removeAll {
    $0.entryType == .text && normalizedForDedup($0.content) == normalizedContent
}
```

Store the original content (not the normalized version) in the entry, so paste-back preserves exactly what was copied.

## Testing

1. Add tests in `ClipboardManagerTests.swift`:
   - Copy `"hello"`, then copy `"hello\n"` -- verify only one entry exists.
   - Copy `"hello"`, then copy `"hello  \n\n"` -- verify only one entry exists.
   - Copy `"hello"`, then copy `"  hello"` -- verify TWO entries exist (leading whitespace preserved).
   - Copy `"hello"`, then copy `"Hello"` -- verify TWO entries exist (case preserved).
   - Verify the stored content is the most recent copy (not the original).
   - Verify starred status is preserved across dedup.
2. Manual test: Copy the same text with and without trailing newlines from a terminal, verify Freeboard does not show duplicates.
