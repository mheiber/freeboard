import Foundation

struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isPassword: Bool
    let expirationDate: Date?

    init(content: String, isPassword: Bool = false, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPassword = isPassword
        self.expirationDate = isPassword ? timestamp.addingTimeInterval(60) : nil
    }

    var displayContent: String {
        isPassword ? "********" : content
    }

    var isExpired: Bool {
        guard let exp = expirationDate else { return false }
        return Date() > exp
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.id == rhs.id
    }
}
