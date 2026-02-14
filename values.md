# Freeboard Values

Design principles for Freeboard. Every feature decision should pass through these.

## 1. Keyboard-first, mouse-optional

The keyboard is always the fastest path. Every action has a key binding. Mouse works for everything, but a user who never touches the mouse should never feel limited. If a feature cannot have a simple, discoverable keyboard binding, it probably should not exist.

## 2. Terminal soul

Freeboard looks, sounds, and feels like a terminal. Green on black. Monospaced text. ASCII art. Scanlines and cracked glass. No rounded-corner cards, no pastel gradients, no SF Symbols in the main UI. New features must feel like they belong on a CRT monitor in a 1983 hacker movie.

## 3. Instant and ephemeral

The app opens fast, does its job, and gets out of the way. Everything lives in memory. No databases, no cloud, no disk writes. Data exists only while the app is running. Clipboard history is transient by nature and the app respects that. Passwords expire and vanish. This is a feature, not a limitation.

## 4. Privacy by architecture

No network calls. No telemetry. No disk persistence. Passwords are detected and masked automatically. Bitwarden integration is passive (read a pasteboard flag, nothing more). The user never has to configure privacy settings because the architecture makes data exposure impossible.

## 5. Simplicity over features

If a feature cannot be explained in one sentence, it is too complex. If it requires a settings panel, it probably should not be built. The app should be self-explanatory on first launch. Complexity is hidden in code, never exposed to the user. A feature that is hard to make simple should simply not be done.

## 6. One window, one purpose

Freeboard is a single popup. No preferences window, no floating palettes, no secondary panels. Everything happens in the main list. The popup opens, the user acts, the popup closes. Every interaction should complete in under 3 seconds.

## 7. Accessible to everyone

VoiceOver works. Increase Contrast works. Reduce Transparency works. Keyboard navigation works. Localization works in 10 languages. Accessibility is not an afterthought bolted on -- it is a constraint that shapes every UI decision from the start.
