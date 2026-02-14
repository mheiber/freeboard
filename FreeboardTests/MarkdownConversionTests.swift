import XCTest
import AppKit

class MarkdownConversionTests: XCTestCase {

    // MARK: - Markdown scoring

    func testPlainTextHasZeroScore() {
        XCTAssertEqual(ClipboardEntry.markdownScore("Hello world"), 0)
        XCTAssertEqual(ClipboardEntry.markdownScore("Just a simple sentence."), 0)
    }

    func testHeadingsScoreTwo() {
        XCTAssertEqual(ClipboardEntry.markdownScore("# Heading"), 2)
        XCTAssertEqual(ClipboardEntry.markdownScore("## Subheading"), 2)
        XCTAssertEqual(ClipboardEntry.markdownScore("### Third level"), 2)
    }

    func testMultipleMarkdownElementsAccumulate() {
        let md = """
        # Title
        - item 1
        - item 2
        """
        let score = ClipboardEntry.markdownScore(md)
        XCTAssertGreaterThanOrEqual(score, 4) // heading(2) + 2 list items(2)
    }

    func testCodeFencesScoreTwo() {
        let md = """
        ```swift
        let x = 1
        ```
        """
        let score = ClipboardEntry.markdownScore(md)
        XCTAssertGreaterThanOrEqual(score, 4) // two fences
    }

    func testBoldScoresOne() {
        XCTAssertEqual(ClipboardEntry.markdownScore("This is **bold** text"), 1)
    }

    func testLinksScoreTwo() {
        XCTAssertEqual(ClipboardEntry.markdownScore("[click here](https://example.com)"), 2)
    }

    func testBlockquoteScoresOne() {
        XCTAssertEqual(ClipboardEntry.markdownScore("> quoted text"), 1)
    }

    func testOrderedListScoresOne() {
        XCTAssertEqual(ClipboardEntry.markdownScore("1. First item"), 1)
    }

    func testThresholdForClassification() {
        // Score of 2 should NOT trigger isMarkdownContent (threshold is 3)
        let lowMd = "## Heading"
        let entry = ClipboardEntry(content: lowMd)
        XCTAssertFalse(entry.isMarkdownContent, "Score 2 should not classify as markdown")

        // Score of 3+ should trigger
        let highMd = "## Heading\n- item"
        let entry2 = ClipboardEntry(content: highMd)
        XCTAssertTrue(entry2.isMarkdownContent, "Score 3+ should classify as markdown")
    }

    // MARK: - Format category classification

    func testPlainTextCategory() {
        let entry = ClipboardEntry(content: "Hello world")
        XCTAssertEqual(entry.formatCategory, .other)
    }

    func testMarkdownCategory() {
        let md = """
        # Title
        ## Subtitle
        - item 1
        - item 2
        """
        let entry = ClipboardEntry(content: md)
        XCTAssertEqual(entry.formatCategory, .markdown)
    }

    func testRichTextIsOther() {
        let rtfData = "{\\rtf1 Hello}".data(using: .utf8)!
        let entry = ClipboardEntry(
            content: "Hello",
            pasteboardData: [.rtf: rtfData, .string: "Hello".data(using: .utf8)!]
        )
        XCTAssertEqual(entry.formatCategory, .other)
    }

    func testRichMarkdownIsStillMarkdown() {
        let htmlData = "<h1>Title</h1><ul><li>item</li></ul>".data(using: .utf8)!
        let md = """
        # Title
        ## Subtitle
        - item 1
        - item 2
        """
        let entry = ClipboardEntry(
            content: md,
            pasteboardData: [.html: htmlData, .string: md.data(using: .utf8)!]
        )
        XCTAssertEqual(entry.formatCategory, .markdown)
    }

    func testImageEntryIsOther() {
        let entry = ClipboardEntry(content: "", entryType: .image, imageData: Data())
        XCTAssertEqual(entry.formatCategory, .other)
    }

    func testFileURLEntryIsOther() {
        let entry = ClipboardEntry(content: "file.txt", entryType: .fileURL, fileURL: URL(fileURLWithPath: "/tmp/file.txt"))
        XCTAssertEqual(entry.formatCategory, .other)
    }

    // MARK: - hasRichData

    func testHasRichDataWithRTF() {
        let entry = ClipboardEntry(
            content: "Hello",
            pasteboardData: [.rtf: Data(), .string: Data()]
        )
        XCTAssertTrue(entry.hasRichData)
    }

    func testHasRichDataWithHTML() {
        let entry = ClipboardEntry(
            content: "Hello",
            pasteboardData: [.html: Data(), .string: Data()]
        )
        XCTAssertTrue(entry.hasRichData)
    }

    func testNoRichDataWithOnlyString() {
        let entry = ClipboardEntry(
            content: "Hello",
            pasteboardData: [.string: Data()]
        )
        XCTAssertFalse(entry.hasRichData)
    }

    func testNoRichDataWhenNil() {
        let entry = ClipboardEntry(content: "Hello")
        XCTAssertFalse(entry.hasRichData)
    }

    // MARK: - Markdown to HTML conversion

    func testHeadingConversion() {
        XCTAssertEqual(ClipboardManager.markdownToHTML("# Hello"), "<h1>Hello</h1>")
        XCTAssertEqual(ClipboardManager.markdownToHTML("## World"), "<h2>World</h2>")
        XCTAssertEqual(ClipboardManager.markdownToHTML("### Third"), "<h3>Third</h3>")
    }

