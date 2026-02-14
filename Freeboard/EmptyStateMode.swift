enum EmptyStateMode {
    case noItems         // clipboard history is empty
    case noSearchResults // search active, no matches
    case hidden          // entries are visible

    static func compute(filteredEntriesEmpty: Bool, searchQueryEmpty: Bool) -> EmptyStateMode {
        if !filteredEntriesEmpty { return .hidden }
        if searchQueryEmpty { return .noItems }
        return .noSearchResults
    }
}
