import Foundation
import Carbon

enum Lang: String {
    case en, zh
}

enum HotkeyChoice: String, CaseIterable {
    case c, x, v

    var keyCode: Int {
        switch self {
        case .c: return kVK_ANSI_C
        case .x: return kVK_ANSI_X
        case .v: return kVK_ANSI_V
        }
    }

    var displayName: String {
        switch self {
        case .c: return "Cmd-Shift-C"
        case .x: return "Cmd-Shift-X"
        case .v: return "Cmd-Shift-V"
        }
    }

    private static let hotkeyKey = "freeboard_hotkey"

    static var current: HotkeyChoice {
        get {
            if let raw = UserDefaults.standard.string(forKey: hotkeyKey),
               let choice = HotkeyChoice(rawValue: raw) {
                return choice
            }
            return .c
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: hotkeyKey)
        }
    }
}

struct L {
    private static let langKey = "freeboard_language"

    static var current: Lang {
        get {
            if let raw = UserDefaults.standard.string(forKey: langKey),
               let lang = Lang(rawValue: raw) {
                return lang
            }
            return .en
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: langKey)
        }
    }

    static var open: String { current == .zh ? "打开" : "Open" }
    static var shortcut: String { current == .zh ? "快捷键" : "Shortcut" }

    static var searchPlaceholder: String {
        current == .zh ? "▌ 搜索剪贴板历史..." : "▌ Search clipboard history..."
    }
    static var navigate: String { current == .zh ? "导航" : "navigate" }
    static var paste: String { current == .zh ? "粘贴" : "paste" }
    static var close: String { current == .zh ? "关闭" : "close" }
    static var expand: String { current == .zh ? "展开" : "expand" }
    static var edit: String { current == .zh ? "编辑" : "edit" }
    static var star: String { current == .zh ? "收藏" : "star" }
    static var quit: String { current == .zh ? "退出" : "Quit" }
    static var quitFreeboard: String { current == .zh ? "退出 Freeboard" : "Quit Freeboard" }
    static var justNow: String { current == .zh ? "刚刚" : "just now" }
    static var english: String { "English" }
    static var chinese: String { "中文" }
    static var emptyHint: String {
        current == .zh ? "复制的文本将显示在这里" : "Text you copy will show up here"
    }
    static var openClose: String {
        current == .zh ? "打开/关闭此窗口" : "open/close"
    }
    static var quickSelect: String { current == .zh ? "快速选择" : "quick select" }
    static var noMatchesFound: String { current == .zh ? "未找到匹配项。" : "No matches found." }
    static var clearSearch: String { current == .zh ? "清除搜索 (Esc)" : "Clear Search (Esc)" }

    static var help: String { current == .zh ? "帮助" : "Help" }
    static var helpTitle: String { current == .zh ? "FREEBOARD 帮助" : "FREEBOARD HELP" }
    static var helpStep1: String { current == .zh ? "从任何应用程序复制文本，使用 ⌘c" : "Copy text from any application with ⌘c" }
    static var helpStep2Suffix: String { current == .zh ? "打开 Freeboard" : "to open Freeboard" }
    static var helpStep3a: String { current == .zh ? "按数字键 (1-9) 粘贴" : "Press a number (1-9) to paste" }
    static var helpStep3b: String { current == .zh ? "或输入搜索，然后按 Enter" : "OR type to search, then Enter" }
    static var helpDismiss: String { current == .zh ? "? 关闭帮助" : "? to close help" }

    static var helpAccessibility: String {
        current == .zh
            ? "要粘贴到其他应用，Freeboard 需要辅助功能权限。\n请前往"
            : "To paste into apps, Freeboard needs permission.\nPlease go to"
    }
    static var helpAccessibilityLink: String {
        current == .zh ? "系统设置 → 辅助功能" : "Accessibility Permissions"
    }
    static var helpAccessibilitySteps: String {
        current == .zh
            ? "点击 [+]，添加 Freeboard，并确保已启用 [✓]"
            : "click [+], add Freeboard, and make sure it is enabled [✓]"
    }

    static func minutesAgo(_ n: Int) -> String {
        current == .zh ? "\(n)分钟前" : "\(n)m ago"
    }
    static func hoursAgo(_ n: Int) -> String {
        current == .zh ? "\(n)小时前" : "\(n)h ago"
    }
    static func daysAgo(_ n: Int) -> String {
        current == .zh ? "\(n)天前" : "\(n)d ago"
    }
}
