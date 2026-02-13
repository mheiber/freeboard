import Foundation

enum Lang: String {
    case en, zh
}

struct L {
    static var current: Lang = defaultLanguage()

    static func defaultLanguage() -> Lang {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 18 || hour < 9) ? .zh : .en
    }

    static var searchPlaceholder: String {
        current == .zh ? "▌ 搜索剪贴板历史..." : "▌ Search clipboard history..."
    }
    static var navigate: String { current == .zh ? "导航" : "navigate" }
    static var paste: String { current == .zh ? "粘贴" : "paste" }
    static var close: String { current == .zh ? "关闭" : "close" }
    static var expand: String { current == .zh ? "展开" : "expand" }
    static var delete: String { current == .zh ? "删除" : "delete" }
    static var quit: String { current == .zh ? "退出" : "Quit" }
    static var quitFreeboard: String { current == .zh ? "退出 Freeboard" : "Quit Freeboard" }
    static var justNow: String { current == .zh ? "刚刚" : "just now" }
    static var english: String { "English" }
    static var chinese: String { "中文" }

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
