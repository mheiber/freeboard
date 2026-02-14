import Foundation

struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isPassword: Bool
    let isFavorite: Bool
    let expirationDate: Date?

    init(content: String, isPassword: Bool = false, isFavorite: Bool = false, timestamp: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPassword = isPassword
        self.isFavorite = isFavorite
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
        if interval < 60 { return L.justNow }
        if interval < 3600 { return L.minutesAgo(Int(interval / 60)) }
        if interval < 86400 { return L.hoursAgo(Int(interval / 3600)) }
        return L.daysAgo(Int(interval / 86400))
    }

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.id == rhs.id
    }
}
