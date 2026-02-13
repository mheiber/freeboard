import XCTest
import AppKit

/// End-to-end style tests that verify the full clipboard flow:
/// copy -> detect -> store -> search -> select
class IntegrationTests: XCTestCase {

    var manager: ClipboardManager!
    var mockPasteboard: MockPasteboard!

    override func setUp() {
        super.setUp()
        mockPasteboard = MockPasteboard()
        manager = ClipboardManager(pasteboard: mockPasteboard)
    }

    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        mockPasteboard = nil
        super.tearDown()
    }

    // MARK: - Full flow: copy -> search -> select

    func testFullCopySearchSelectFlow() {
        // User copies several items
        let items = [
            "import Foundation",
            "func hello() { print(\"hi\") }",
            "let x = 42",
            "// TODO: fix this bug",
            "struct User { var name: String }",
        ]
        for item in items {
            mockPasteboard.simulateCopy(item)
            manager.checkForChanges()
        }

        XCTAssertEqual(manager.entries.count, 5)

        // Search for "func"
        let results = FuzzySearch.filter(entries: manager.entries, query: "func")
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].content.contains("func"))

        // Select the found entry
        manager.selectEntry(results[0])
        XCTAssertEqual(mockPasteboard.string(forType: .string), "func hello() { print(\"hi\") }")
    }

    // MARK: - Password flow

    func testPasswordFlowCopyMaskExpire() {
        // User copies a password
        mockPasteboard.simulateCopy("myS3cur3!P@ss")
        manager.checkForChanges()

        // Verify it's detected and masked
        let entry = manager.entries.first!
        XCTAssertTrue(entry.isPassword)
        XCTAssertEqual(entry.displayContent, "********")
        XCTAssertNotNil(entry.expirationDate)

        // Password should not be searchable
        let results = FuzzySearch.filter(entries: manager.entries, query: "secure")
        XCTAssertEqual(results.count, 0)
    }

    func testBitwardenPasswordFlow() {
        // Bitwarden copies a password with concealed type
        let types: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        ]
        mockPasteboard.simulateCopy("simpletext", types: types)
        manager.checkForChanges()

        // Even though "simpletext" doesn't look like a password,
        // it should be treated as one because Bitwarden flagged it
        let entry = manager.entries.first!
        XCTAssertTrue(entry.isPassword)
        XCTAssertEqual(entry.displayContent, "********")
    }

    // MARK: - Mixed content flow

    func testMixedContentWithPasswordsAndText() {
        // Normal text
        mockPasteboard.simulateCopy("Hello World")
        manager.checkForChanges()

        // Password
        mockPasteboard.simulateCopy("p@ss!word")
        manager.checkForChanges()

        // Git hash (not a password)
        mockPasteboard.simulateCopy("fa81bf3c4d5e6f7a")
        manager.checkForChanges()

        // Another normal text
        mockPasteboard.simulateCopy("let result = true")
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 4)

        // Verify password is masked
        let passwordEntry = manager.entries.first { $0.isPassword }!
        XCTAssertEqual(passwordEntry.displayContent, "********")

        // Verify git hash is NOT treated as password
        let hashEntry = manager.entries.first { $0.content.contains("fa81bf3") }!
        XCTAssertFalse(hashEntry.isPassword)

        // Search should find text entries but not passwords
        let searchResults = FuzzySearch.filter(entries: manager.entries, query: "let")
        XCTAssertEqual(searchResults.count, 1)
        XCTAssertEqual(searchResults[0].content, "let result = true")
    }

    // MARK: - Capacity and ordering

    func testHistoryCapacityAndOrdering() {
        // Fill beyond capacity
        for i in 0..<55 {
            mockPasteboard.simulateCopy("Item \(i)")
            manager.checkForChanges()
        }

        // Should be capped at 50
        XCTAssertEqual(manager.entries.count, 50)

        // Most recent should be first
        XCTAssertEqual(manager.entries.first?.content, "Item 54")

        // Oldest kept entry should be Item 5 (items 0-4 were pushed out)
        XCTAssertEqual(manager.entries.last?.content, "Item 5")
    }

    // MARK: - Delete and re-copy flow

    func testDeleteAndRecopyFlow() {
        mockPasteboard.simulateCopy("Important text")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Delete me")
        manager.checkForChanges()

        // Delete the most recent
        let toDelete = manager.entries.first!
        manager.deleteEntry(id: toDelete.id)
        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.content, "Important text")

        // Re-copy the deleted text
        mockPasteboard.simulateCopy("Delete me")
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 2)
        XCTAssertEqual(manager.entries.first?.content, "Delete me")
    }

    // MARK: - Search edge cases

    func testSearchWithNoResults() {
        mockPasteboard.simulateCopy("Hello World")
        manager.checkForChanges()

        let results = FuzzySearch.filter(entries: manager.entries, query: "xyz123")
        XCTAssertEqual(results.count, 0)
    }

    func testSearchRanking() {
        mockPasteboard.simulateCopy("xhello world")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("hello world")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("say hello")
        manager.checkForChanges()

        let results = FuzzySearch.filter(entries: manager.entries, query: "hello")

        // "hello world" should rank first (starts with match)
        XCTAssertEqual(results.first?.content, "hello world")
    }
}
