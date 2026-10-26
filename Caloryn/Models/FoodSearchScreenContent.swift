import Foundation

enum FoodSearchScreenContent: Equatable, CaseIterable {
    case barcodeLookupFailure

    case barcodeLookupProgress

    case recent

    case searchProgress

    case searchFailure

    case noResults

    case results

    static func resolve(
        isLookingUpBarcode: Bool,
        hasBarcodeLookupError: Bool,
        showingRecent: Bool,
        isSearching: Bool,
        hasSearchFailure: Bool,
        hasLocalMatches: Bool,
        hasProductSearchResults: Bool
    ) -> FoodSearchScreenContent {
        if hasBarcodeLookupError { return .barcodeLookupFailure }
        if isLookingUpBarcode { return .barcodeLookupProgress }
        if showingRecent { return .recent }
        if isSearching, !hasLocalMatches { return .searchProgress }
        if hasSearchFailure, !hasLocalMatches { return .searchFailure }
        if !hasProductSearchResults, !hasLocalMatches { return .noResults }
        return .results
    }

    var coversSearchField: Bool {
        switch self {
        case .barcodeLookupFailure, .barcodeLookupProgress: true
        case .recent, .searchProgress, .searchFailure, .noResults, .results: false
        }
    }

    static func dismissesBarcodeFailure(
        forSearchText searchText: String,
        errorDismissesOnNameSearch: Bool
    ) -> Bool {
        guard errorDismissesOnNameSearch else { return false }
        return !searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
