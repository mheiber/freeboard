import XCTest

class EmptyStateTests: XCTestCase {

    // MARK: - EmptyStateMode.compute

    func testNoItemsMode() {
        let mode = EmptyStateMode.compute(filteredEntriesEmpty: true, searchQueryEmpty: true)
        XCTAssertEqual(mode, .noItems)
    }

    func testNoSearchResultsMode() {
        let mode = EmptyStateMode.compute(filteredEntriesEmpty: true, searchQueryEmpty: false)
        XCTAssertEqual(mode, .noSearchResults)
    }

    func testHiddenModeWithResults() {
        let mode = EmptyStateMode.compute(filteredEntriesEmpty: false, searchQueryEmpty: true)
        XCTAssertEqual(mode, .hidden)
    }

    func testHiddenModeWithSearchResults() {
        let mode = EmptyStateMode.compute(filteredEntriesEmpty: false, searchQueryEmpty: false)
        XCTAssertEqual(mode, .hidden)
    }

    // MARK: - Localization strings

    func testEnglishStrings() {
        let saved = L.current
        defer { L.current = saved }
        L.current = .en

        XCTAssertEqual(L.noMatchesFound, "No matches found.")
        XCTAssertEqual(L.clearSearch, "Clear Search (Esc)")
    }

    func testChineseStrings() {
        let saved = L.current
        defer { L.current = saved }
        L.current = .zh

        XCTAssertEqual(L.noMatchesFound, "未找到匹配项。")
        XCTAssertEqual(L.clearSearch, "清除搜索 (Esc)")
    }
}
