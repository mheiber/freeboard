import Foundation

struct FuzzySearch {
    /// Returns a score for how well the query matches the text.
    /// Returns nil if no match. Higher score = better match.
    static func score(query: String, in text: String) -> Int? {
        guard !query.isEmpty else { return 0 }

        let queryLower = query.lowercased()
        let textLower = text.lowercased()
        let queryChars = Array(queryLower)
        let textChars = Array(textLower)

        var queryIndex = 0
        var score = 0
        var lastMatchIndex = -1

        for (textIndex, char) in textChars.enumerated() {
            guard queryIndex < queryChars.count else { break }

            if char == queryChars[queryIndex] {
                score += 1
                // Bonus for consecutive matches
                if textIndex == lastMatchIndex + 1 {
                    score += 2
                }
                // Bonus for matching at start
                if textIndex == 0 {
                    score += 3
                }
                // Bonus for matching after separator
                if textIndex > 0 {
                    let prev = textChars[textIndex - 1]
                    if prev == " " || prev == "/" || prev == "-" || prev == "_" || prev == "." {
                        score += 2
                    }
                }
                lastMatchIndex = textIndex
                queryIndex += 1
            }
        }

        // All query characters must be matched
        guard queryIndex == queryChars.count else { return nil }

        return score
    }

    /// Filters and sorts entries by fuzzy match score, with favorites first.
    static func filter(entries: [ClipboardEntry], query: String) -> [ClipboardEntry] {
        guard !query.isEmpty else { return entries }

        let scored = entries
            .compactMap { entry -> (ClipboardEntry, Int)? in
                let searchText = entry.isPassword ? "" : entry.content
                guard let s = score(query: query, in: searchText) else { return nil }
                return (entry, s)
            }

        let favorites = scored.filter { $0.0.isFavorite }.sorted { $0.1 > $1.1 }.map { $0.0 }
        let nonFavorites = scored.filter { !$0.0.isFavorite }.sorted { $0.1 > $1.1 }.map { $0.0 }
        return favorites + nonFavorites
    }
}
