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

    let mode: Mode
    let searchText: String
    let recentFoods: [FoodItem]
    let mealTemplates: [MealTemplate]
    let providerResults: [FoodSearchResult]
    let suggestions: [ContextualFoodSuggestion]

    let query: String
    private let isBlank: Bool
    private let meetsSearchMinimum: Bool
    let recipes: [FoodItem]
    let manualEntries: [FoodItem]
    let editedProducts: [FoodItem]
    let displayedRecentFoods: [FoodItem]
    let contextualSuggestions: [(FoodItem, ContextualFoodSuggestion)]
    let matchingManualEntries: [FoodItem]
    let matchingEditedProducts: [FoodItem]
    let visibleProviderSearchResults: [FoodSearchResult]
    let matchingRecipes: [FoodItem]
    let matchingMeals: [MealTemplate]

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

        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        self.query = query
        isBlank = searchText.trimmingCharacters(in: .whitespaces).isEmpty
        meetsSearchMinimum = FoodSearchQuery(searchText).meetsSearchMinimum

        let suggestedIDs = Set(suggestions.map(\.foodID))
        var recipes: [FoodItem] = []
        var manualEntries: [FoodItem] = []
        var editedProducts: [FoodItem] = []
        var displayedRecentFoods: [FoodItem] = []
        var suggestedFoodsByID: [UUID: FoodItem] = [:]
        for food in recentFoods {
            if mode.includesRecipes, food.isRecipe {
                recipes.append(food)
            }
            if food.isManualEntry {
                manualEntries.append(food)
            }
            let isEditedCatalogProduct = food.isEditedCatalogProduct
            if isEditedCatalogProduct {
                editedProducts.append(food)
            }
            let id = food.id
            if suggestedIDs.contains(id) {
                suggestedFoodsByID[id] = food
            } else if displayedRecentFoods.count < Self.recentFoodLimit,
                      !food.isUserCreatedFood || isEditedCatalogProduct {
                displayedRecentFoods.append(food)
            }
        }
        self.recipes = recipes
        self.manualEntries = manualEntries
        self.editedProducts = editedProducts
        self.displayedRecentFoods = displayedRecentFoods

        contextualSuggestions = mode.supportsMultiSelection
            ? suggestions.compactMap { suggestion in
                suggestedFoodsByID[suggestion.foodID].map { ($0, suggestion) }
            }
            : []

        matchingManualEntries = query.isEmpty ? [] : manualEntries.filter {
            $0.name.lowercased().contains(query)
                || ($0.brand?.lowercased().contains(query) ?? false)
        }

        let matchingEditedProducts = EditedProductCatalog.loggingProducts(
            in: editedProducts,
            matching: searchText,
            providerResults: providerResults
        )
        self.matchingEditedProducts = matchingEditedProducts
        visibleProviderSearchResults = EditedProductCatalog.providerResults(
            providerResults,
            excludingProductsOverlaidBy: matchingEditedProducts
        )

        matchingRecipes = query.isEmpty ? [] : recipes.filter {
            $0.name.lowercased().contains(query)
        }

        matchingMeals = mode.supportsMultiSelection && !query.isEmpty
            ? mealTemplates.filter { $0.name.lowercased().contains(query) }
            : []
    }

    var showingRecent: Bool {
        isBlank || (!meetsSearchMinimum && !hasLocalMatches)
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
