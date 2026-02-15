import Foundation
import AppKit

enum EntryType: Equatable {
    case text
    case image
    case fileURL
}

/// Classification for markdown/rich text paste conversion.
/// Determines what Shift+Enter does for a given entry.
enum FormatCategory: Equatable {
    case markdown   // Content is markdown → Shift+Enter pastes as rich text
    case code(String) // Content is code in the given language → Shift+Enter pastes with syntax highlighting
    case other      // Everything else → Shift+Enter pastes as plain text (no-op for plain text)
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

    /// Whether this entry has rich pasteboard data (RTF or HTML).
    var hasRichData: Bool {
        guard let pbData = pasteboardData else { return false }
        let richTypes: [NSPasteboard.PasteboardType] = [.rtf, .html,
            NSPasteboard.PasteboardType("public.rtf"),
            NSPasteboard.PasteboardType("public.html")]
        return richTypes.contains { pbData[$0] != nil }
    }

    /// Whether the plain text content looks like markdown (stricter threshold for paste conversion).
    var isMarkdownContent: Bool {
        guard entryType == .text, !content.isEmpty else { return false }
        return Self.markdownScore(content) >= 3
    }

    /// Classify this entry for paste conversion behavior.
    /// Uses a 40-line detection limit for performance — avoids scanning
    /// huge clipboard entries just to determine the language.
    ///
    /// Detection order: code FIRST, then markdown. This prevents code that
    /// happens to contain markdown-like patterns (e.g. `**`, `- `) from
    /// being misclassified as markdown.
    var formatCategory: FormatCategory {
        guard entryType == .text else { return .other }
        let lang = MonacoEditorView.detectLanguage(content, maxLines: 40)
        if lang != "plaintext" && lang != "markdown" {
            return .code(lang)
        }
        if isMarkdownContent { return .markdown }
        return .other
    }

    /// Score text for markdown-likeness. Higher score = more likely markdown.
    static func markdownScore(_ text: String) -> Int {
        let lines = text.components(separatedBy: "\n")
        var score = 0
        for line in lines {
            let ln = line.trimmingCharacters(in: .whitespaces)
            if ln.range(of: "^#{1,6} ", options: .regularExpression) != nil { score += 2 }
            if ln.hasPrefix("- ") || ln.hasPrefix("+ ") || (ln.hasPrefix("* ") && ln.count > 2) { score += 1 }
            if ln.range(of: "^\\d+\\. ", options: .regularExpression) != nil { score += 1 }
            if ln.hasPrefix("```") || ln.hasPrefix("~~~") { score += 2 }
            if ln.hasPrefix("> ") { score += 1 }
            if ln.contains("](") && ln.contains("[") { score += 2 }
            if ln.contains("**") || ln.contains("__") { score += 1 }
        }
        return score
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
