# Agents Guide

Instructions for AI coding agents working on Freeboard.

Read [values.md](values.md) before making design decisions — it defines what Freeboard is and isn't.

## Build

```
make build     # Debug build
make run       # Build, kill existing instance, launch
make prod      # Release build, install to /Applications, launch
make clean     # Remove build artifacts
```

## Test

```
xcodebuild -project Freeboard.xcodeproj -scheme Freeboard -configuration Debug SYMROOT=$(pwd)/build build-for-testing
xcrun xctest build/Debug/FreeboardTests.xctest
```

Do NOT use `xcodebuild test` — it fails with terminal permission errors. Always use `xcrun xctest` directly on the built bundle.

## Architecture

Native macOS clipboard manager (Swift/AppKit, macOS 13+). Menu bar accessory app triggered by cmd-shift-c.

```
Freeboard/
  main.swift                           → App entry point
  AppDelegate.swift                    → Menu bar (NSStatusItem), popup lifecycle, paste simulation via CGEvent
  ClipboardManager.swift               → Polls NSPasteboard.general every 0.5s, stores last 50 entries, handles text/images/file URLs, OCR via Vision
  ClipboardEntry.swift                 → Data model (content, timestamp, password flag, expiration, type detection, markdown/code detection)
  ClipboardHistoryViewController.swift → NSTableView UI: search, keyboard nav (ctrl-n/p, vim bindings), selection, delete, rich paste modes
  GlobalHotkeyManager.swift            → Carbon RegisterEventHotKey for global shortcuts
  MonacoEditorView.swift               → WebKit view embedding Monaco editor for syntax highlighting via monaco-editor:// URL scheme
  PasswordDetector.swift               → Password heuristics, commit hash exclusion, Bitwarden ConcealedType marker
  FuzzySearch.swift                    → Character-order fuzzy matching with scoring
  PopupWindow.swift                    → Floating borderless NSPanel
  ScreenOverlayWindow.swift            → Darkened screen overlay behind popup
  RetroEffectsView.swift               → Static scanlines and vignette (mouse-transparent)
  Localization.swift                   → 10 languages (en/zh/hi/es/fr/ar/bn/pt/ru/ja), language persisted in UserDefaults
  Resources/MonacoEditor/              → Monaco editor HTML + VS language definitions
```

## Conventions

- **No disk storage.** Everything in memory. UserDefaults only for settings (hotkey, language).
- **No network.** Zero internet, zero API calls.
- **No external dependencies.** Pure native macOS (AppKit, WebKit, Vision, Carbon, ServiceManagement). No CocoaPods/SPM.
- **Testability.** Core logic uses `PasteboardProviding` protocol for mock injection. Tests use `MockPasteboard`.
- **End-to-end tests only.** No unit tests for trivial getters. Test full flows.
- **Xcode project.** Hand-written `project.pbxproj`. When adding files, add both a `PBXFileReference` and a `PBXBuildFile` entry. Test sources compile app source files directly (no `@testable import`).
- **Commit style.** `wip: [description] - builds/tests pass/etc`. Never amend.
- **Makefile.** Use `make build`, `make run`, `make prod`, `make clean`.
- follow our values!! ./values.md
