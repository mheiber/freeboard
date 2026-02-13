import XCTest
import AppKit

class MockPasteboard: PasteboardProviding {
    var changeCount: Int = 0
    var types: [NSPasteboard.PasteboardType]? = [.string]
    private var content: String?

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        return content
    }

    @discardableResult
    func clearContents() -> Int {
        content = nil
        changeCount += 1
        return changeCount
    }

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        content = string
        changeCount += 1
        return true
    }

    func simulateCopy(_ text: String, types: [NSPasteboard.PasteboardType]? = nil) {
        content = text
        changeCount += 1
        if let types = types {
            self.types = types
        } else {
            self.types = [.string]
        }
    }
}

class ClipboardManagerTests: XCTestCase {

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

    // MARK: - Basic clipboard monitoring

    func testDetectsNewClipboardContent() {
        mockPasteboard.simulateCopy("Hello World")
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.content, "Hello World")
    }

    func testIgnoresUnchangedClipboard() {
        mockPasteboard.simulateCopy("Hello")
        manager.checkForChanges()
        // Check again without changing
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 1)
    }

    func testMultipleCopiesCreateMultipleEntries() {
        mockPasteboard.simulateCopy("First")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Second")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Third")
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 3)
        XCTAssertEqual(manager.entries[0].content, "Third")
        XCTAssertEqual(manager.entries[1].content, "Second")
        XCTAssertEqual(manager.entries[2].content, "First")
    }

    func testNewestEntryIsFirst() {
        mockPasteboard.simulateCopy("Old")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("New")
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.first?.content, "New")
    }

    // MARK: - Duplicate handling

    func testDuplicateMovesToTop() {
        mockPasteboard.simulateCopy("First")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Second")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("First")
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 2)
        XCTAssertEqual(manager.entries[0].content, "First")
        XCTAssertEqual(manager.entries[1].content, "Second")
    }

    // MARK: - Max entries

    func testCapsAtMaxEntries() {
        for i in 0..<60 {
            mockPasteboard.simulateCopy("Entry \(i)")
            manager.checkForChanges()
        }
        XCTAssertEqual(manager.entries.count, ClipboardManager.maxEntries)
    }

    // MARK: - Delete

    func testDeleteEntry() {
        mockPasteboard.simulateCopy("Keep")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Delete me")
        manager.checkForChanges()

        let entryToDelete = manager.entries.first!
        manager.deleteEntry(id: entryToDelete.id)

        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.content, "Keep")
    }

    // MARK: - Password detection

    func testPasswordLikeContentIsFlagged() {
        mockPasteboard.simulateCopy("s3cur3!pass")
        manager.checkForChanges()
        XCTAssertTrue(manager.entries.first?.isPassword ?? false)
    }

    func testNormalContentIsNotFlaggedAsPassword() {
        mockPasteboard.simulateCopy("Hello World")
        manager.checkForChanges()
        XCTAssertFalse(manager.entries.first?.isPassword ?? true)
    }

    func testBitwardenContentIsFlaggedAsPassword() {
        let bitwardenTypes: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        ]
        mockPasteboard.simulateCopy("normaltext", types: bitwardenTypes)
        manager.checkForChanges()
        XCTAssertTrue(manager.entries.first?.isPassword ?? false)
    }

    // MARK: - Password expiry

    func testPasswordEntryHasExpiration() {
        mockPasteboard.simulateCopy("s3cur3!pass")
        manager.checkForChanges()

        let entry = manager.entries.first!
        XCTAssertNotNil(entry.expirationDate)
        XCTAssertFalse(entry.isExpired)
    }

    func testExpiredEntriesAreRemoved() {
        // Add an entry with a past expiration
        let expiredEntry = ClipboardEntry(
            content: "old!password",
            isPassword: true,
            timestamp: Date().addingTimeInterval(-120)
        )
        manager.addEntry(expiredEntry)

        XCTAssertEqual(manager.entries.count, 1)
        manager.removeExpiredEntries()
        XCTAssertEqual(manager.entries.count, 0)
    }

    func testNonExpiredPasswordsAreKept() {
        mockPasteboard.simulateCopy("fresh!password")
        manager.checkForChanges()

        manager.removeExpiredEntries()
        XCTAssertEqual(manager.entries.count, 1)
    }

    // MARK: - Select entry

    func testSelectEntryCopiesToPasteboard() {
        mockPasteboard.simulateCopy("First")
        manager.checkForChanges()
        mockPasteboard.simulateCopy("Second")
        manager.checkForChanges()

        let firstEntry = manager.entries.last!
        manager.selectEntry(firstEntry)

        XCTAssertEqual(mockPasteboard.string(forType: .string), "First")
    }

    // MARK: - Empty/whitespace content

    func testIgnoresEmptyContent() {
        mockPasteboard.simulateCopy("")
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 0)
    }

    func testIgnoresWhitespaceOnlyContent() {
        mockPasteboard.simulateCopy("   \n\t  ")
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 0)
    }

    // MARK: - Delegate

    func testDelegateCalledOnNewEntry() {
        let expectation = XCTestExpectation(description: "Delegate called")
        let delegateSpy = DelegateSpy(expectation: expectation)
        manager.delegate = delegateSpy

        mockPasteboard.simulateCopy("Hello")
        manager.checkForChanges()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(delegateSpy.wasCalled)
    }
}

class DelegateSpy: ClipboardManagerDelegate {
    var wasCalled = false
    let expectation: XCTestExpectation

    init(expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func clipboardManagerDidUpdateEntries(_ manager: ClipboardManager) {
        wasCalled = true
        expectation.fulfill()
    }
}
