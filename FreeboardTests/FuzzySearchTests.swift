import XCTest

class FuzzySearchTests: XCTestCase {

    // MARK: - Score function

    func testEmptyQueryMatchesEverything() {
        let result = FuzzySearch.score(query: "", in: "hello world")
        XCTAssertEqual(result, 0)
    }

    func testExactMatchScoresHigh() {
        let exact = FuzzySearch.score(query: "hello", in: "hello")
        let spread = FuzzySearch.score(query: "hello", in: "hXeXlXlXo")
        XCTAssertNotNil(exact)
        XCTAssertNotNil(spread)
        XCTAssertGreaterThan(exact!, spread!)
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(FuzzySearch.score(query: "xyz", in: "hello"))
        XCTAssertNil(FuzzySearch.score(query: "abc", in: "def"))
    }

    func testCaseInsensitive() {
        let lower = FuzzySearch.score(query: "hello", in: "HELLO WORLD")
        XCTAssertNotNil(lower)
    }

    func testCharacterOrderMatters() {
        XCTAssertNotNil(FuzzySearch.score(query: "abc", in: "aXbXc"))
        XCTAssertNil(FuzzySearch.score(query: "abc", in: "cba"))
    }

    func testConsecutiveMatchesScoreHigher() {
        let consecutive = FuzzySearch.score(query: "hel", in: "hello")!
        let spread = FuzzySearch.score(query: "hel", in: "hXeXl")!
        XCTAssertGreaterThan(consecutive, spread)
    }

    func testStartOfStringBonus() {
        let atStart = FuzzySearch.score(query: "h", in: "hello")!
        let notStart = FuzzySearch.score(query: "h", in: "xhello")!
        XCTAssertGreaterThan(atStart, notStart)
    }

    // MARK: - Filter function

    func testFilterReturnsAllWhenQueryEmpty() {
        let entries = [
            ClipboardEntry(content: "hello"),
            ClipboardEntry(content: "world"),
        ]
        let result = FuzzySearch.filter(entries: entries, query: "")
        XCTAssertEqual(result.count, 2)
    }

    func testFilterRemovesNonMatches() {
        let entries = [
            ClipboardEntry(content: "hello world"),
            ClipboardEntry(content: "foo bar"),
            ClipboardEntry(content: "help me"),
        ]
        let result = FuzzySearch.filter(entries: entries, query: "hel")
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.content.lowercased().contains("hel") })
    }

    func testFilterSortsByScore() {
        let entries = [
            ClipboardEntry(content: "xhello"),
            ClipboardEntry(content: "hello"),
        ]
        let result = FuzzySearch.filter(entries: entries, query: "hello")
        XCTAssertEqual(result.first?.content, "hello")
    }

    func testFilterSkipsPasswordEntries() {
        let entries = [
            ClipboardEntry(content: "hello world"),
            ClipboardEntry(content: "secret!pass", isPassword: true),
        ]
        let result = FuzzySearch.filter(entries: entries, query: "sec")
        XCTAssertEqual(result.count, 0)
    }
}
