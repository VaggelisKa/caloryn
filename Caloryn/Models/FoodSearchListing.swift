import Foundation

/// Decides what the food search screen shows for a given query.
///
/// `FoodSearchView` owns a search field, three `@Query` collections, a provider
/// service and a suggestion snapshot, and derived roughly a dozen filtered
/// lists from them inline. Those rules are the part that can be wrong, so they
/// live here where a test can reach them without a view.
struct FoodSearchListing {
    /// The facts about the presentation mode that filtering depends on.
    ///
    /// `FoodSearchMode` carries selection callbacks and screen titles that mean
    /// nothing to these rules, so this takes the two answers they actually ask
    /// for rather than the mode itself.
    struct Mode: Equatable {
        var includesRecipes: Bool
        var supportsMultiSelection: Bool

        init(includesRecipes: Bool, supportsMultiSelection: Bool) {
            self.includesRecipes = includesRecipes
            self.supportsMultiSelection = supportsMultiSelection
        }

        init(_ mode: FoodSearchMode) {
            self.init(
                includesRecipes: mode.includesRecipes,
                supportsMultiSelection: mode.supportsMultiSelection
            )
        }
    }

    /// How many recent foods the list shows before the user has typed anything.
    static let recentFoodLimit = 20

    var mode: Mode
    var searchText: String
    var recentFoods: [FoodItem]
    var mealTemplates: [MealTemplate]
    var providerResults: [FoodSearchResult]
    var suggestions: [ContextualFoodSuggestion]

    init(
        mode: Mode,
        searchText: String,
        recentFoods: [FoodItem],
        mealTemplates: [MealTemplate] = [],
        providerResults: [FoodSearchResult] = [],
        suggestions: [ContextualFoodSuggestion] = []
    ) {
        self.mode = mode
        self.searchText = searchText
        self.recentFoods = recentFoods
        self.mealTemplates = mealTemplates
        self.providerResults = providerResults
        self.suggestions = suggestions
    }

    // MARK: - Query

    /// The query the local filters match on: trimmed and case-folded once.
    var query: String {
        searchText.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Whether the screen is in its resting state, listing recents rather than
    /// results. Whitespace alone is still resting — it is what a stray space
    /// leaves behind, not a search.
    var showingRecent: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Partitions of the local library

    var recipes: [FoodItem] {
        guard mode.includesRecipes else { return [] }
        return recentFoods.filter(\.isRecipe)
    }

    var manualEntries: [FoodItem] {
        recentFoods.filter(\.isManualEntry)
    }

    var editedProducts: [FoodItem] {
        recentFoods.filter(\.isEditedCatalogProduct)
    }

    // MARK: - Resting state

    /// Recents, minus anything already shown as a suggestion above them and
    /// minus the user's own foods, which have their own sections.
    ///
    /// Edited catalog products are the exception: they are user-created but
    /// stand in for a real product, so they belong with the recents.
    var displayedRecentFoods: [FoodItem] {
        let suggestedIDs = Set(suggestions.map(\.foodID))
        return Array(
            recentFoods
                .filter {
                    (!$0.isUserCreatedFood || $0.isEditedCatalogProduct)
                        && !suggestedIDs.contains($0.id)
                }
                .prefix(Self.recentFoodLimit)
        )
    }

    /// Suggestions paired with the food each one points at, dropping any whose
    /// food is no longer in the library.
    var contextualSuggestions: [(FoodItem, ContextualFoodSuggestion)] {
        guard mode.supportsMultiSelection else { return [] }
        let foodsByID = recentFoods.reduce(into: [UUID: FoodItem]()) { result, food in
            result[food.id] = food
        }
        return suggestions.compactMap { suggestion in
            foodsByID[suggestion.foodID].map { ($0, suggestion) }
        }
    }

    // MARK: - Search results

    var matchingManualEntries: [FoodItem] {
        let query = query
        guard !query.isEmpty else { return [] }
        return manualEntries.filter {
            $0.name.lowercased().contains(query)
                || ($0.brand?.lowercased().contains(query) ?? false)
        }
    }

    var matchingEditedProducts: [FoodItem] {
        EditedProductCatalog.loggingProducts(
            in: editedProducts,
            matching: searchText,
            providerResults: providerResults
        )
    }

    /// Provider hits with the ones the user has already edited removed, so a
    /// product never appears twice under two different names.
    var visibleProviderSearchResults: [FoodSearchResult] {
        EditedProductCatalog.providerResults(
            providerResults,
            excludingProductsOverlaidBy: matchingEditedProducts
        )
    }

    var matchingRecipes: [FoodItem] {
        let query = query
        guard !query.isEmpty else { return [] }
        return recipes.filter { $0.name.lowercased().contains(query) }
    }

    var matchingMeals: [MealTemplate] {
        guard mode.supportsMultiSelection else { return [] }
        let query = query
        guard !query.isEmpty else { return [] }
        return mealTemplates.filter { $0.name.lowercased().contains(query) }
    }

    // MARK: - Emptiness

    var hasCategorizedLocalMatches: Bool {
        !matchingMeals.isEmpty
            || !matchingManualEntries.isEmpty
            || !matchingRecipes.isEmpty
    }

    var hasLocalMatches: Bool {
        hasCategorizedLocalMatches || !matchingEditedProducts.isEmpty
    }

    var hasProductSearchResults: Bool {
        !matchingEditedProducts.isEmpty || !visibleProviderSearchResults.isEmpty
    }

    // MARK: - Multi-selection

    /// How many rows the user could tick right now.
    ///
    /// A barcode lookup that is running or has failed replaces the whole list
    /// with an overlay, so nothing is selectable underneath it however many
    /// rows the query would otherwise produce.
    func selectableOptionCount(
        isLookingUpBarcode: Bool = false,
        hasBarcodeLookupError: Bool = false
    ) -> Int {
        guard !isLookingUpBarcode, !hasBarcodeLookupError else { return 0 }

        if showingRecent {
            return contextualSuggestions.count
                + mealTemplates.count
                + displayedRecentFoods.count
        }

        return matchingMeals.count
            + matchingRecipes.count
            + matchingManualEntries.count
            + matchingEditedProducts.count
            + visibleProviderSearchResults.count
    }
}
