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

    /// File URL for persisted clipboard entries (Application Support directory).
    private static let persistenceURL: URL? = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = appSupport.appendingPathComponent("Freeboard")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_entries.json")
    }()

    init(pasteboard: PasteboardProviding = NSPasteboard.general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
        loadFromDisk()
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

        // Check for file URLs first — when copying files from Finder, macOS puts both
        // a file URL and an image (the file icon) on the pasteboard. Checking file URLs
        // first ensures we store the file path, not the icon thumbnail.
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
            saveToDisk()
            return
        }

        // Check for image data (PNG, TIFF, JPEG) — only reached when there's no file URL,
        // i.e. screenshots, browser image copies, etc.
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
                saveToDisk()
                return
            }
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
        saveToDisk()
    }

    func removeExpiredEntries() {
        let before = entries.count
        entries.removeAll { $0.isExpired }
        if entries.count != before {
            delegate?.clipboardManagerDidUpdateEntries(self)
            saveToDisk()
        }
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        delegate?.clipboardManagerDidUpdateEntries(self)
        saveToDisk()
    }

    func updateEntryContent(id: UUID, newContent: String) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: newContent, isPassword: old.isPassword, isStarred: old.isStarred, timestamp: old.timestamp, id: old.id, pasteboardData: old.pasteboardData)
        delegate?.clipboardManagerDidUpdateEntries(self)
        saveToDisk()
    }

    func toggleStar(id: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        let old = entries[idx]
        entries[idx] = ClipboardEntry(content: old.content, isPassword: old.isPassword, isStarred: !old.isStarred, timestamp: old.timestamp, id: old.id, entryType: old.entryType, imageData: old.imageData, fileURL: old.fileURL, pasteboardData: old.pasteboardData)
        delegate?.clipboardManagerDidUpdateEntries(self)
        saveToDisk()
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

    /// Convert code content to syntax-highlighted HTML and write to pasteboard.
    /// Used when Shift+Enter is pressed on a detected code entry.
    func selectEntryAsSyntaxHighlightedCode(_ entry: ClipboardEntry, language: String) {
        let html = Self.codeToHighlightedHTML(entry.content, language: language)
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

    // MARK: - Syntax Highlighting

    /// Generate syntax-highlighted HTML from code text.
    /// Uses a simple regex-based tokenizer for common languages.
    /// Colors use a dark-on-light scheme that works well when pasted into
    /// rich text editors like Pages, Google Docs, Word, etc.
    static func codeToHighlightedHTML(_ code: String, language: String) -> String {
        let escaped = escapeHTML(code)
        let highlighted = highlightTokens(escaped, language: language)
        return """
        <pre style="font-family: Menlo, Monaco, 'Courier New', monospace; font-size: 13px; \
        background-color: #f8f8f8; padding: 12px; border-radius: 6px; \
        line-height: 1.4; color: #24292e; white-space: pre-wrap;">\(highlighted)</pre>
        """
    }

    /// Tokenize and colorize HTML-escaped source code.
    /// Order matters: comments and strings are matched first so keywords
    /// inside them are not colorized.
    private static func highlightTokens(_ escaped: String, language: String) -> String {
        // Build patterns in priority order
        var patterns: [(pattern: String, color: String)] = []

        // 1. Multi-line comments  /* ... */ (and OCaml's (* ... *), Lua's --[[ ... ]])
        if language == "ocaml" {
            patterns.append((#"\(\*[\s\S]*?\*\)"#, "#6a737d"))
        } else if language == "lua" {
            patterns.append((#"--\[\[[\s\S]*?\]\]"#, "#6a737d"))
        } else {
            patterns.append((#"\/\*[\s\S]*?\*\/"#, "#6a737d"))
        }

        // 2. Single-line comments
        if language == "python" || language == "shell" || language == "ruby" {
            patterns.append((#"#[^\n]*"#, "#6a737d"))
        } else if language == "toml" || language == "jq" {
            patterns.append((#"#[^\n]*"#, "#6a737d"))
        } else if language == "php" {
            // PHP supports both // and # comments
            patterns.append((#"\/\/[^\n]*"#, "#6a737d"))
            patterns.append((#"#[^\n]*"#, "#6a737d"))
        } else if language == "lua" {
            patterns.append((#"--[^\n]*"#, "#6a737d"))
        } else if language == "ocaml" {
            // OCaml only has block comments (* ... *), no single-line comment
        } else {
            patterns.append((#"\/\/[^\n]*"#, "#6a737d"))
        }
        // SQL also uses -- comments
        if language == "sql" {
            patterns.append((#"--[^\n]*"#, "#6a737d"))
        }

        // 3. Strings (double-quoted and single-quoted)
        patterns.append((#"&quot;(?:[^&]|&(?!quot;))*?&quot;"#, "#032f62"))
        // OCaml uses single-quotes for type variables ('a, 'b) and char literals ('x'),
        // so skip the generic single-quote string pattern. Match only char literals.
        if language == "ocaml" {
            patterns.append((#"&#39;(?:[^&]|&(?!#39;))&#39;(?!\w)"#, "#032f62"))
        } else {
            patterns.append((#"&#39;(?:[^&]|&(?!#39;))*?&#39;"#, "#032f62"))
        }
        // Backtick template literals for JS/TS (escaped as `)
        if language == "javascript" || language == "typescript" {
            patterns.append((#"`[^`]*`"#, "#032f62"))
        }

        // 4. Numbers (integers, floats, hex)
        patterns.append((#"\b0x[0-9a-fA-F]+\b"#, "#005cc5"))
        patterns.append((#"\b\d+\.?\d*\b"#, "#005cc5"))

        // 5. Language-specific keywords
        let keywords = Self.keywordsForLanguage(language)
        if !keywords.isEmpty {
            let joined = keywords.joined(separator: "|")
            patterns.append((#"\b(?:"# + joined + #")\b"#, "#d73a49"))
        }

        // 6. Type/class names (capitalized identifiers)
        let builtinTypes = Self.builtinTypesForLanguage(language)
        if !builtinTypes.isEmpty {
            let joined = builtinTypes.joined(separator: "|")
            patterns.append((#"\b(?:"# + joined + #")\b"#, "#6f42c1"))
        }

        // 7. Decorators/attributes (@something)
        if language == "swift" || language == "python" || language == "java" || language == "typescript"
            || language == "csharp" || language == "kotlin" || language == "php" {
            patterns.append((#"@\w+"#, "#e36209"))
        }
        // Rust attributes (#[...] and #![...])
        if language == "rust" {
            patterns.append((#"#!?\[[\w:(, )]*\]"#, "#e36209"))
        }
        // C/C++ preprocessor directives (#include, #define, #ifdef, etc.)
        if language == "c" || language == "cpp" {
            patterns.append((#"#\s*(include|define|undef|ifdef|ifndef|if|elif|else|endif|pragma|error|warning)\b[^\n]*"#, "#e36209"))
        }
        // PHP variables ($variable)
        if language == "php" {
            patterns.append((#"\$\w+"#, "#e36209"))
        }
        // Ruby symbols (:symbol)
        if language == "ruby" {
            patterns.append((#":\w+"#, "#0086b3"))
        }
        // OCaml: capitalized identifiers are module names / constructors
        if language == "ocaml" {
            patterns.append((#"\b[A-Z]\w*"#, "#6f42c1"))
        }

        // Combine all patterns into one regex with named groups
        // We process matches left-to-right, applying the first match at each position
        var result = escaped
        var combinedPattern = patterns.map { "(\($0.pattern))" }.joined(separator: "|")

        guard let regex = try? NSRegularExpression(pattern: combinedPattern, options: [.dotMatchesLineSeparators]) else {
            return escaped
        }

        let nsString = escaped as NSString
        let matches = regex.matches(in: escaped, range: NSRange(location: 0, length: nsString.length))

        // Build result by replacing matches in reverse order to preserve indices
        var mutableResult = escaped
        for match in matches.reversed() {
            let fullRange = match.range
            let matchedText = nsString.substring(with: fullRange)

            // Find which group matched to determine color
            var color = "#24292e"
            for i in 0..<patterns.count {
                let groupRange = match.range(at: i + 1)
                if groupRange.location != NSNotFound {
                    color = patterns[i].color
                    break
                }
            }

            let startIndex = mutableResult.index(mutableResult.startIndex, offsetBy: fullRange.location)
            let endIndex = mutableResult.index(startIndex, offsetBy: fullRange.length)
            mutableResult.replaceSubrange(startIndex..<endIndex,
                with: "<span style=\"color: \(color)\">\(matchedText)</span>")
        }

        return mutableResult
    }

    /// Return keyword list for a given language.
    static func keywordsForLanguage(_ language: String) -> [String] {
        switch language {
        case "swift":
            return ["func", "var", "let", "if", "else", "guard", "return", "import", "class", "struct",
                    "enum", "protocol", "extension", "switch", "case", "default", "for", "while", "repeat",
                    "break", "continue", "throw", "throws", "try", "catch", "do", "in", "where",
                    "self", "super", "init", "deinit", "nil", "true", "false", "static", "private",
                    "public", "internal", "fileprivate", "open", "override", "mutating", "weak",
                    "unowned", "lazy", "typealias", "associatedtype", "async", "await"]
        case "python":
            return ["def", "class", "if", "elif", "else", "for", "while", "return", "import", "from",
                    "as", "try", "except", "finally", "raise", "with", "yield", "lambda", "pass",
                    "break", "continue", "and", "or", "not", "in", "is", "None", "True", "False",
                    "self", "async", "await", "global", "nonlocal"]
        case "javascript":
            return ["function", "var", "let", "const", "if", "else", "return", "for", "while", "do",
                    "switch", "case", "default", "break", "continue", "throw", "try", "catch",
                    "finally", "new", "this", "class", "extends", "import", "export", "from",
                    "async", "await", "yield", "typeof", "instanceof", "in", "of",
                    "true", "false", "null", "undefined"]
        case "typescript":
            return ["function", "var", "let", "const", "if", "else", "return", "for", "while", "do",
                    "switch", "case", "default", "break", "continue", "throw", "try", "catch",
                    "finally", "new", "this", "class", "extends", "implements", "import", "export",
                    "from", "async", "await", "yield", "typeof", "instanceof", "in", "of",
                    "true", "false", "null", "undefined", "type", "interface", "enum", "namespace",
                    "abstract", "private", "public", "protected", "readonly", "static", "as",
                    "keyof", "declare"]
        case "json":
            return ["true", "false", "null"]
        case "sql":
            return ["SELECT", "FROM", "WHERE", "INSERT", "INTO", "UPDATE", "DELETE", "CREATE",
                    "TABLE", "ALTER", "DROP", "INDEX", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER",
                    "ON", "AND", "OR", "NOT", "IN", "IS", "NULL", "AS", "ORDER", "BY", "GROUP",
                    "HAVING", "LIMIT", "OFFSET", "UNION", "ALL", "DISTINCT", "SET", "VALUES",
                    "WITH", "EXISTS", "BETWEEN", "LIKE", "CASE", "WHEN", "THEN", "ELSE", "END",
                    "ASC", "DESC", "COUNT", "SUM", "AVG", "MIN", "MAX",
                    // lowercase variants
                    "select", "from", "where", "insert", "into", "update", "delete", "create",
                    "table", "alter", "drop", "index", "join", "left", "right", "inner", "outer",
                    "on", "and", "or", "not", "in", "is", "null", "as", "order", "by", "group",
                    "having", "limit", "offset", "union", "all", "distinct", "set", "values",
                    "with", "exists", "between", "like", "case", "when", "then", "else", "end"]
        case "shell":
            return ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case",
                    "esac", "function", "return", "exit", "echo", "export", "local", "readonly",
                    "source", "alias", "unalias", "set", "unset", "in", "true", "false"]
        case "rust":
            return ["as", "async", "await", "break", "const", "continue", "crate", "dyn",
                    "else", "enum", "extern", "false", "fn", "for", "if", "impl", "in",
                    "let", "loop", "match", "mod", "move", "mut", "pub", "ref", "return",
                    "self", "Self", "static", "struct", "super", "trait", "true", "type",
                    "unsafe", "use", "where", "while", "yield"]
        case "go":
            return ["break", "case", "chan", "const", "continue", "default", "defer", "else",
                    "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
                    "map", "package", "range", "return", "select", "struct", "switch", "type",
                    "var", "true", "false", "nil"]
        case "ocaml":
            return ["and", "as", "assert", "begin", "class", "constraint", "do", "done",
                    "downto", "else", "end", "exception", "external", "false", "for", "fun",
                    "function", "functor", "if", "in", "include", "inherit", "initializer",
                    "lazy", "let", "match", "method", "mod", "module", "mutable", "new",
                    "nonrec", "object", "of", "open", "or", "private", "rec", "sig", "struct",
                    "then", "to", "true", "try", "type", "val", "virtual", "when", "while", "with"]
        case "toml":
            return ["true", "false"]
        case "jq":
            return ["if", "then", "elif", "else", "end", "as", "def", "reduce", "foreach",
                    "try", "catch", "import", "include", "label", "break", "null", "true",
                    "false", "and", "or", "not"]
        case "xml":
            return []  // XML doesn't have keywords in the traditional sense
        case "c", "cpp":
            return ["auto", "break", "case", "char", "const", "continue", "default", "do",
                    "double", "else", "enum", "extern", "float", "for", "goto", "if",
                    "inline", "int", "long", "register", "return", "short", "signed",
                    "sizeof", "static", "struct", "switch", "typedef", "union", "unsigned",
                    "void", "volatile", "while",
                    // C++ additions
                    "alignas", "alignof", "and", "and_eq", "asm", "bitand", "bitor",
                    "bool", "catch", "class", "compl", "concept", "consteval", "constexpr",
                    "constinit", "co_await", "co_return", "co_yield", "decltype",
                    "delete", "dynamic_cast", "explicit", "export", "false", "friend",
                    "mutable", "namespace", "new", "noexcept", "not", "not_eq", "nullptr",
                    "operator", "or", "or_eq", "override", "private", "protected", "public",
                    "reinterpret_cast", "requires", "static_assert", "static_cast",
                    "template", "this", "throw", "true", "try", "typeid", "typename",
                    "using", "virtual", "xor", "xor_eq"]
        case "java":
            return ["abstract", "assert", "boolean", "break", "byte", "case", "catch",
                    "char", "class", "const", "continue", "default", "do", "double",
                    "else", "enum", "extends", "final", "finally", "float", "for", "goto",
                    "if", "implements", "import", "instanceof", "int", "interface", "long",
                    "native", "new", "package", "private", "protected", "public", "return",
                    "short", "static", "strictfp", "super", "switch", "synchronized",
                    "this", "throw", "throws", "transient", "try", "void", "volatile",
                    "while", "true", "false", "null", "var", "yield", "record", "sealed",
                    "permits", "non-sealed"]
        case "csharp":
            return ["abstract", "as", "base", "bool", "break", "byte", "case", "catch",
                    "char", "checked", "class", "const", "continue", "decimal", "default",
                    "delegate", "do", "double", "else", "enum", "event", "explicit",
                    "extern", "false", "finally", "fixed", "float", "for", "foreach",
                    "goto", "if", "implicit", "in", "int", "interface", "internal", "is",
                    "lock", "long", "namespace", "new", "null", "object", "operator",
                    "out", "override", "params", "private", "protected", "public",
                    "readonly", "ref", "return", "sbyte", "sealed", "short", "sizeof",
                    "stackalloc", "static", "string", "struct", "switch", "this", "throw",
                    "true", "try", "typeof", "uint", "ulong", "unchecked", "unsafe",
                    "ushort", "using", "var", "virtual", "void", "volatile", "while",
                    "async", "await", "yield", "dynamic", "partial", "where", "when",
                    "record", "init", "required"]
        case "ruby":
            return ["alias", "and", "begin", "break", "case", "class", "def", "defined?",
                    "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in",
                    "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
                    "return", "self", "super", "then", "true", "undef", "unless", "until",
                    "when", "while", "yield", "require", "require_relative", "include",
                    "extend", "prepend", "attr_reader", "attr_writer", "attr_accessor",
                    "puts", "print", "raise", "lambda", "proc"]
        case "php":
            return ["abstract", "and", "as", "break", "callable", "case", "catch", "class",
                    "clone", "const", "continue", "declare", "default", "do", "echo",
                    "else", "elseif", "empty", "enddeclare", "endfor", "endforeach",
                    "endif", "endswitch", "endwhile", "enum", "extends", "false", "final",
                    "finally", "fn", "for", "foreach", "function", "global", "goto", "if",
                    "implements", "include", "include_once", "instanceof", "insteadof",
                    "interface", "isset", "list", "match", "namespace", "new", "null",
                    "or", "print", "private", "protected", "public", "readonly", "require",
                    "require_once", "return", "static", "switch", "this", "throw", "trait",
                    "true", "try", "unset", "use", "var", "while", "xor", "yield"]
        case "kotlin":
            return ["as", "break", "class", "continue", "do", "else", "false", "for",
                    "fun", "if", "in", "interface", "is", "null", "object", "package",
                    "return", "super", "this", "throw", "true", "try", "typealias",
                    "typeof", "val", "var", "when", "while", "by", "catch", "constructor",
                    "delegate", "dynamic", "field", "file", "finally", "get", "import",
                    "init", "param", "property", "receiver", "set", "setparam", "where",
                    "actual", "abstract", "annotation", "companion", "const", "crossinline",
                    "data", "enum", "expect", "external", "final", "infix", "inline",
                    "inner", "internal", "lateinit", "noinline", "open", "operator", "out",
                    "override", "private", "protected", "public", "reified", "sealed",
                    "suspend", "tailrec", "vararg"]
        case "lua":
            return ["and", "break", "do", "else", "elseif", "end", "false", "for",
                    "function", "goto", "if", "in", "local", "nil", "not", "or",
                    "repeat", "return", "then", "true", "until", "while"]
        default:
            // Fallback: common C-family keywords
            return ["if", "else", "for", "while", "return", "class", "struct", "enum",
                    "switch", "case", "default", "break", "continue", "true", "false", "null",
                    "void", "int", "float", "double", "bool", "string", "import", "include",
                    "new", "this", "public", "private", "static", "const", "var", "let", "func",
                    "function", "def", "try", "catch", "throw", "finally"]
        }
    }

    /// Return built-in type names for a given language.
    static func builtinTypesForLanguage(_ language: String) -> [String] {
        switch language {
        case "swift":
            return ["String", "Int", "Double", "Float", "Bool", "Array", "Dictionary", "Set",
                    "Optional", "Any", "AnyObject", "Void", "Error", "Result", "Data", "URL",
                    "Date", "NSObject", "NSView", "NSWindow", "NSImage", "NSColor",
                    "UIView", "UIViewController", "CGFloat", "CGRect", "CGPoint", "CGSize"]
        case "python":
            return ["str", "int", "float", "bool", "list", "dict", "set", "tuple",
                    "bytes", "bytearray", "range", "type", "object", "Exception"]
        case "javascript", "typescript":
            return ["String", "Number", "Boolean", "Array", "Object", "Map", "Set",
                    "Promise", "Date", "RegExp", "Error", "Symbol", "BigInt",
                    "HTMLElement", "Document", "Window", "Event", "Response", "Request"]
        case "sql":
            return ["INT", "INTEGER", "VARCHAR", "TEXT", "BOOLEAN", "DATE", "TIMESTAMP",
                    "FLOAT", "DECIMAL", "CHAR", "BLOB", "SERIAL", "BIGINT"]
        case "rust":
            return ["i8", "i16", "i32", "i64", "i128", "isize", "u8", "u16", "u32", "u64",
                    "u128", "usize", "f32", "f64", "bool", "char", "str", "String", "Vec",
                    "Option", "Result", "Box", "Rc", "Arc", "Cell", "RefCell", "HashMap",
                    "HashSet", "BTreeMap", "BTreeSet"]
        case "go":
            return ["bool", "byte", "complex64", "complex128", "error", "float32", "float64",
                    "int", "int8", "int16", "int32", "int64", "rune", "string", "uint",
                    "uint8", "uint16", "uint32", "uint64", "uintptr", "any"]
        case "ocaml":
            return ["int", "float", "bool", "string", "char", "unit", "list", "array",
                    "option", "ref", "exn", "bytes"]
        case "c", "cpp":
            return ["size_t", "ptrdiff_t", "intptr_t", "uintptr_t",
                    "int8_t", "int16_t", "int32_t", "int64_t",
                    "uint8_t", "uint16_t", "uint32_t", "uint64_t",
                    "FILE", "NULL", "EOF",
                    // C++ standard library types
                    "string", "wstring", "vector", "map", "set", "list", "deque",
                    "array", "pair", "tuple", "optional", "variant", "any",
                    "unique_ptr", "shared_ptr", "weak_ptr",
                    "unordered_map", "unordered_set", "multimap", "multiset",
                    "function", "thread", "mutex", "future", "promise",
                    "iostream", "istream", "ostream", "ifstream", "ofstream"]
        case "java":
            return ["String", "Integer", "Long", "Double", "Float", "Boolean", "Character",
                    "Byte", "Short", "Object", "Class", "Void",
                    "List", "ArrayList", "LinkedList", "Map", "HashMap", "TreeMap",
                    "Set", "HashSet", "TreeSet", "Queue", "Deque", "Stack",
                    "Iterator", "Iterable", "Collection", "Collections", "Arrays",
                    "Optional", "Stream", "Comparable", "Comparator",
                    "Exception", "RuntimeException", "Thread", "Runnable",
                    "System", "Math", "StringBuilder", "StringBuffer"]
        case "csharp":
            return ["String", "Int32", "Int64", "Double", "Float", "Boolean", "Decimal",
                    "Object", "Byte", "Char", "DateTime", "TimeSpan", "Guid",
                    "List", "Dictionary", "HashSet", "Queue", "Stack", "Array",
                    "Task", "Action", "Func", "Predicate", "IEnumerable",
                    "ICollection", "IList", "IDictionary", "IDisposable",
                    "Console", "Math", "Convert", "Nullable", "Tuple",
                    "Exception", "EventHandler", "StringBuilder"]
        case "ruby":
            return ["String", "Integer", "Float", "Array", "Hash", "Symbol", "Regexp",
                    "Range", "NilClass", "TrueClass", "FalseClass", "Proc", "Lambda",
                    "IO", "File", "Dir", "Time", "Date", "Exception", "Struct",
                    "Enumerable", "Comparable", "Kernel", "Object", "Class", "Module",
                    "Numeric", "Fixnum", "Bignum", "Complex", "Rational"]
        case "php":
            return ["string", "int", "float", "bool", "array", "object", "null", "void",
                    "mixed", "callable", "iterable", "never", "self", "static", "parent",
                    "stdClass", "Exception", "Error", "Closure", "Generator",
                    "ArrayObject", "DateTime", "SplStack", "SplQueue"]
        case "kotlin":
            return ["Any", "Unit", "Nothing", "String", "Int", "Long", "Double", "Float",
                    "Boolean", "Char", "Byte", "Short", "Array", "IntArray", "LongArray",
                    "List", "MutableList", "Map", "MutableMap", "Set", "MutableSet",
                    "Pair", "Triple", "Sequence", "Iterable", "Iterator",
                    "Comparable", "Lazy", "Result", "Regex", "Exception"]
        case "lua":
            return ["io", "os", "math", "string", "table", "coroutine", "debug",
                    "package", "utf8"]
        default:
            return []
        }
    }

    // For testing
    func addEntry(_ entry: ClipboardEntry) {
        entries.insert(entry, at: 0)
        if entries.count > ClipboardManager.maxEntries {
            entries = Array(entries.prefix(ClipboardManager.maxEntries))
        }
        delegate?.clipboardManagerDidUpdateEntries(self)
        saveToDisk()
    }

    // MARK: - Persistence

    /// Save non-password entries to disk as JSON.
    /// Passwords are NEVER written to disk -- filtered out as a belt-and-suspenders measure.
    func saveToDisk() {
        guard let url = Self.persistenceURL else { return }
        let nonPasswordEntries = entries.filter { !$0.isPassword }
        do {
            let data = try JSONEncoder().encode(nonPasswordEntries)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        } catch {
            // Silently fail -- persistence is best-effort
        }
    }

    /// Load persisted entries from disk. Called once during init.
    /// Any password entries that somehow ended up on disk are filtered out on load.
    private func loadFromDisk() {
        guard let url = Self.persistenceURL,
              FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let loaded = try JSONDecoder().decode([ClipboardEntry].self, from: data)
            // Belt and suspenders: never load passwords from disk
            entries = loaded.filter { !$0.isPassword }
        } catch {
            // Corrupted file -- start fresh
            entries = []
        }
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
        saveToDisk()
    }
}
