# Monaco Editor Restoration Plan

## Why We Removed Monaco

The WKWebView-based Monaco editor (commit 94021de) failed because `WKWebView.loadFileURL`
couldn't access the bundled MonacoEditor resources from within the hardened macOS sandbox.
The result was a blank transparent WKWebView, visible as a green rectangle through the
RetroEffectsView CRT effects.

## What Was Replaced

We replaced the WKWebView/Monaco approach with a native NSTextView in `MonacoEditorView.swift`.
The class name was kept to minimize changes in `ClipboardHistoryViewController.swift`.

## Current Architecture (Native NSTextView)

- `MonacoEditorView` wraps an `EditorTextView` (private NSTextView subclass) in an NSScrollView
- Key events flow through `EditorTextView.keyHandler` closure → `MonacoEditorView.handleKeyDown`
- Vim state machine: `.insert` / `.normal` / `.command` modes
- Block cursor in normal mode: `setNormalCursor(at:)` selects 1 char with bright green bg
- Status line at bottom shows mode indicator + shortcut hints
- `MonacoEditorDelegate` protocol unchanged: `editorDidSave(content:)`, `editorDidClose()`

## How to Restore Monaco (If Sandbox Issue Is Solved)

### The Sandbox Problem
`WKWebView.loadFileURL(htmlFile, allowingReadAccessTo: monacoDir)` fails because the
DerivedData build path is "outside the allowed root paths." This is a WKWebView security
restriction, not the app sandbox per se (debug entitlements don't even enable app sandbox).

### Possible Fixes
1. **Inline the HTML/JS**: Embed editor.html content as a string and use `webView.loadHTMLString()`
   instead of `loadFileURL`. Monaco JS (~745KB editor.main.js) would need to be base64-encoded
   or inlined. The `vs/` resource loading via AMD (`require.config`) would also need adjustment.

2. **Local HTTP server**: Spin up a lightweight localhost HTTP server (e.g., `GCDWebServer` or
   `NWListener`) serving the MonacoEditor directory, then load via `http://localhost:PORT/editor.html`.
   This sidesteps WKWebView file access restrictions entirely.

3. **WKURLSchemeHandler**: Register a custom URL scheme (e.g., `freeboard://`) and implement
   `WKURLSchemeHandler` to serve the bundled files. This is the Apple-recommended approach for
   loading local resources in WKWebView within sandboxed apps.

### Resources Still Bundled
The MonacoEditor directory is still in the project at:
- `Freeboard/Resources/MonacoEditor/editor.html` (363 lines, custom theme + vim mode in JS)
- `Freeboard/Resources/MonacoEditor/vs/` (loader.js, editor.main.js, language workers, etc.)

The `editor.html` contains:
- Custom "freeboard-dark" theme (green cursor, dark bg)
- Full vim mode implementation in JS (normal/insert/command modes, motions, jk exit)
- Monaco editor initialization with AMD require
- Swift↔JS bridge via `window.webkit.messageHandlers.editorBridge.postMessage()`
- `window.setContent(text, language, isVimEnabled)` / `window.getContent()` public API

### Integration Points (in ClipboardHistoryViewController.swift)
- `enterEditMode()` creates `MonacoEditorView`, adds below `effectsView`, hides other UI
- `exitEditMode()` removes editor, restores UI, calls `reloadEntries()`
- `editorDidSave(content:)` updates entry via `clipboardManager.updateEntryContent()`
- `editorDidClose()` calls `exitEditMode()` without saving
- Tab key handling at keyCode 48 (currently passes through; was save+close for Monaco)
- Esc at keyCode 53 triggers `triggerSaveAndClose()` as fallback

### What Monaco Gives Over Native NSTextView
- Syntax highlighting (JSON, XML, SQL, shell, Python, Swift, JS/TS, Markdown)
- Language-aware features (bracket matching, auto-indent)
- The `detectLanguage()` static method is retained and still called but currently unused
