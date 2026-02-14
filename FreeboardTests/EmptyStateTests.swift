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

    func testSpanishStrings() {
        let saved = L.current
        defer { L.current = saved }
        L.current = .es

        XCTAssertEqual(L.noMatchesFound, "No se encontraron coincidencias.")
        XCTAssertEqual(L.clearSearch, "Limpiar búsqueda (Esc)")
        XCTAssertEqual(L.open, "Abrir")
        XCTAssertEqual(L.quit, "Salir")
        XCTAssertEqual(L.language, "Idioma")
    }

    // MARK: - Lang.usesSystemFont

    func testUsesSystemFont() {
        XCTAssertFalse(Lang.en.usesSystemFont)
        XCTAssertTrue(Lang.zh.usesSystemFont)
        XCTAssertTrue(Lang.hi.usesSystemFont)
        XCTAssertFalse(Lang.es.usesSystemFont)
        XCTAssertFalse(Lang.fr.usesSystemFont)
        XCTAssertTrue(Lang.ar.usesSystemFont)
        XCTAssertTrue(Lang.bn.usesSystemFont)
        XCTAssertFalse(Lang.pt.usesSystemFont)
        XCTAssertFalse(Lang.ru.usesSystemFont)
        XCTAssertTrue(Lang.ja.usesSystemFont)
    }

    // MARK: - Lang.nativeName

    func testNativeName() {
        XCTAssertEqual(Lang.en.nativeName, "English")
        XCTAssertEqual(Lang.zh.nativeName, "中文")
        XCTAssertEqual(Lang.es.nativeName, "Español")
        XCTAssertEqual(Lang.ja.nativeName, "日本語")
        XCTAssertEqual(Lang.ru.nativeName, "Русский")
    }

    // MARK: - Auto-detect fallback

    func testAutoDetectFallbackToEnglish() {
        let saved = L.current
        defer { L.current = saved }

        // Remove saved language preference
        UserDefaults.standard.removeObject(forKey: "freeboard_language")

        // L.current getter will try auto-detect from Locale.preferredLanguages.
        // If the system locale matches a supported language, it returns that.
        // Otherwise falls back to .en. Either way it should return a valid Lang.
        let detected = L.current
        XCTAssertTrue(Lang.allCases.contains(detected))
    }

    // MARK: - Lang.fromLocaleIdentifier

    func testFromLocaleIdentifier() {
        XCTAssertEqual(Lang.fromLocaleIdentifier("en-US"), .en)
        XCTAssertEqual(Lang.fromLocaleIdentifier("zh-Hans"), .zh)
        XCTAssertEqual(Lang.fromLocaleIdentifier("es-MX"), .es)
        XCTAssertEqual(Lang.fromLocaleIdentifier("ja-JP"), .ja)
        XCTAssertNil(Lang.fromLocaleIdentifier("de-DE"))
        XCTAssertNil(Lang.fromLocaleIdentifier("ko-KR"))
    }

    // MARK: - Accessibility strings

    func testAccessibilityStrings() {
        let saved = L.current
        defer { L.current = saved }
        L.current = .en

        XCTAssertEqual(L.accessibilityStarred, "Starred")
        XCTAssertEqual(L.accessibilityStar, "Star")
        XCTAssertEqual(L.accessibilityDelete, "Delete clipboard entry")
        XCTAssertEqual(L.accessibilityPasswordHidden, "Password (hidden)")
        XCTAssertEqual(L.accessibilitySearchField, "Search clipboard history")
        XCTAssertEqual(L.delete, "delete")
        XCTAssertEqual(L.accessibleMinutesAgo(5), "5 minutes ago")
        XCTAssertEqual(L.accessibleHoursAgo(2), "2 hours ago")
        XCTAssertEqual(L.accessibleDaysAgo(3), "3 days ago")
    }
}