    func testBoldConversion() {
        let html = ClipboardManager.markdownToHTML("This is **bold** text")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }

    func testItalicConversion() {
        let html = ClipboardManager.markdownToHTML("This is *italic* text")
        XCTAssertTrue(html.contains("<em>italic</em>"))
    }

    func testInlineCodeConversion() {
        let html = ClipboardManager.markdownToHTML("Use `code` here")
        XCTAssertTrue(html.contains("<code>code</code>"))
    }

    func testLinkConversion() {
        let html = ClipboardManager.markdownToHTML("[Google](https://google.com)")
        XCTAssertTrue(html.contains("<a href=\"https://google.com\">Google</a>"))
    }

    func testUnorderedListConversion() {
        let md = """
        - item 1
        - item 2
        - item 3
        """
        let html = ClipboardManager.markdownToHTML(md)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<li>item 1</li>"))
        XCTAssertTrue(html.contains("<li>item 2</li>"))
        XCTAssertTrue(html.contains("</ul>"))
    }

    func testOrderedListConversion() {
        let md = """
        1. First
        2. Second
        3. Third
        """
        let html = ClipboardManager.markdownToHTML(md)
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("<li>First</li>"))
        XCTAssertTrue(html.contains("</ol>"))
    }

    func testCodeBlockConversion() {
        let md = """
        ```
        let x = 1
        ```
        """
        let html = ClipboardManager.markdownToHTML(md)
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("let x = 1"))
        XCTAssertTrue(html.contains("</code></pre>"))
    }

    func testBlockquoteConversion() {
        let html = ClipboardManager.markdownToHTML("> This is quoted")
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("This is quoted"))
    }

    func testHorizontalRuleConversion() {
        XCTAssertEqual(ClipboardManager.markdownToHTML("---"), "<hr>")
        XCTAssertEqual(ClipboardManager.markdownToHTML("***"), "<hr>")
    }

    func testHTMLEscaping() {
        let html = ClipboardManager.markdownToHTML("Use <div> & \"quotes\"")
        XCTAssertTrue(html.contains("&lt;div&gt;"))
        XCTAssertTrue(html.contains("&amp;"))
    }

    func testParagraphWrapping() {
        let html = ClipboardManager.markdownToHTML("Just a paragraph")
        XCTAssertEqual(html, "<p>Just a paragraph</p>")
    }

    func testComplexDocument() {
        let md = """
        # Title

        This is a paragraph with **bold** and *italic* text.

        ## List

        - Item 1
        - Item 2
        - Item 3

        ```
        code block
        ```

        > A quote

        [link](https://example.com)
        """
        let html = ClipboardManager.markdownToHTML(md)
        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<h2>List</h2>"))
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("<blockquote>"))
        XCTAssertTrue(html.contains("<a href="))
    }

    // MARK: - Rendered markdown paste

    func testSelectEntryAsRenderedMarkdown() {
        let mockPasteboard = MockPasteboard()
        let manager = ClipboardManager(pasteboard: mockPasteboard)

        let md = "# Hello\n\nThis is **bold**."
        let entry = ClipboardEntry(content: md)
        manager.selectEntryAsRenderedMarkdown(entry)

        // Should have plain text
        XCTAssertEqual(mockPasteboard.string(forType: .string), md)
        // Should have HTML
        let htmlData = mockPasteboard.data(forType: .html)
        XCTAssertNotNil(htmlData)
        if let data = htmlData, let html = String(data: data, encoding: .utf8) {
            XCTAssertTrue(html.contains("<h1>Hello</h1>"))
            XCTAssertTrue(html.contains("<strong>bold</strong>"))
        }
    }

    // MARK: - Edge cases

    func testEmptyStringIsNotMarkdown() {
        let entry = ClipboardEntry(content: "")
        XCTAssertFalse(entry.isMarkdownContent)
        XCTAssertEqual(entry.formatCategory, .other)
    }

    func testSingleHashNotMarkdown() {
        // "#hashtag" without space is not a heading
        XCTAssertEqual(ClipboardEntry.markdownScore("#hashtag"), 0)
    }

    func testBoldItalicCombination() {
        let html = ClipboardManager.markdownToHTML("This is ***bold italic*** text")
        XCTAssertTrue(html.contains("<strong><em>bold italic</em></strong>"))
    }

    func testUnclosedCodeBlock() {
        let md = """
        ```
        some code
        without closing fence
        """
        let html = ClipboardManager.markdownToHTML(md)
        // Should still produce output, treating remaining lines as code
        XCTAssertTrue(html.contains("<pre><code>"))
        XCTAssertTrue(html.contains("some code"))
    }

    func testMixedListTypes() {
        let md = """
        - unordered
        - items

        1. ordered
        2. items
        """
        let html = ClipboardManager.markdownToHTML(md)
        XCTAssertTrue(html.contains("<ul>"))
        XCTAssertTrue(html.contains("</ul>"))
        XCTAssertTrue(html.contains("<ol>"))
        XCTAssertTrue(html.contains("</ol>"))
    }

    func testUnderscoreBoldConversion() {
        let html = ClipboardManager.markdownToHTML("This is __bold__ text")
        XCTAssertTrue(html.contains("<strong>bold</strong>"))
    }
}
