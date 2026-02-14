import AppKit

protocol PasteboardProviding: AnyObject {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    @discardableResult func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: PasteboardProviding {}

protocol ClipboardManagerDelegate: AnyObject {
    func clipboardManagerDidUpdateEntries(_ manager: ClipboardManager)
}

class ClipboardManager {
    static let maxEntries = 50

    weak var delegate: ClipboardManagerDelegate?

    private(set) var entries: [ClipboardEntry] = []
    private var lastChangeCount: Int
    private var pollTimer: Timer?
    private var expiryTimer: Timer?
    private let pasteboard: PasteboardProviding

    init(pasteboard: PasteboardProviding = NSPasteboard.general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func startMonitoring() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.removeExpiredEntries()
        }
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    func checkForChanges() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let content = pasteboard.string(forType: .string) else { return }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Preserve favorite status from any duplicate before removing
        let wasFavorite = entries.first(where: { $0.content == content })?.isFavorite ?? false
        entries.removeAll { $0.content == content }

        let isBitwarden = PasswordDetector.isBitwardenContent(pasteboardTypes: pasteboard.types)
        let isPassword = isBitwarden || PasswordDetector.isPasswordLike(content)

        let entry = ClipboardEntry(content: content, isPassword: isPassword, isFavorite: wasFavorite)
        entries.insert(entry, at: 0)

        // Cap at max entries
        if entries.count > ClipboardManager.maxEntries {
            entries = Array(entries.prefix(ClipboardManager.maxEntries))
        }

        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func removeExpiredEntries() {
        let before = entries.count
        entries.removeAll { $0.isExpired }
        if entries.count != before {
            delegate?.clipboardManagerDidUpdateEntries(self)
        }
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func updateEntryContent(id: UUID, newContent: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: newContent, isPassword: old.isPassword, isFavorite: old.isFavorite, timestamp: old.timestamp, id: old.id)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func toggleFavorite(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: old.content, isPassword: old.isPassword, isFavorite: !old.isFavorite, timestamp: old.timestamp, id: old.id)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func selectEntry(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        _ = pasteboard.setString(entry.content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    // For testing
    func addEntry(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        if entries.count > ClipboardManager.maxEntries {
            entries = Array(entries.prefix(ClipboardManager.maxEntries))
        }
        delegate?.clipboardManagerDidUpdateEntries(self)
    }
}
