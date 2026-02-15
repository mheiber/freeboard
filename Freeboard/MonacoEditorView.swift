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
        let contentType = mimeType == "application/wasm" ? mimeType : "\(mimeType); charset=utf-8"
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": contentType,
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
        case "wasm":        return "application/wasm"
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

    /// Heuristic language detection based on text content.
    /// This serves as a fallback hint for the JS-side detection in editor.html,
    /// which is the primary/authoritative detection engine.
    static func detectLanguage(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "plaintext" }

        // JSON: starts with { or [
        if let first = trimmed.first, first == "{" || first == "[" {
            // Quick validation: try to see if it parses
            if let data = trimmed.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                return "json"
            }
            // Still looks JSON-ish with "key": patterns
            if first == "{" && trimmed.range(of: #""[^"]*"\s*:"#, options: .regularExpression) != nil {
                return "json"
            }
        }

        // XML/HTML: starts with < and a tag-like pattern
        if trimmed.range(of: #"^<[?!a-zA-Z]"#, options: .regularExpression) != nil { return "xml" }

        // SQL: starts with SQL keywords
        let upper = trimmed.uppercased()
        let sqlStarts = ["SELECT ", "INSERT ", "UPDATE ", "DELETE ", "CREATE TABLE",
                         "ALTER TABLE", "DROP TABLE", "CREATE INDEX", "WITH "]
        for kw in sqlStarts {
            if upper.hasPrefix(kw) { return "sql" }
        }

        // Shell: shebang
        if trimmed.hasPrefix("#!/bin/") || trimmed.hasPrefix("#!/usr/bin/env") { return "shell" }

        // TOML: [section] headers and key = value patterns
        let tomlSections = trimmed.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^\[[\w.\-]+\]$"#, options: .regularExpression) != nil
        }.count
        let tomlKVs = trimmed.components(separatedBy: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).range(of: #"^[\w.\-]+\s*=\s*.+"#, options: .regularExpression) != nil
        }.count
        if tomlSections >= 1 && tomlKVs >= 2 { return "toml" }
        if tomlKVs >= 3 && !trimmed.contains("function ") && !trimmed.contains("def ")
            && !trimmed.contains("class ") && !trimmed.contains("const ") { return "toml" }

        // Markdown detection (HIGHER priority than code)
        let lines = trimmed.components(separatedBy: "\n")
        let sampleCount = min(lines.count, 100)
        var mdScore = 0
        for i in 0..<sampleCount {
            let ln = lines[i].trimmingCharacters(in: .whitespaces)
            if ln.range(of: #"^#{1,6}\s"#, options: .regularExpression) != nil { mdScore += 3 }
            if ln.hasPrefix("- ") || ln.hasPrefix("+ ") || (ln.hasPrefix("* ") && ln.count > 2) { mdScore += 1 }
            if ln.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil { mdScore += 1 }
            if ln.hasPrefix("```") || ln.hasPrefix("~~~") { mdScore += 3 }
            if ln.hasPrefix("> ") { mdScore += 1 }
            if ln.contains("](") && ln.contains("[") { mdScore += 2 }
            if ln.contains("**") || ln.contains("__") { mdScore += 1 }
        }
        if mdScore >= 3 { return "markdown" }

        // Rust: (check before Swift because both use func/struct/enum)
        if trimmed.contains("use std::") || trimmed.contains("use crate::") { return "rust" }
        if trimmed.contains("pub fn ") || trimmed.contains("pub struct ") || trimmed.contains("pub enum ") { return "rust" }
        if trimmed.range(of: #"\bfn\s+\w+\s*[\(<]"#, options: .regularExpression) != nil &&
           (trimmed.contains("let mut ") || trimmed.contains("-> ")) { return "rust" }
        if trimmed.range(of: #"\bimpl\s+\w+"#, options: .regularExpression) != nil && trimmed.contains("fn ") { return "rust" }
        if trimmed.contains("let mut ") && trimmed.contains("fn ") { return "rust" }
        if trimmed.range(of: #"\b(println|eprintln|format|vec|panic)!\s*\("#, options: .regularExpression) != nil { return "rust" }

        // Go: package + func, := operator, go func, chan
        if trimmed.contains("package ") && trimmed.contains("func ") { return "go" }
        if trimmed.contains("func ") && trimmed.contains(":=") { return "go" }
        if trimmed.range(of: #"\bfunc\s+\(\w+\s+\*?\w+\)\s+\w+"#, options: .regularExpression) != nil { return "go" }
        if trimmed.contains("go func(") || trimmed.contains("go func (") { return "go" }
        if trimmed.contains("chan ") || trimmed.contains("<-chan") { return "go" }
        if trimmed.contains("package main") { return "go" }
        if trimmed.contains("defer ") && trimmed.contains("func ") { return "go" }

        // OCaml: let rec, match...with, module...struct, sig...val
        if trimmed.contains("let ") && trimmed.contains("match") && trimmed.contains("with") &&
           !trimmed.contains("const ") && !trimmed.contains("var ") { return "ocaml" }
        if trimmed.contains("module ") && trimmed.contains("struct") &&
           trimmed.range(of: #"\bmodule\s+\w+\s*=\s*struct\b"#, options: .regularExpression) != nil { return "ocaml" }
        if trimmed.contains("sig") && trimmed.contains("val") &&
           !trimmed.contains("const ") && !trimmed.contains("function ") { return "ocaml" }
        if trimmed.range(of: #"\blet\s+rec\s+\w+"#, options: .regularExpression) != nil { return "ocaml" }
        if trimmed.range(of: #"\bfun\s+\w+\s*->"#, options: .regularExpression) != nil { return "ocaml" }

        // jq: pipe-heavy with field access, select/map, @format
        if trimmed.range(of: #"\|\s*(select|map|keys|values|length|sort_by|group_by)\s*\("#, options: .regularExpression) != nil &&
           trimmed.contains(".") { return "jq" }
        if trimmed.range(of: #"@(csv|tsv|json|text|html|base64|base64d|uri|sh)\b"#, options: .regularExpression) != nil &&
           trimmed.contains("|") { return "jq" }

        // Swift: specific imports
        let swiftImports = ["import Foundation", "import UIKit", "import SwiftUI",
                            "import Cocoa", "import AppKit", "import Combine", "import CoreData"]
        for imp in swiftImports {
            if trimmed.contains(imp) { return "swift" }
        }
        // Swift: guard let, if let, @objc, @IBOutlet
        if trimmed.contains("guard let ") || trimmed.contains("if let ") { return "swift" }
        if trimmed.contains("@objc") || trimmed.contains("@IBOutlet") || trimmed.contains("@IBAction") { return "swift" }
        // Swift: func + (let/var or ->)
        if trimmed.contains("func ") && (trimmed.contains("-> ") || trimmed.contains("let ") || trimmed.contains("var ")) { return "swift" }

        // Python: def/class with colon, if __name__
        if trimmed.contains("if __name__") { return "python" }
        if trimmed.range(of: #"\bdef\s+\w+\s*\("#, options: .regularExpression) != nil &&
           trimmed.contains(":") { return "python" }
        // Python-style imports (but not JS-style "import X from")
        if trimmed.range(of: #"^(from|import)\s+\w+"#, options: .regularExpression) != nil &&
           !trimmed.contains("function ") && !trimmed.contains("const ") { return "python" }

        // TypeScript: interface/type declarations with type annotations
        if trimmed.contains("interface ") && trimmed.contains("{") { return "typescript" }

        // JavaScript: function, const/let with =>, require, module.exports
        if trimmed.contains("function ") || trimmed.contains("=> ") { return "javascript" }
        if trimmed.contains("module.exports") || trimmed.contains("require(") { return "javascript" }
        if trimmed.contains("const ") || trimmed.contains("let ") {
            if trimmed.contains("= ") { return "javascript" }
        }

        // Shell: broader patterns
        if trimmed.hasPrefix("export ") || trimmed.hasPrefix("alias ") { return "shell" }
        if trimmed.contains("| grep") || trimmed.contains("| awk") { return "shell" }

        return "plaintext"
    }
}
