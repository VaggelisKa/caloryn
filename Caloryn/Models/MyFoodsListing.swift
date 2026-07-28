import Foundation

/// Decides how the "My Foods" screen partitions the food library and which
/// sections it shows.
///
/// `MyFoodsView` owns one `@Query` of every stored `FoodItem` and derived
/// several filtered lists and section-visibility decisions from it inline.
/// Those rules are the part that can be wrong, so they live here where a
/// test can reach them without a view. Like `FoodSearchListing`, this works
/// from `FoodItem` arrays rather than a stripped-down value type: the view
/// needs the actual objects back to render rows and open edit sheets, so a
/// value type would only add a round trip through an id-keyed lookup with
/// nothing gained in return — `FoodItem`'s kind flags and `isFavorite` are
/// plain stored/computed properties that need no live model context to read.
@MainActor
struct MyFoodsListing {
    var foodItems: [FoodItem]
    var showsAllFavorites: Bool

    init(foodItems: [FoodItem], showsAllFavorites: Bool = false) {
        self.foodItems = foodItems
        self.showsAllFavorites = showsAllFavorites
    }

    // MARK: - Partitions

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

    /// Manual entries with their own row in the Favorites section removed, so
    /// nothing appears twice.
    var nonFavoriteManualEntries: [FoodItem] {
        manualEntries.filter { !$0.isFavorite }
    }

    /// Recipes with their own row in the Favorites section removed, so
    /// nothing appears twice.
    var nonFavoriteRecipes: [FoodItem] {
        recipes.filter { !$0.isFavorite }
    }

    // MARK: - Section visibility

    /// Whether the library has no recipes at all, in which case the section
    /// shows an empty-state row instead of a list.
    var showsEmptyRecipesSection: Bool {
        recipes.isEmpty
    }

    /// Recipes exist, but every one of them is already shown under
    /// Favorites, so the dedicated section would be empty and is hidden
    /// rather than shown blank.
    var showsRecipesSection: Bool {
        !recipes.isEmpty && !nonFavoriteRecipes.isEmpty
    }

    /// Whether the library has no manual entries at all, in which case the
    /// section shows an empty-state row instead of a list.
    var showsEmptyManualEntriesSection: Bool {
        manualEntries.isEmpty
    }

    /// Manual entries exist, but every one of them is already shown under
    /// Favorites, so the dedicated section would be empty and is hidden
    /// rather than shown blank.
    var showsManualEntriesSection: Bool {
        !manualEntries.isEmpty && !nonFavoriteManualEntries.isEmpty
    }

    /// Whether there are more favorites than the collapsed view shows, so the
    /// "Show all" / "Show less" disclosure control is worth offering.
    var showsFavoritesDisclosure: Bool {
        favorites.count > FavoriteFoodLogging.collapsedFavoriteLimit
    }
}
