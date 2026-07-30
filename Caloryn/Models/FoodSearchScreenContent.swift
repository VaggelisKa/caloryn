import Foundation

/// Which one thing the food search screen is showing below its search field.
///
/// The screen has seven mutually exclusive states and the order they are tried
/// in is the whole rule: a barcode overlay outranks anything the query would
/// have produced, and a local match outranks the spinner, the provider's
/// failure *and* "No Results" — so a user who has the food in their own library
/// still sees it when the network is down. That precedence used to be spelled
/// out as two nested `if`/`else if` chains inside `body`, where nothing could
/// check it.
enum FoodSearchScreenContent: Equatable, CaseIterable {
    /// A scanned barcode could not be resolved; the failure view offers retry
    /// and, when the product is simply unknown, manual creation.
    case barcodeLookupFailure

    /// A scanned barcode is being looked up.
    case barcodeLookupProgress

    /// The resting list: suggestions, meals, the user's own foods, recents.
    case recent

    /// A query is in flight and nothing local matches it yet.
    case searchProgress

    /// The provider failed and nothing local matches, so there is nothing to
    /// show but the failure.
    case searchFailure

    /// The query matched nothing, anywhere.
    case noResults

    /// At least one row to show.
    case results

    /// Resolves the state from the facts the screen holds.
    ///
    /// `hasLocalMatches` and `hasProductSearchResults` come from
    /// `FoodSearchListing`, which already derives them; nothing here recomputes
    /// them from the underlying collections.
    static func resolve(
        isLookingUpBarcode: Bool,
        hasBarcodeLookupError: Bool,
        showingRecent: Bool,
        isSearching: Bool,
        hasSearchFailure: Bool,
        hasLocalMatches: Bool,
        hasProductSearchResults: Bool
    ) -> FoodSearchScreenContent {
        // A failed lookup outranks one still running: a retry that fails again
        // must show the failure, not fall back to the spinner it replaced.
        if hasBarcodeLookupError { return .barcodeLookupFailure }
        if isLookingUpBarcode { return .barcodeLookupProgress }
        if showingRecent { return .recent }
        if isSearching, !hasLocalMatches { return .searchProgress }
        if hasSearchFailure, !hasLocalMatches { return .searchFailure }
        if !hasProductSearchResults, !hasLocalMatches { return .noResults }
        return .results
    }

    /// Whether this state covers the search field.
    ///
    /// The barcode overlay takes the whole area below the field, so focusing
    /// the field on appear would raise a keyboard over a screen the user cannot
    /// type into and unsettle the navigation title behind it.
    var coversSearchField: Bool {
        switch self {
        case .barcodeLookupFailure, .barcodeLookupProgress: true
        case .recent, .searchProgress, .searchFailure, .noResults, .results: false
        }
    }

    /// Whether typing dismisses a barcode failure that is currently on screen.
    ///
    /// Starting a name search is the user giving up on the scan, so the overlay
    /// gets out of the way — but only for a real query. Whitespace alone is not
    /// a search, and it is what a stray space or a cleared field leaves behind.
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
