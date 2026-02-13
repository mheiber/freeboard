# Agents Guide

Instructions for AI coding agents working on Freeboard.

## Build

```
make build
```

Or directly:

```
xcodebuild -project Freeboard.xcodeproj -scheme Freeboard -configuration Debug SYMROOT=$(pwd)/build build
```

## Test

```
xcodebuild -project Freeboard.xcodeproj -scheme Freeboard -configuration Debug SYMROOT=$(pwd)/build build-for-testing
xcrun xctest build/Debug/FreeboardTests.xctest
```

`xcodebuild test` may fail with terminal permission errors — use `xcrun xctest` directly on the built bundle.

## Architecture

```
Freeboard/
  main.swift                         → App entry point
  AppDelegate.swift                  → Menu bar setup, popup lifecycle, paste simulation
  ClipboardManager.swift             → Pasteboard polling, history storage, expiry
  ClipboardEntry.swift               → Data model (content, timestamp, password flag)
  PasswordDetector.swift             → Password heuristics, commit hash exclusion, Bitwarden
  FuzzySearch.swift                  → Character-order fuzzy matching with scoring
  GlobalHotkeyManager.swift          → cmd-shift-v via Carbon RegisterEventHotKey
  PopupWindow.swift                  → Floating borderless panel
  ClipboardHistoryViewController.swift → Table view, search, keyboard nav, delete
  RetroEffectsView.swift             → Static scanlines and vignette (mouse-transparent)
  Localization.swift                 → Bilingual strings (en/zh), time-based default
```

## Conventions

- **No disk storage.** Everything in memory. No UserDefaults, no files, no CoreData.
- **No network.** Zero internet, zero API calls.
- **Testability.** Core logic uses `PasteboardProviding` protocol for mock injection. Tests use `MockPasteboard`.
- **End-to-end tests only.** No unit tests for trivial getters. Test full flows.
- **Xcode project.** Hand-written `project.pbxproj`. When adding files, add both a `PBXFileReference` and a `PBXBuildFile` entry. Test sources compile app source files directly (no `@testable import`).
- **Commit style.** `wip: [description] - builds/tests pass/etc`. Never amend.
- **Makefile.** Use `make build`, `make run`, `make prod`, `make clean`.
