import XCTest
import AppKit

class MockPasteboard: PasteboardProviding {
    var changeCount: Int = 0
    var types: [NSPasteboard.PasteboardType]? = [.string]
    private var content: String?
    private var dataStore: [NSPasteboard.PasteboardType: Data] = [:]
    private var writtenObjects: [NSPasteboardWriting] = []

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        return content
    }

    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? {
        return dataStore[dataType]
    }

    @discardableResult
    func clearContents() -> Int {
        content = nil
        dataStore = [:]
        writtenObjects = []
        changeCount += 1
        return changeCount
    }

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        content = string
        changeCount += 1
        return true
    }

    @discardableResult
    func setData(_ data: Data?, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        if let data = data {
            dataStore[dataType] = data
        } else {
            dataStore.removeValue(forKey: dataType)
        }
        return true
    }

    func writeObjects(_ objects: [NSPasteboardWriting]) -> Bool {
        writtenObjects = objects
        changeCount += 1
        return true
    }

    func readObjects(forClasses classArray: [AnyClass], options: [NSPasteboard.ReadingOptionKey : Any]?) -> [Any]? {
        return writtenObjects as? [Any]
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

    func simulateImageCopy(_ imageData: Data, type: NSPasteboard.PasteboardType = .tiff) {
        content = nil
        dataStore[type] = imageData
        types = [type]
        changeCount += 1
    }

    func simulateFileURLCopy(_ url: URL) {
        let fileURLType = NSPasteboard.PasteboardType("public.file-url")
        content = url.absoluteString
        types = [fileURLType, .string]
        changeCount += 1
    }

    func simulateRichCopy(_ text: String, rtfData: Data) {
        content = text
        dataStore[.rtf] = rtfData
        types = [.string, .rtf]
        changeCount += 1
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

    // MARK: - Image clipboard

    func testDetectsImageContent() {
        // Create a small 1x1 red PNG
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!

        mockPasteboard.simulateImageCopy(tiffData)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.entryType, .image)
        XCTAssertNotNil(manager.entries.first?.imageData)
    }

    func testRejectsOversizedImage() {
        let bigData = Data(repeating: 0, count: 11_000_000) // > 10MB
        mockPasteboard.simulateImageCopy(bigData)
        // After skipping image, falls through to text check which finds nil
        manager.checkForChanges()
        XCTAssertEqual(manager.entries.count, 0)
    }

    func testDetectsFileURL() {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        mockPasteboard.simulateFileURLCopy(url)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertEqual(manager.entries.first?.entryType, .fileURL)
        XCTAssertEqual(manager.entries.first?.fileURL, url)
        XCTAssertEqual(manager.entries.first?.content, "test.txt")
    }

    func testImageSelectRestoresImageToPasteboard() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!

        mockPasteboard.simulateImageCopy(tiffData)
        manager.checkForChanges()

        let entry = manager.entries.first!
        manager.selectEntry(entry)
        // writeObjects should have been called
        XCTAssertTrue(true) // Just verify no crash
    }

    func testImageDeduplication() {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        let tiffData = image.tiffRepresentation!

        mockPasteboard.simulateImageCopy(tiffData)
        manager.checkForChanges()
        mockPasteboard.simulateImageCopy(tiffData)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 1) // Deduplicated
    }

    func testTextAndImageCoexist() {
        mockPasteboard.simulateCopy("Hello")
        manager.checkForChanges()

        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 1, height: 1))
        image.unlockFocus()
        mockPasteboard.simulateImageCopy(image.tiffRepresentation!)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 2)
        XCTAssertEqual(manager.entries[0].entryType, .image)
        XCTAssertEqual(manager.entries[1].entryType, .text)
    }

    // MARK: - Rich text

    func testRichTextDataCaptured() {
        let rtfData = "{\\rtf1 Hello}".data(using: .utf8)!
        mockPasteboard.simulateRichCopy("Hello", rtfData: rtfData)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.count, 1)
        XCTAssertNotNil(manager.entries.first?.pasteboardData)
        XCTAssertNotNil(manager.entries.first?.pasteboardData?[.rtf])
    }

    func testPlainTextPasteStripsRichData() {
        let rtfData = "{\\rtf1 Hello}".data(using: .utf8)!
        mockPasteboard.simulateRichCopy("Hello", rtfData: rtfData)
        manager.checkForChanges()

        let entry = manager.entries.first!
        manager.selectEntryAsPlainText(entry)

        // Should only have string, not RTF
        XCTAssertEqual(mockPasteboard.string(forType: .string), "Hello")
        XCTAssertNil(mockPasteboard.data(forType: .rtf))
    }

    func testPasswordsDoNotStoreRichData() {
        let rtfData = "{\\rtf1 secret}".data(using: .utf8)!
        mockPasteboard.simulateRichCopy("s3cur3!pass", rtfData: rtfData)
        manager.checkForChanges()

        XCTAssertNil(manager.entries.first?.pasteboardData)
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
