import Cocoa

protocol MonacoEditorDelegate: AnyObject {
    func editorDidSave(content: String)
    func editorDidClose()
}

/// Custom NSTextView subclass that intercepts Esc and Tab for save/close
private class EditorTextView: NSTextView {
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        NSLog("[DEBUG EditorTextView] keyDown: keyCode=\(event.keyCode) chars='\(event.characters ?? "")' firstResponder=\(window?.firstResponder === self)")
        if event.keyCode == 53 { // Esc
            NSLog("[DEBUG EditorTextView] Esc → save and close")
            onEscape?()
            return
        }
        if event.keyCode == 48 { // Tab
            NSLog("[DEBUG EditorTextView] Tab → save and close")
            onTab?()
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

        textView.onEscape = { [weak self] in
            self?.saveAndClose()
        }
        textView.onTab = { [weak self] in
            self?.saveAndClose()
        }

        editorScrollView.documentView = textView
        addSubview(editorScrollView)

        NSLayoutConstraint.activate([
            debugLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            debugLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            debugLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            editorScrollView.topAnchor.constraint(equalTo: debugLabel.bottomAnchor, constant: 2),
            editorScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        NSLog("[DEBUG MonacoEditorView] setupEditor complete")
    }

    func loadEditor() {
        NSLog("[DEBUG MonacoEditorView] loadEditor — native NSTextView ready immediately")
        updateDebugLabel("Editor ready (native NSTextView)")
    }

    func setContent(_ text: String, language: String) {
        NSLog("[DEBUG MonacoEditorView] setContent: \(text.count) chars, language=\(language)")
        textView.string = text
        updateDebugLabel("Editing \(text.count) chars | \(language) | Esc or Tab → save+close")

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

    /// Save content and close the editor (used by Tab key shortcut)
    func triggerSaveAndClose() {
        NSLog("[DEBUG MonacoEditorView] triggerSaveAndClose")
        saveAndClose()
    }

    // MARK: - Cleanup

    func cleanup() {
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

        // JSON: starts with { or [
        if let first = trimmed.first, first == "{" || first == "[" {
            return "json"
        }

        // XML/HTML: starts with <
        if trimmed.hasPrefix("<") {
            return "xml"
        }

        let upper = trimmed.uppercased()

        // SQL: common keywords
        let sqlKeywords = ["SELECT ", "INSERT ", "UPDATE ", "DELETE ", "CREATE TABLE", "ALTER TABLE",
                           "DROP TABLE", "CREATE INDEX", "SELECT\n", "INSERT\n"]
        for kw in sqlKeywords {
            if upper.hasPrefix(kw) || upper.contains("\n\(kw)") {
                return "sql"
            }
        }

        // Shell: shebang or common patterns
        if trimmed.hasPrefix("#!/bin/") || trimmed.hasPrefix("#!/usr/bin/env") {
            return "shell"
        }
        if trimmed.hasPrefix("export ") || trimmed.hasPrefix("alias ") ||
           trimmed.contains("| grep") || trimmed.contains("$(") {
            return "shell"
        }

        // Markdown
        let lines = trimmed.components(separatedBy: "\n")
        var markdownScore = 0
        for line in lines {
            let ln = line.trimmingCharacters(in: .whitespaces)
            if ln.range(of: "^#{1,6} ", options: .regularExpression) != nil {
                markdownScore += 2
            }
            if ln.hasPrefix("- ") || ln.hasPrefix("+ ") ||
               (ln.hasPrefix("* ") && ln.count > 2) {
                markdownScore += 1
            }
            if ln.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                markdownScore += 1
            }
            if ln.hasPrefix("```") || ln.hasPrefix("~~~") {
                markdownScore += 2
            }
            if ln.hasPrefix("> ") {
                markdownScore += 1
            }
            if ln.contains("](") && ln.contains("[") {
                markdownScore += 2
            }
            if ln.contains("**") || ln.contains("__") {
                markdownScore += 1
            }
        }
        if markdownScore >= 2 {
            return "markdown"
        }

        // Python
        let pythonPatterns = ["def ", "import ", "from ", "class ", "if __name__", "print("]
        for pat in pythonPatterns {
            if trimmed.contains(pat) {
                return "python"
            }
        }

        // Swift
        if trimmed.contains("func ") && (trimmed.contains("-> ") || trimmed.contains("let ") || trimmed.contains("var ")) {
            return "swift"
        }
        if trimmed.contains("import Foundation") || trimmed.contains("import UIKit") ||
           trimmed.contains("import SwiftUI") || trimmed.contains("import Cocoa") {
            return "swift"
        }

        // JavaScript/TypeScript
        let jsPatterns = ["function ", "const ", "=> ", "require(", "module.exports", "async "]
        for pat in jsPatterns {
            if trimmed.contains(pat) {
                return "javascript"
            }
        }
        if trimmed.contains("interface ") && trimmed.contains(": ") {
            return "typescript"
        }

        return "plaintext"
    }
}
