import AppKit
import Vision

protocol PasteboardProviding: AnyObject {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool
    func readObjects(forClasses classArray: [AnyClass], options: [NSPasteboard.ReadingOptionKey : Any]?) -> [Any]?
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

        let types = pasteboard.types ?? []

        // Check for image data first (PNG, TIFF, JPEG)
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff,
            NSPasteboard.PasteboardType("public.jpeg")]
        for imageType in imageTypes {
            if types.contains(imageType), let data = pasteboard.data(forType: imageType) {
                guard data.count <= 10_000_000 else { continue } // 10MB cap
                // Deduplicate by data hash
                let hash = dataHash(data)
                let wasStarred = entries.first(where: { $0.imageData != nil && dataHash($0.imageData!) == hash })?.isStarred ?? false
                entries.removeAll { $0.imageData != nil && dataHash($0.imageData!) == hash }

                let entry = ClipboardEntry(content: "", isStarred: wasStarred, entryType: .image, imageData: data)
                entries.insert(entry, at: 0)
                capEntries()

                // Run OCR on background thread
                performOCR(on: data, entryId: entry.id)

                delegate?.clipboardManagerDidUpdateEntries(self)
                return
            }
        }

        // Check for file URLs
        if types.contains(NSPasteboard.PasteboardType("public.file-url")),
           let urlString = pasteboard.string(forType: NSPasteboard.PasteboardType("public.file-url")),
           let url = URL(string: urlString) {
            let fileName = url.lastPathComponent
            let wasStarred = entries.first(where: { $0.fileURL?.absoluteString == urlString })?.isStarred ?? false
            entries.removeAll { $0.fileURL?.absoluteString == urlString }

            let entry = ClipboardEntry(content: fileName, isStarred: wasStarred, entryType: .fileURL, fileURL: url)
            entries.insert(entry, at: 0)
            capEntries()
            delegate?.clipboardManagerDidUpdateEntries(self)
            return
        }

        // Fall through to text
        guard let content = pasteboard.string(forType: .string) else { return }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Preserve star status from any duplicate before removing
        let wasStarred = entries.first(where: { $0.content == content && $0.entryType == .text })?.isStarred ?? false
        entries.removeAll { $0.content == content && $0.entryType == .text }

        let isBitwarden = PasswordDetector.isBitwardenContent(pasteboardTypes: pasteboard.types)
        let isPassword = isBitwarden || PasswordDetector.isPasswordLike(content)

        let entry = ClipboardEntry(content: content, isPassword: isPassword, isStarred: wasStarred)
        entries.insert(entry, at: 0)
        capEntries()
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
        entries[idx] = ClipboardEntry(content: newContent, isPassword: old.isPassword, isStarred: old.isStarred, timestamp: old.timestamp, id: old.id)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func toggleStar(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: old.content, isPassword: old.isPassword, isStarred: !old.isStarred, timestamp: old.timestamp, id: old.id, entryType: old.entryType, imageData: old.imageData, fileURL: old.fileURL)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func selectEntry(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.entryType {
        case .text:
            _ = pasteboard.setString(entry.content, forType: .string)
        case .image:
            if let data = entry.imageData, let image = NSImage(data: data) {
                _ = pasteboard.writeObjects([image])
            }
        case .fileURL:
            if let url = entry.fileURL {
                _ = pasteboard.writeObjects([url as NSURL])
            }
        }
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

    // MARK: - Private helpers

    private func capEntries() {
        if entries.count > ClipboardManager.maxEntries {
            entries = Array(entries.prefix(ClipboardManager.maxEntries))
        }
    }

    private func dataHash(_ data: Data) -> Int {
        var hasher = Hasher()
        hasher.combine(data)
        return hasher.finalize()
    }

    private func performOCR(on imageData: Data, entryId: UUID) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let nsImage = NSImage(data: imageData) else { return }
            var rect = NSRect(origin: .zero, size: nsImage.size)
            guard let cgImage = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return }
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                guard !text.isEmpty else { return }
                DispatchQueue.main.async {
                    self?.updateOCRText(entryId: entryId, text: text)
                }
            }
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func updateOCRText(entryId: UUID, text: String) {
        guard let idx = entries.firstIndex(where: { $0.id == entryId }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(
            content: text, isPassword: false, isStarred: old.isStarred,
            timestamp: old.timestamp, id: old.id,
            entryType: .image, imageData: old.imageData
        )
        delegate?.clipboardManagerDidUpdateEntries(self)
    }
}
