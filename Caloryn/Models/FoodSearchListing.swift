import Foundation

struct FoodSearchListing {
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

    var query: String {
        searchText.lowercased().trimmingCharacters(in: .whitespaces)
    }

    var showingRecent: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

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

    var contextualSuggestions: [(FoodItem, ContextualFoodSuggestion)] {
        guard mode.supportsMultiSelection else { return [] }
        let foodsByID = recentFoods.reduce(into: [UUID: FoodItem]()) { result, food in
            result[food.id] = food
        }
        return suggestions.compactMap { suggestion in
            foodsByID[suggestion.foodID].map { ($0, suggestion) }
        }
    }

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
