import AppKit
import Vision

protocol PasteboardProviding: AnyObject {
    var changeCount: Int { get }
    var types: [NSPasteboard.PasteboardType]? { get }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String?
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data?
    @discardableResult func clearContents() -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
    @discardableResult func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool
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

        // Capture rich text data (RTF, HTML) for non-password entries
        var richPasteboardData: [NSPasteboard.PasteboardType: Data]? = nil
        if !isPassword {
            var richData: [NSPasteboard.PasteboardType: Data] = [:]
            let richTypes: [NSPasteboard.PasteboardType] = [.rtf, .html,
                NSPasteboard.PasteboardType("public.rtf"),
                NSPasteboard.PasteboardType("public.html")]
            for richType in richTypes {
                if let data = pasteboard.data(forType: richType) {
                    richData[richType] = data
                }
            }
            if let stringData = content.data(using: .utf8) {
                richData[.string] = stringData
            }
            richPasteboardData = richData.isEmpty ? nil : richData
        }

        let entry = ClipboardEntry(content: content, isPassword: isPassword, isStarred: wasStarred, pasteboardData: richPasteboardData)
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
        entries[idx] = ClipboardEntry(content: newContent, isPassword: old.isPassword, isStarred: old.isStarred, timestamp: old.timestamp, id: old.id, pasteboardData: old.pasteboardData)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func toggleStar(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: old.content, isPassword: old.isPassword, isStarred: !old.isStarred, timestamp: old.timestamp, id: old.id, entryType: old.entryType, imageData: old.imageData, fileURL: old.fileURL, pasteboardData: old.pasteboardData)
        delegate?.clipboardManagerDidUpdateEntries(self)
    }

    func selectEntry(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.entryType {
        case .text:
            if let pbData = entry.pasteboardData {
                for (type, data) in pbData {
                    if type == .string {
                        _ = pasteboard.setString(entry.content, forType: .string)
                    } else {
                        _ = pasteboard.setData(data, forType: type)
                    }
                }
            } else {
                _ = pasteboard.setString(entry.content, forType: .string)
            }
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

    func selectEntryAsPlainText(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        _ = pasteboard.setString(entry.content, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }

    /// Convert markdown content to rich text (HTML) and write to pasteboard.
    /// Used when Shift+Enter is pressed on a plain markdown entry.
    func selectEntryAsRenderedMarkdown(_ entry: ClipboardEntry) {
        let html = Self.markdownToHTML(entry.content)
        pasteboard.clearContents()
        _ = pasteboard.setString(entry.content, forType: .string)
        if let htmlData = html.data(using: .utf8) {
            _ = pasteboard.setData(htmlData, forType: .html)
        }
        lastChangeCount = pasteboard.changeCount
    }

    /// Minimal markdown-to-HTML converter. Handles the most common markdown
    /// constructs: headings, bold, italic, code blocks, inline code, links,
    /// blockquotes, unordered/ordered lists, and horizontal rules.
    static func markdownToHTML(_ markdown: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        var html: [String] = []
        var inCodeBlock = false
        var codeBlockLang = ""
        var codeLines: [String] = []
        var inList = false
        var listOrdered = false
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code fences
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if inCodeBlock {
                    html.append("<pre><code>" + escapeHTML(codeLines.joined(separator: "\n")) + "</code></pre>")
                    codeLines = []
                    inCodeBlock = false
                    codeBlockLang = ""
                } else {
                    closeList(&html, &inList, listOrdered)
                    inCodeBlock = true
                    let fence = trimmed.hasPrefix("```") ? "```" : "~~~"
                    codeBlockLang = String(trimmed.dropFirst(fence.count)).trimmingCharacters(in: .whitespaces)
                }
                i += 1
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }

            // Empty line
            if trimmed.isEmpty {
                closeList(&html, &inList, listOrdered)
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed.range(of: "^[-*_]{3,}$", options: .regularExpression) != nil {
                closeList(&html, &inList, listOrdered)
                html.append("<hr>")
                i += 1
                continue
            }

            // Headings
            if let match = trimmed.range(of: "^(#{1,6}) (.+)$", options: .regularExpression) {
                closeList(&html, &inList, listOrdered)
                let hashCount = trimmed.prefix(while: { $0 == "#" }).count
                let content = String(trimmed.dropFirst(hashCount + 1))
                html.append("<h\(hashCount)>\(inlineMarkdown(content))</h\(hashCount)>")
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") {
                closeList(&html, &inList, listOrdered)
                let content = String(trimmed.dropFirst(2))
                html.append("<blockquote>\(inlineMarkdown(content))</blockquote>")
                i += 1
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if !inList || listOrdered {
                    closeList(&html, &inList, listOrdered)
                    html.append("<ul>")
                    inList = true
                    listOrdered = false
                }
                let content = String(trimmed.dropFirst(2))
                html.append("<li>\(inlineMarkdown(content))</li>")
                i += 1
                continue
            }

            // Ordered list
            if trimmed.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                if !inList || !listOrdered {
                    closeList(&html, &inList, listOrdered)
                    html.append("<ol>")
                    inList = true
                    listOrdered = true
                }
                let dotIndex = trimmed.firstIndex(of: ".")!
                let content = String(trimmed[trimmed.index(dotIndex, offsetBy: 2)...])
                html.append("<li>\(inlineMarkdown(content))</li>")
                i += 1
                continue
            }

            // Paragraph
            closeList(&html, &inList, listOrdered)
            html.append("<p>\(inlineMarkdown(trimmed))</p>")
            i += 1
        }

        // Close any open blocks
        if inCodeBlock {
            html.append("<pre><code>" + escapeHTML(codeLines.joined(separator: "\n")) + "</code></pre>")
        }
        closeList(&html, &inList, listOrdered)

        return html.joined(separator: "\n")
    }

    /// Process inline markdown: bold, italic, code, links.
    private static func inlineMarkdown(_ text: String) -> String {
        var result = escapeHTML(text)
        // Inline code (must come before bold/italic to avoid conflicts)
        result = result.replacingOccurrences(of: "`([^`]+)`",
            with: "<code>$1</code>", options: .regularExpression)
        // Bold+italic
        result = result.replacingOccurrences(of: "\\*\\*\\*(.+?)\\*\\*\\*",
            with: "<strong><em>$1</em></strong>", options: .regularExpression)
        // Bold
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*",
            with: "<strong>$1</strong>", options: .regularExpression)
        result = result.replacingOccurrences(of: "__(.+?)__",
            with: "<strong>$1</strong>", options: .regularExpression)
        // Italic
        result = result.replacingOccurrences(of: "\\*(.+?)\\*",
            with: "<em>$1</em>", options: .regularExpression)
        result = result.replacingOccurrences(of: "_(.+?)_",
            with: "<em>$1</em>", options: .regularExpression)
        // Links [text](url)
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        return result
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func closeList(_ html: inout [String], _ inList: inout Bool, _ ordered: Bool) {
        if inList {
            html.append(ordered ? "</ol>" : "</ul>")
            inList = false
        }
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
