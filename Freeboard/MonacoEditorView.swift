import Cocoa

protocol MonacoEditorDelegate: AnyObject {
    func editorDidSave(content: String)
    func editorDidClose()
}

/// Custom NSTextView subclass that delegates all key handling to the parent MonacoEditorView
private class EditorTextView: NSTextView {
    var keyHandler: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if let handler = keyHandler, handler(event) {
            return
        }
        super.keyDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        NSLog("[DEBUG EditorTextView] becomeFirstResponder")
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        NSLog("[DEBUG EditorTextView] resignFirstResponder")
        return super.resignFirstResponder()
    }
}

class MonacoEditorView: NSView {

    weak var delegate: MonacoEditorDelegate?
    private var editorScrollView: NSScrollView!
    private var textView: EditorTextView!
    private var debugLabel: NSTextField!
    private var statusLabel: NSTextField!  // vim mode indicator / help hints

    // Vim state
    private var vimEnabled = false
    private enum VimMode { case insert, normal, command }
    private var vimMode: VimMode = .insert
    private var jkTimer: Timer?
    private var pendingG = false
    private var pendingZ = false
    private var commandBuffer = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        NSLog("[DEBUG MonacoEditorView] init frame=\(frameRect)")
        setupEditor()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        NSLog("[DEBUG MonacoEditorView] init(coder)")
        setupEditor()
    }

    private func setupEditor() {
        wantsLayer = true
        layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1).cgColor

        // Debug label — bright yellow for visibility through CRT effects
        debugLabel = NSTextField(labelWithString: "[DEBUG] Editor initializing...")
        debugLabel.translatesAutoresizingMaskIntoConstraints = false
        debugLabel.font = NSFont(name: "Menlo", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .bold)
        debugLabel.textColor = NSColor.yellow
        debugLabel.backgroundColor = NSColor(red: 0.2, green: 0.1, blue: 0, alpha: 0.9)
        debugLabel.drawsBackground = true
        debugLabel.maximumNumberOfLines = 2
        addSubview(debugLabel)

        // Scroll view for text editor
        editorScrollView = NSScrollView()
        editorScrollView.translatesAutoresizingMaskIntoConstraints = false
        editorScrollView.hasVerticalScroller = true
        editorScrollView.drawsBackground = true
        editorScrollView.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
        editorScrollView.scrollerStyle = .overlay

        let contentSize = NSSize(width: 400, height: 300)
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: .greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        textView = EditorTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
        textView.textColor = NSColor(red: 0.83, green: 0.83, blue: 0.83, alpha: 1) // #d4d4d4
        textView.insertionPointColor = NSColor(red: 0, green: 1, blue: 0.25, alpha: 1) // #00ff40
        textView.font = NSFont(name: "Menlo", size: 14) ?? .monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isRichText = false
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(red: 0, green: 0.23, blue: 0.05, alpha: 0.53)
        ]
        textView.allowsUndo = true
        textView.setAccessibilityLabel(L.accessibilityTextEditor)
        textView.setAccessibilityRole(.textArea)

        textView.keyHandler = { [weak self] event in
            self?.handleKeyDown(event) ?? false
        }

        editorScrollView.documentView = textView
        addSubview(editorScrollView)

        // Status label at bottom — mode indicator + hints (like vim status line)
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = .clear
        statusLabel.isEditable = false
        statusLabel.isBezeled = false
        statusLabel.alignment = .left
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            debugLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            debugLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            editorScrollView.topAnchor.constraint(equalTo: debugLabel.bottomAnchor, constant: 2),
            editorScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorScrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor),

            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.heightAnchor.constraint(equalToConstant: 18),
        ])

        NSLog("[DEBUG MonacoEditorView] setupEditor complete")
    }

    // MARK: - Status line

    private func updateStatusLine() {
        let retroGreen = NSColor(red: 0.0, green: 1.0, blue: 0.25, alpha: 1.0)
        let retroDimGreen = NSColor(red: 0.0, green: 0.75, blue: 0.19, alpha: 1.0)
        let smallFont = NSFont(name: "Menlo", size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular)
        let modeAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.8),
            .font: smallFont
        ]
        let keyAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroGreen.withAlphaComponent(0.6),
            .font: smallFont
        ]
        let dimAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: retroDimGreen.withAlphaComponent(0.6),
            .font: smallFont
        ]

        let str = NSMutableAttributedString()

        if !vimEnabled {
            str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
            str.append(NSAttributedString(string: L.saveAndClose, attributes: dimAttrs))
        } else {
            switch vimMode {
            case .insert:
                str.append(NSAttributedString(string: "-- INSERT --", attributes: modeAttrs))
                str.append(NSAttributedString(string: "    ", attributes: dimAttrs))
                str.append(NSAttributedString(string: "Esc/jk ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.vimNormalMode, attributes: dimAttrs))
            case .normal:
                str.append(NSAttributedString(string: "-- NORMAL --", attributes: modeAttrs))
                str.append(NSAttributedString(string: "    ", attributes: dimAttrs))
                str.append(NSAttributedString(string: "i ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.vimInsertMode + "  ", attributes: dimAttrs))
                str.append(NSAttributedString(string: ":x ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.saveAndClose + "  ", attributes: dimAttrs))
                str.append(NSAttributedString(string: "Esc ", attributes: keyAttrs))
                str.append(NSAttributedString(string: L.vimGoBack, attributes: dimAttrs))
            case .command:
                str.append(NSAttributedString(string: commandBuffer, attributes: modeAttrs))
            }
        }

        statusLabel.attributedStringValue = str
    }

    // MARK: - Cursor style

    private func updateCursorForMode() {
        let text = textView.string as NSString
        let pos = textView.selectedRange().location

        if vimMode == .normal {
            // Block cursor: bright green bg with dark text, like a real terminal
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0, green: 1.0, blue: 0.25, alpha: 0.85),
                .foregroundColor: NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
            ]
            if pos < text.length {
                textView.setSelectedRange(NSRange(location: pos, length: 1))
            }
        } else {
            // Insert mode: subtle selection for user-selected text
            textView.selectedTextAttributes = [
                .backgroundColor: NSColor(red: 0, green: 0.23, blue: 0.05, alpha: 0.53)
            ]
            textView.setSelectedRange(NSRange(location: pos, length: 0))
        }
    }

    /// After a normal-mode motion, re-apply block cursor at new position
    private func setNormalCursor(at pos: Int) {
        let text = textView.string as NSString
        var p = min(pos, text.length > 0 ? text.length - 1 : 0)
        // Don't land on a newline — back up to the last printable char
        while p > 0 && p < text.length && text.character(at: p) == 0x0A {
            p -= 1
        }
        if p < text.length {
            textView.setSelectedRange(NSRange(location: p, length: 1))
        } else {
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    // MARK: - Key handling

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let key = event.charactersIgnoringModifiers ?? ""
        NSLog("[DEBUG Editor] keyDown: keyCode=\(keyCode) key='\(key)' vim=\(vimEnabled) mode=\(vimMode)")

        if !vimEnabled {
            if keyCode == 53 {
                NSLog("[DEBUG Editor] Esc → save+close (non-vim)")
                saveAndClose()
                return true
            }
            return false
        }

        switch vimMode {
        case .insert:  return handleVimInsert(event)
        case .normal:  return handleVimNormal(event)
        case .command: return handleVimCommand(event)
        }
    }

    private func handleVimInsert(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let key = event.charactersIgnoringModifiers ?? ""

        if keyCode == 53 {
            NSLog("[DEBUG Vim] Esc → normal mode")
            enterNormalMode()
            return true
        }

        // jk detection
        if key == "j" {
            jkTimer?.invalidate()
            jkTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                self?.jkTimer = nil
            }
            return false // let j be typed normally
        }
        if key == "k", jkTimer != nil {
            jkTimer?.invalidate()
            jkTimer = nil
            NSLog("[DEBUG Vim] jk → normal mode")
            if let storage = textView.textStorage, storage.length > 0 {
                let cursorPos = textView.selectedRange().location
                if cursorPos > 0 {
                    textView.setSelectedRange(NSRange(location: cursorPos - 1, length: 1))
                    textView.delete(nil)
                }
            }
            enterNormalMode()
            return true
        }

        return false
    }

    private func handleVimNormal(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let key = event.characters ?? ""

        // Esc → save and close (go back)
        if keyCode == 53 {
            NSLog("[DEBUG Vim] Esc → save+close (normal mode)")
            saveAndClose()
            return true
        }

        // ZZ handling
        if pendingZ {
            pendingZ = false
            if key == "Z" {
                NSLog("[DEBUG Vim] ZZ → save+close")
                saveAndClose()
                return true
            }
        }

        // gg handling
        if pendingG {
            pendingG = false
            if key == "g" {
                NSLog("[DEBUG Vim] gg → top of file")
                setNormalCursor(at: 0)
                textView.scrollRangeToVisible(textView.selectedRange())
                return true
            }
        }

        let text = textView.string as NSString
        let range = textView.selectedRange()
        let pos = range.location

        switch key {
        // Enter command mode
        case ":":
            commandBuffer = ":"
            vimMode = .command
            updateStatusLine()
            NSLog("[DEBUG Vim] entering command mode")
            return true

        case "i":
            textView.setSelectedRange(NSRange(location: pos, length: 0))
            NSLog("[DEBUG Vim] i → insert mode")
            enterInsertMode()
            return true

        case "I":
            // I → first non-whitespace of line
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            var firstNonWS = lineRange.location
            while firstNonWS < lineRange.location + lineRange.length {
                let ch = text.character(at: firstNonWS)
                if ch != 0x20 && ch != 0x09 { break }
                firstNonWS += 1
            }
            textView.setSelectedRange(NSRange(location: firstNonWS, length: 0))
            NSLog("[DEBUG Vim] I → insert mode (line start)")
            enterInsertMode()
            return true

        case "a":
            let newPos = min(pos + 1, text.length)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
            enterInsertMode()
            return true

        case "A":
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            var end = lineRange.location + lineRange.length
            if end > lineRange.location && end <= text.length && text.character(at: end - 1) == 0x0A {
                end -= 1
            }
            textView.setSelectedRange(NSRange(location: end, length: 0))
            enterInsertMode()
            return true

        case "o":
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            let lineEnd = lineRange.location + lineRange.length
            textView.setSelectedRange(NSRange(location: lineEnd, length: 0))
            textView.insertText("\n", replacementRange: NSRange(location: lineEnd, length: 0))
            enterInsertMode()
            return true

        case "O":
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            textView.insertText("\n", replacementRange: NSRange(location: lineRange.location, length: 0))
            textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
            enterInsertMode()
            return true

        case "g":
            pendingG = true
            return true

        case "G":
            setNormalCursor(at: text.length > 0 ? text.length - 1 : 0)
            textView.scrollRangeToVisible(textView.selectedRange())
            return true

        case "Z":
            pendingZ = true
            return true

        case "h":
            if pos > 0 { setNormalCursor(at: pos - 1) }
            return true

        case "j":
            // Move down: get current line, find same column on next line
            textView.setSelectedRange(NSRange(location: pos, length: 0))
            textView.moveDown(nil)
            let newPos = textView.selectedRange().location
            setNormalCursor(at: newPos)
            return true

        case "k":
            textView.setSelectedRange(NSRange(location: pos, length: 0))
            textView.moveUp(nil)
            let newPos = textView.selectedRange().location
            setNormalCursor(at: newPos)
            return true

        case "l":
            if pos + 1 < text.length {
                setNormalCursor(at: pos + 1)
            }
            return true

        case "w":
            if pos < text.length {
                var i = pos
                while i < text.length && isWordChar(text.character(at: i)) { i += 1 }
                while i < text.length && !isWordChar(text.character(at: i)) { i += 1 }
                setNormalCursor(at: i)
                textView.scrollRangeToVisible(textView.selectedRange())
            }
            return true

        case "b":
            if pos > 0 {
                var i = pos - 1
                while i > 0 && !isWordChar(text.character(at: i)) { i -= 1 }
                while i > 0 && isWordChar(text.character(at: i - 1)) { i -= 1 }
                setNormalCursor(at: i)
                textView.scrollRangeToVisible(textView.selectedRange())
            }
            return true

        case "0":
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            setNormalCursor(at: lineRange.location)
            return true

        case "$":
            let lineRange = text.lineRange(for: NSRange(location: pos, length: 0))
            var end = lineRange.location + lineRange.length
            if end > lineRange.location && end <= text.length && text.character(at: end - 1) == 0x0A {
                end -= 1
            }
            setNormalCursor(at: max(end - 1, lineRange.location))
            return true

        case "x":
            if pos < text.length {
                textView.setSelectedRange(NSRange(location: pos, length: 1))
                textView.delete(nil)
                setNormalCursor(at: pos)
            }
            return true

        case "u":
            textView.undoManager?.undo()
            let newPos = textView.selectedRange().location
            setNormalCursor(at: newPos)
            return true

        default:
            return true // consume all keys in normal mode
        }
    }

    private func handleVimCommand(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode
        let key = event.characters ?? ""

        // Esc → cancel command, back to normal
        if keyCode == 53 {
            NSLog("[DEBUG Vim] Esc → cancel command mode")
            commandBuffer = ""
            vimMode = .normal
            updateStatusLine()
            return true
        }

        // Enter → execute command
        if keyCode == 36 {
            NSLog("[DEBUG Vim] execute command: '\(commandBuffer)'")
            let cmd = commandBuffer.lowercased()
            commandBuffer = ""
            vimMode = .normal

            switch cmd {
            case ":x", ":wq":
                saveAndClose()
            case ":w":
                // Save but don't close
                delegate?.editorDidSave(content: textView.string)
            case ":q", ":q!":
                delegate?.editorDidClose()
            default:
                NSLog("[DEBUG Vim] unknown command: \(cmd)")
                updateStatusLine()
            }
            return true
        }

        // Backspace
        if keyCode == 51 {
            if commandBuffer.count > 1 {
                commandBuffer.removeLast()
            } else {
                // Backspace on just ":" → cancel
                commandBuffer = ""
                vimMode = .normal
            }
            updateStatusLine()
            return true
        }

        // Accumulate command characters
        commandBuffer += key
        updateStatusLine()
        return true
    }

    private func isWordChar(_ ch: unichar) -> Bool {
        let c = Character(UnicodeScalar(ch)!)
        return c.isLetter || c.isNumber || c == "_"
    }

    private func enterNormalMode() {
        vimMode = .normal
        jkTimer?.invalidate()
        jkTimer = nil
        pendingG = false
        pendingZ = false
        commandBuffer = ""
        updateCursorForMode()
        updateStatusLine()
        updateDebugLabel("NORMAL MODE")
        NSLog("[DEBUG Vim] entered normal mode")
    }

    private func enterInsertMode() {
        vimMode = .insert
        pendingG = false
        pendingZ = false
        commandBuffer = ""
        updateCursorForMode()
        updateStatusLine()
        updateDebugLabel("INSERT MODE")
        NSLog("[DEBUG Vim] entered insert mode")
    }

    // MARK: - Public API

    func loadEditor() {
        NSLog("[DEBUG MonacoEditorView] loadEditor — native NSTextView ready immediately")
        updateDebugLabel("Editor ready (native NSTextView)")
    }

    func setContent(_ text: String, language: String) {
        vimEnabled = UserDefaults.standard.bool(forKey: "vimModeEnabled")
        vimMode = .insert
        NSLog("[DEBUG MonacoEditorView] setContent: \(text.count) chars, language=\(language), vim=\(vimEnabled)")
        textView.string = text
        updateStatusLine()
        if vimEnabled {
            updateDebugLabel("INSERT MODE | \(text.count) chars | \(language)")
        } else {
            updateDebugLabel("Editing \(text.count) chars | \(language)")
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.textView.window else {
                NSLog("[DEBUG MonacoEditorView] setContent: no window available for focus")
                return
            }
            let ok = window.makeFirstResponder(self.textView)
            NSLog("[DEBUG MonacoEditorView] makeFirstResponder → \(ok)")
        }
    }

    func getContent(completion: @escaping (String) -> Void) {
        completion(textView.string)
    }

    func triggerSaveAndClose() {
        NSLog("[DEBUG MonacoEditorView] triggerSaveAndClose")
        saveAndClose()
    }

    // MARK: - Cleanup

    func cleanup() {
        jkTimer?.invalidate()
        jkTimer = nil
        NSLog("[DEBUG MonacoEditorView] cleanup")
    }

    // MARK: - Private

    private func saveAndClose() {
        let content = textView.string
        NSLog("[DEBUG MonacoEditorView] saveAndClose: \(content.count) chars")
        delegate?.editorDidSave(content: content)
    }

    private func updateDebugLabel(_ text: String) {
        debugLabel.stringValue = "[DEBUG] \(text)"
    }

    // MARK: - Syntax Detection (kept for future use)

    static func detectLanguage(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "plaintext" }

        if let first = trimmed.first, first == "{" || first == "[" { return "json" }
        if trimmed.hasPrefix("<") { return "xml" }

        let upper = trimmed.uppercased()
        let sqlKeywords = ["SELECT ", "INSERT ", "UPDATE ", "DELETE ", "CREATE TABLE", "ALTER TABLE",
                           "DROP TABLE", "CREATE INDEX", "SELECT\n", "INSERT\n"]
        for kw in sqlKeywords {
            if upper.hasPrefix(kw) || upper.contains("\n\(kw)") { return "sql" }
        }

        if trimmed.hasPrefix("#!/bin/") || trimmed.hasPrefix("#!/usr/bin/env") { return "shell" }
        if trimmed.hasPrefix("export ") || trimmed.hasPrefix("alias ") ||
           trimmed.contains("| grep") || trimmed.contains("$(") { return "shell" }

        let lines = trimmed.components(separatedBy: "\n")
        var markdownScore = 0
        for line in lines {
            let ln = line.trimmingCharacters(in: .whitespaces)
            if ln.range(of: "^#{1,6} ", options: .regularExpression) != nil { markdownScore += 2 }
            if ln.hasPrefix("- ") || ln.hasPrefix("+ ") || (ln.hasPrefix("* ") && ln.count > 2) { markdownScore += 1 }
            if ln.range(of: "^\\d+\\. ", options: .regularExpression) != nil { markdownScore += 1 }
            if ln.hasPrefix("```") || ln.hasPrefix("~~~") { markdownScore += 2 }
            if ln.hasPrefix("> ") { markdownScore += 1 }
            if ln.contains("](") && ln.contains("[") { markdownScore += 2 }
            if ln.contains("**") || ln.contains("__") { markdownScore += 1 }
        }
        if markdownScore >= 2 { return "markdown" }

        let pythonPatterns = ["def ", "import ", "from ", "class ", "if __name__", "print("]
        for pat in pythonPatterns { if trimmed.contains(pat) { return "python" } }

        if trimmed.contains("func ") && (trimmed.contains("-> ") || trimmed.contains("let ") || trimmed.contains("var ")) { return "swift" }
        if trimmed.contains("import Foundation") || trimmed.contains("import UIKit") ||
           trimmed.contains("import SwiftUI") || trimmed.contains("import Cocoa") { return "swift" }

        let jsPatterns = ["function ", "const ", "=> ", "require(", "module.exports", "async "]
        for pat in jsPatterns { if trimmed.contains(pat) { return "javascript" } }
        if trimmed.contains("interface ") && trimmed.contains(": ") { return "typescript" }

        return "plaintext"
    }
}
