import Foundation

@MainActor
struct MyFoodsListing {
    let mealTemplateCount: Int
    let showsAllFavorites: Bool

    let manualEntries: [FoodItem]
    let editedProducts: [FoodItem]
    let recipes: [FoodItem]
    let favorites: [FoodItem]
    let visibleFavorites: [FoodItem]
    let nonFavoriteManualEntries: [FoodItem]
    let nonFavoriteRecipes: [FoodItem]

    init(
        foodItems: [FoodItem],
        mealTemplateCount: Int = 0,
        showsAllFavorites: Bool = false
    ) {
        self.mealTemplateCount = mealTemplateCount
        self.showsAllFavorites = showsAllFavorites

        var manualEntries: [FoodItem] = []
        var editedProducts: [FoodItem] = []
        var recipes: [FoodItem] = []
        var nonFavoriteManualEntries: [FoodItem] = []
        var nonFavoriteRecipes: [FoodItem] = []
        for food in foodItems {
            let isFavorite = food.isFavorite
            if food.isManualEntry {
                manualEntries.append(food)
                if !isFavorite {
                    nonFavoriteManualEntries.append(food)
                }
            }
            if food.isEditedCatalogProduct {
                editedProducts.append(food)
            }
            if food.isRecipe {
                recipes.append(food)
                if !isFavorite {
                    nonFavoriteRecipes.append(food)
                }
            }
        }
        self.manualEntries = manualEntries
        self.editedProducts = editedProducts
        self.recipes = recipes
        self.nonFavoriteManualEntries = nonFavoriteManualEntries
        self.nonFavoriteRecipes = nonFavoriteRecipes

        let favorites = FavoriteFoodLogging.sortedFavorites(from: foodItems)
        self.favorites = favorites
        visibleFavorites = showsAllFavorites
            ? favorites
            : Array(favorites.prefix(FavoriteFoodLogging.collapsedFavoriteLimit))
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

    var selectableFoods: [FoodItem] {
        favorites + nonFavoriteRecipes + nonFavoriteManualEntries
    }

    var showsFavoritesDisclosure: Bool {
        favorites.count > FavoriteFoodLogging.collapsedFavoriteLimit
    }
}
