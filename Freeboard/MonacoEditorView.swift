import Cocoa
import WebKit

protocol MonacoEditorDelegate: AnyObject {
    func editorDidSave(content: String)
    func editorDidClose()
}

class MonacoEditorView: NSView, WKScriptMessageHandler, WKNavigationDelegate {

    weak var delegate: MonacoEditorDelegate?
    private var webView: WKWebView!
    private var isLoaded = false
    private var pendingContent: (text: String, language: String, vimEnabled: Bool)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(self, name: "editorBridge")
        config.userContentController = userContentController
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        webView = WKWebView(frame: bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        addSubview(webView)
    }

    func loadEditor() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let monacoDir = resourceURL.appendingPathComponent("MonacoEditor")
        let htmlFile = monacoDir.appendingPathComponent("editor.html")

        guard FileManager.default.fileExists(atPath: htmlFile.path) else {
            NSLog("MonacoEditorView: editor.html not found at \(htmlFile.path)")
            return
        }

        webView.loadFileURL(htmlFile, allowingReadAccessTo: monacoDir)
    }

    func setContent(_ text: String, language: String) {
        let vimEnabled = UserDefaults.standard.bool(forKey: "vimModeEnabled")
        if isLoaded {
            evaluateSetContent(text: text, language: language, vimEnabled: vimEnabled)
        } else {
            pendingContent = (text, language, vimEnabled)
        }
    }

    private func evaluateSetContent(text: String, language: String, vimEnabled: Bool) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = "setContent(`\(escaped)`, '\(language)', \(vimEnabled));"
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                NSLog("MonacoEditorView setContent error: \(error)")
            }
        }
    }

    func getContent(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("getContent()") { result, _ in
            completion(result as? String ?? "")
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded = true
        if let pending = pendingContent {
            evaluateSetContent(text: pending.text, language: pending.language, vimEnabled: pending.vimEnabled)
            pendingContent = nil
        }
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "save":
            let content = body["content"] as? String ?? ""
            delegate?.editorDidSave(content: content)
        case "close":
            delegate?.editorDidClose()
        default:
            break
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "editorBridge")
    }

    // MARK: - Syntax Detection

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
