import Cocoa
import WebKit

protocol MonacoEditorDelegate: AnyObject {
    func editorDidSave(content: String)
    func editorDidClose()
}

/// Serves Monaco editor resources from the app bundle via a custom URL scheme.
/// This sidesteps WKWebView's file-access restrictions entirely — the web process
/// never touches the filesystem; our Swift code reads files and serves them.
private class MonacoSchemeHandler: NSObject, WKURLSchemeHandler {
    let baseDir: URL

    init(baseDir: URL) {
        self.baseDir = baseDir
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        var path = url.path
        if path.hasPrefix("/") { path = String(path.dropFirst()) }
        if path.isEmpty { path = "editor.html" }

        let fileURL = baseDir.appendingPathComponent(path)

        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mimeType = Self.mimeType(for: fileURL.pathExtension)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "\(mimeType); charset=utf-8",
                "Content-Length": "\(data.count)",
                "Access-Control-Allow-Origin": "*"
            ]
        )!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html":        return "text/html"
        case "js":          return "application/javascript"
        case "css":         return "text/css"
        case "json", "map": return "application/json"
        case "svg":         return "image/svg+xml"
        case "ttf":         return "font/ttf"
        case "woff":        return "font/woff"
        case "woff2":       return "font/woff2"
        default:            return "application/octet-stream"
        }
    }
}

class MonacoEditorView: NSView, WKScriptMessageHandler, WKNavigationDelegate {

    weak var delegate: MonacoEditorDelegate?
    private var webView: WKWebView!
    private var schemeHandler: MonacoSchemeHandler?
    private var pendingContent: (text: String, language: String)?
    private(set) var isEditorReady = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupWebView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }

    private func setupWebView() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let monacoDir = resourceURL.appendingPathComponent("MonacoEditor")

        let handler = MonacoSchemeHandler(baseDir: monacoDir)
        schemeHandler = handler

        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(handler, forURLScheme: "monaco-editor")

        let contentController = WKUserContentController()
        contentController.add(self, name: "editorBridge")
        let errorScript = WKUserScript(source: """
            window.onerror = function(msg, url, line, col, error) {
                window.webkit.messageHandlers.editorBridge.postMessage({
                    type: 'jsError', message: String(msg), url: String(url || ''), line: line, col: col
                });
                return true;
            };
            """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        contentController.addUserScript(errorScript)
        config.userContentController = contentController

        webView = WKWebView(frame: bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1).cgColor

        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    // MARK: - Public API

    func loadEditor() {
        guard let url = URL(string: "monaco-editor://app/editor.html") else { return }
        webView.load(URLRequest(url: url))
    }

    func focusEditor() {
        window?.makeFirstResponder(webView)
        webView.evaluateJavaScript("""
            if (typeof monaco !== 'undefined' && document.querySelector('.monaco-editor')) {
                var editors = monaco.editor.getEditors();
                if (editors.length > 0) {
                    editors[0].layout();
                    editors[0].focus();
                }
            }
            """) { _, _ in }
    }

    func setContent(_ text: String, language: String) {
        let vimEnabled = UserDefaults.standard.bool(forKey: "vimModeEnabled")

        guard let textData = try? JSONEncoder().encode(text),
              let textJSON = String(data: textData, encoding: .utf8) else { return }

        guard isEditorReady else {
            pendingContent = (text, language)
            return
        }

        let js = "window.setContent(\(textJSON), '\(language)', \(vimEnabled));"

        webView.evaluateJavaScript(js) { [weak self] _, error in
            if error != nil {
                self?.pendingContent = (text, language)
            }
        }
    }

    func getContent(completion: @escaping (String) -> Void) {
        webView.evaluateJavaScript("window.getContent()") { result, _ in
            completion(result as? String ?? "")
        }
    }

    func triggerSaveAndClose() {
        getContent { [weak self] content in
            self?.delegate?.editorDidSave(content: content)
        }
    }

    func cleanup() {}

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "save":
            if let content = body["content"] as? String {
                delegate?.editorDidSave(content: content)
            }
        case "close":
            delegate?.editorDidClose()
        case "editorReady":
            isEditorReady = true
            if let pending = pendingContent {
                pendingContent = nil
                setContent(pending.text, language: pending.language)
            }
        default:
            break
        }
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let pending = pendingContent {
            pendingContent = nil
            setContent(pending.text, language: pending.language)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {}

    // MARK: - Syntax Detection

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
