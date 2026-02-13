# Freeboard

Mac menu bar clipboard manager. Retro green-on-black hacker UI.

## Features

- **Clipboard history** — stores last 50 entries in memory (never on disk)
- **cmd-shift-v** or click `[F]` in menu bar to open
- **Fuzzy search**, ctrl-n/ctrl-p navigation, click or Enter to paste
- **Password detection** — masks entries that look like passwords (`********`), auto-expires after 60s
- **Bitwarden support** — recognizes `org.nspasteboard.ConcealedType` pasteboard marker
- **VCR glitch effects** — scanlines, occasional glitch bands, edge vignette
- Fully local. Zero internet. Zero disk. All in-memory.

## Build & Run

```
xcodebuild -project Freeboard.xcodeproj -scheme Freeboard build
open build/Debug/Freeboard.app
```

Requires Accessibility permissions for the global hotkey (prompted on first launch).

## Test

```
xcodebuild -project Freeboard.xcodeproj -target FreeboardTests -configuration Debug build -destination "platform=macOS"
xcrun xctest build/Debug/FreeboardTests.xctest
```

51 end-to-end style tests covering clipboard management, password detection, fuzzy search, and integration flows.

## Quit

Right-click the `[F]` menu bar icon, or use the Quit button in the popup footer.
