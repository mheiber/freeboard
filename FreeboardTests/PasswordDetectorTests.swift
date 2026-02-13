import XCTest

class PasswordDetectorTests: XCTestCase {

    // MARK: - Basic password detection

    func testShortStringIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("ab!"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("a!c"))
        XCTAssertFalse(PasswordDetector.isPasswordLike(""))
    }

    func testStringWithSpacesIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("hello world!"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("my password123!"))
    }

    func testStringWithoutLowercaseIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("HELLO!WORLD"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("12345!@#$%"))
    }

    func testStringWithoutSpecialCharIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("helloworld"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("password123"))
    }

    func testValidPasswordIsDetected() {
        XCTAssertTrue(PasswordDetector.isPasswordLike("p@ssw0rd"))
        XCTAssertTrue(PasswordDetector.isPasswordLike("my!secret123"))
        XCTAssertTrue(PasswordDetector.isPasswordLike("hunter2!"))
        XCTAssertTrue(PasswordDetector.isPasswordLike("c0mpl3x#pass"))
    }

    func testMinimumLengthPasswordIsDetected() {
        XCTAssertTrue(PasswordDetector.isPasswordLike("ab!cd"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("a!cd"))
    }

    // MARK: - Git/Hg commit hash exclusion

    func testFullCommitHashIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("fa81bf3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a"))
    }

    func testShortCommitHashIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("fa81bf3"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("abc123def"))
        XCTAssertFalse(PasswordDetector.isPasswordLike("deadbeef"))
    }

    func testHexStringIsLikelyCommitHash() {
        XCTAssertTrue(PasswordDetector.isLikelyCommitHash("fa81bf3"))
        XCTAssertTrue(PasswordDetector.isLikelyCommitHash("ABCDEF1234567890"))
        XCTAssertFalse(PasswordDetector.isLikelyCommitHash("not-a-hash!"))
    }

    // MARK: - Bitwarden detection

    func testBitwardenConcealedType() {
        let types = [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]
        XCTAssertTrue(PasswordDetector.isBitwardenContent(pasteboardTypes: types))
    }

    func testNonBitwardenTypes() {
        let types = [NSPasteboard.PasteboardType.string]
        XCTAssertFalse(PasswordDetector.isBitwardenContent(pasteboardTypes: types))
    }

    func testNilTypesIsNotBitwarden() {
        XCTAssertFalse(PasswordDetector.isBitwardenContent(pasteboardTypes: nil))
    }

    // MARK: - Edge cases

    func testWhitespaceOnlyIsNotPassword() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("     "))
        XCTAssertFalse(PasswordDetector.isPasswordLike("\t\t\t"))
    }

    func testNewlinesAreNotPasswords() {
        XCTAssertFalse(PasswordDetector.isPasswordLike("\n\n\n\n\n"))
    }

    func testURLsCanBePasswords() {
        // URLs have special chars but aren't passwords - however our heuristic
        // will flag them. This is acceptable behavior.
        XCTAssertTrue(PasswordDetector.isPasswordLike("https://example.com"))
    }
}
