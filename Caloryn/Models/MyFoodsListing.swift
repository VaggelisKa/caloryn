import Foundation

@MainActor
struct MyFoodsListing {
    var foodItems: [FoodItem]
    var mealTemplateCount: Int
    var showsAllFavorites: Bool

    init(
        foodItems: [FoodItem],
        mealTemplateCount: Int = 0,
        showsAllFavorites: Bool = false
    ) {
        self.foodItems = foodItems
        self.mealTemplateCount = mealTemplateCount
        self.showsAllFavorites = showsAllFavorites
    }

    var manualEntries: [FoodItem] {
        foodItems.filter(\.isManualEntry)
    }

    var editedProducts: [FoodItem] {
        foodItems.filter(\.isEditedCatalogProduct)
    }

    var recipes: [FoodItem] {
        foodItems.filter(\.isRecipe)
    }

    var favorites: [FoodItem] {
        FavoriteFoodLogging.sortedFavorites(from: foodItems)
    }

    var visibleFavorites: [FoodItem] {
        FavoriteFoodLogging.visibleFavorites(
            from: foodItems,
            showsAll: showsAllFavorites
        )
    }

    var nonFavoriteManualEntries: [FoodItem] {
        manualEntries.filter { !$0.isFavorite }
    }

    var nonFavoriteRecipes: [FoodItem] {
        recipes.filter { !$0.isFavorite }
    }

    var showsFavoritesSection: Bool {
        !favorites.isEmpty
    }

    var showsRecipesSection: Bool {
        !nonFavoriteRecipes.isEmpty
    }

    var showsMealsSection: Bool {
        mealTemplateCount > 0
    }

    var showsManualEntriesSection: Bool {
        !nonFavoriteManualEntries.isEmpty
    }

    var showsEditedProductCatalogSection: Bool {
        !editedProducts.isEmpty
    }

    var isEmptyLibrary: Bool {
        manualEntries.isEmpty
            && recipes.isEmpty
            && editedProducts.isEmpty
            && mealTemplateCount == 0
    }

    var showsFavoritesDisclosure: Bool {
        favorites.count > FavoriteFoodLogging.collapsedFavoriteLimit
    }
}
