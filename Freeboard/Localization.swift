import Foundation

enum Lang: String {
    case en, zh
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

    static var searchPlaceholder: String {
        current == .zh ? "▌ 搜索剪贴板历史..." : "▌ Search clipboard history..."
    }
    static var navigate: String { current == .zh ? "导航" : "navigate" }
    static var paste: String { current == .zh ? "粘贴" : "paste" }
    static var close: String { current == .zh ? "关闭" : "close" }
    static var expand: String { current == .zh ? "展开" : "expand" }
    static var edit: String { current == .zh ? "编辑" : "edit" }
    static var delete: String { current == .zh ? "删除" : "delete" }
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
    static var search: String { current == .zh ? "搜索" : "search" }

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
