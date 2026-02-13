# Freeboard一一the only clipboard manager with fake screen cracks and hanzi

clipboard manager. 100% vibecoded.

cmd-shift-v to open and select recent clipboard entries

## Features

- **Clipboard history** — stores last 50 entries in memory (never on disk)
- **cmd-shift-v** or click `[F]` in menu bar to open
- **Fuzzy search**, ctrl-n/ctrl-p navigation, click or Enter to paste
- **Password detection** — masks entries that look like passwords (`********`), auto-expires after 60s
- **Bitwarden support** — recognizes `org.nspasteboard.ConcealedType` pasteboard marker
- **Bilingual UI** — English and Chinese, switchable from menu.
- Fully local. Zero internet. Zero disk. All in-memory.

## Build & Run

```
make build    # build Debug
make run      # build, kill existing, launch
make prod     # build Release, install to /Applications, launch
make clean    # remove build artifacts
```

Requires Accessibility permissions for paste simulation (prompted on first launch).

## Test

```
xcodebuild -project Freeboard.xcodeproj -scheme Freeboard -configuration Debug build-for-testing
xcrun xctest build/Debug/FreeboardTests.xctest
```

52 end-to-end style tests covering clipboard management, password detection, fuzzy search, and integration flows.

## Quit

Right-click the `[F]` menu bar icon, or use the Quit button in the popup footer.

## Vocabulary / 词汇

All UI strings with pinyin for learners:

| English | 汉字 | Pīnyīn |
|---------|------|--------|
| Search clipboard history | 搜索剪贴板历史 | sōusuǒ jiǎntiēbǎn lìshǐ |
| navigate | 导航 | dǎoháng |
| paste | 粘贴 | zhāntiē |
| close | 关闭 | guānbì |
| expand | 展开 | zhǎnkāi |
| edit | 编辑 | biānjí |
| delete | 删除 | shānchú |
| Quit | 退出 | tuìchū |
| Quit Freeboard | 退出 Freeboard | tuìchū Freeboard |
| just now | 刚刚 | gānggāng |
| Chinese | 中文 | zhōngwén |
| N minutes ago | N分钟前 | N fēnzhōng qián |
| N hours ago | N小时前 | N xiǎoshí qián |
| N days ago | N天前 | N tiān qián |
| Language | 语言 | yǔyán |
