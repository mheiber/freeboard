# Freeboard Values

Design principles for Freeboard. Every feature decision should pass through these.

## 1. Keyboard-first, mouse-optional

The keyboard is always the fastest path. Every action has a key binding. Mouse works for everything, but a user who never touches the mouse should never feel limited. If a feature cannot have a simple, discoverable keyboard binding, it probably should not exist.

Hints are live. If the UI shows a shortcut like "^E edit" or ":x save+close", clicking that hint performs the action. A hint that describes something you can do should let you do it right there. No dead text.

Discoverable layers. Standard keys (Tab, arrow keys) work everywhere a power user would expect them to, even when not documented. For example, Tab cycles through links in help screens alongside j/k -- users who expect it find it; users who don't aren't overwhelmed.

## 2. Terminal Power: Efficiency, pragmatism, beauty, soul

PRACTICAL: no noise, no animations
LOoks fun and interesting
Pragmatic efficient

we want efficient and
  pragmatic, no distractions, no overcomplication. No need for clear all, just hold cmd-d . No boot up animation. no fade ins
  and fade outs


## 3. Instant and ephemeral

The app opens fast, does its job, and gets out of the way. Clipboard history is transient by nature and the app respects that. Passwords expire and vanish. This is a feature, not a limitation.

**Persistence as a special case:** Non-password clipboard entries are persisted across app launches so that the user's history survives a restart. This is opt-in by architecture -- only safe, non-password content is ever written to disk.

**Passwords are NEVER stored to disk.** This is an absolute rule. Password entries exist only in memory and are filtered out before any write to persistent storage. Even on load, any password entry that somehow appears in the stored data is discarded.

## 4. Privacy by architecture

No network calls. No telemetry. Passwords are detected and masked automatically and are NEVER written to disk. Bitwarden integration is passive (read a pasteboard flag, nothing more). Non-password clipboard data is persisted locally in the app's sandboxed container -- never sent anywhere. The user never has to configure privacy settings because the architecture makes data exposure impossible.

## 5. Simplicity over features

If a feature cannot be explained in one sentence, it is too complex. If it requires a settings panel, it probably should not be built. The app should be self-explanatory on first launch. Complexity is hidden in code, never exposed to the user. A feature that is hard to make simple should simply not be done.

## 6. One window, one purpose

Freeboard is a single popup. No preferences window, no floating palettes, no secondary panels. Everything happens in the main list. The popup opens, the user acts, the popup closes. Every interaction should complete in under 3 seconds.

## 7. Accessible to everyone

VoiceOver works. Increase Contrast works. Reduce Transparency works. Keyboard navigation works. Localization works in 10 languages. Accessibility is not an afterthought bolted on -- it is a constraint that shapes every UI decision from the start.

### i18n and a11y in practice

Every user-facing string lives in `Localization.swift` with translations in all 10 languages. No hardcoded English in the UI layer. When adding a new feature:

- Add a localization key with translations for all 10 `Lang` cases (en, zh, hi, es, fr, ar, bn, pt, ru, ja).
- Add an `accessibilityLabel` or `accessibilityHelp` for any new interactive or informational element so VoiceOver users know what Shift+Enter (or any alternate action) will do.
- If the feature changes behavior based on content type (markdown, code, rich text), communicate that state to VoiceOver via `setAccessibilityHelp` on the row cell and `setAccessibilityLabel` on the hint bar.
- Context menu items should mirror keyboard shortcuts with localized labels.

## 8. Performance is invisible

The app must feel instant, even with large or numerous clipboard entries. Any feature that processes content -- syntax highlighting, language detection, format classification -- must bound its work to what is actually visible on screen. Never scan an entire million-line entry when the user can only see a few lines. Never do O(n) work where O(1) suffices.

Example: syntax highlighting in the main view only highlights text that is actually rendered. If 100 unexpanded entries each contain a million lines, total highlighting work stays around 700 lines (one line per unexpanded row, plus ~30 lines for one expanded row), not 100 million. Language detection examines at most 40 lines. These limits keep the popup responsive even with pathological clipboard content.
