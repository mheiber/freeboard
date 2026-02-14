import Foundation
import AppKit

enum EntryType: Equatable {
    case text
    case image
    case fileURL
}

struct ClipboardEntry: Identifiable, Equatable {
    let id: UUID
    let content: String  // For text: the text. For image: OCR text or "". For fileURL: the URL string.
    let timestamp: Date
    let isPassword: Bool
    let isStarred: Bool
    let expirationDate: Date?
    let entryType: EntryType
    let imageData: Data?      // Raw image data (PNG/TIFF/JPEG), nil for non-image
    let fileURL: URL?         // File URL for file entries, nil otherwise
    let pasteboardData: [NSPasteboard.PasteboardType: Data]?  // nil for image/file entries

    // Cached thumbnail -- not part of equality
    private var _thumbnail: NSImage?

    init(content: String, isPassword: Bool = false, isStarred: Bool = false,
         timestamp: Date = Date(), id: UUID = UUID(),
         entryType: EntryType = .text, imageData: Data? = nil, fileURL: URL? = nil,
         pasteboardData: [NSPasteboard.PasteboardType: Data]? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isPassword = isPassword
        self.isStarred = isStarred
        self.expirationDate = isPassword ? timestamp.addingTimeInterval(60) : nil
        self.entryType = entryType
        self.imageData = imageData
        self.fileURL = fileURL
        self.pasteboardData = pasteboardData
    }

    var displayContent: String {
        switch entryType {
        case .text:
            return isPassword ? "********" : content
        case .image:
            if content.isEmpty {
                return "[img]"
            }
            return content
        case .fileURL:
            if let url = fileURL {
                return url.lastPathComponent
            }
            return content
        }
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

    var accessibleTimeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        if interval < 60 { return L.justNow }
        if interval < 3600 { return L.accessibleMinutesAgo(Int(interval / 60)) }
        if interval < 86400 { return L.accessibleHoursAgo(Int(interval / 3600)) }
        return L.accessibleDaysAgo(Int(interval / 86400))
    }

    /// Generate a thumbnail for image entries. Caches lazily.
    mutating func thumbnail(maxSize: CGFloat = 40) -> NSImage? {
        if let cached = _thumbnail { return cached }
        guard entryType == .image, let data = imageData, let image = NSImage(data: data) else { return nil }
        let ratio = min(maxSize / image.size.width, maxSize / image.size.height, 1.0)
        let newSize = NSSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumb.unlockFocus()
        _thumbnail = thumb
        return thumb
    }

    static func == (lhs: ClipboardEntry, rhs: ClipboardEntry) -> Bool {
        lhs.id == rhs.id
    }
}
