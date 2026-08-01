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

    /// A section with nothing in it is left out entirely rather than shown
    /// with a placeholder row: the toolbar's create menu already names every
    /// kind of food you can make, so a card that says "No Recipes" only
    /// repeats a control that is permanently on screen, at the cost of a full
    /// row of space between the things the user actually saved.

    /// Favorites is derived rather than created — there is no "new favorite"
    /// action to point at — so at zero it is simply absent.
    var showsFavoritesSection: Bool {
        !favorites.isEmpty
    }

    /// Hidden both when no recipes exist and when every one of them is
    /// already shown under Favorites, which would leave the section blank.
    var showsRecipesSection: Bool {
        !nonFavoriteRecipes.isEmpty
    }

    var showsMealsSection: Bool {
        mealTemplateCount > 0
    }

    /// Hidden both when no manual entries exist and when every one of them is
    /// already shown under Favorites, which would leave the section blank.
    var showsManualEntriesSection: Bool {
        !nonFavoriteManualEntries.isEmpty
    }

    /// The catalog row is a drill-down whose destination would itself be
    /// empty at zero, so it is not offered until there is something to open.
    var showsEditedProductCatalogSection: Bool {
        !editedProducts.isEmpty
    }

    /// Nothing this screen can show exists yet, so the whole list is replaced
    /// by a single empty state. This is the one moment the user has no other
    /// signal about what the tab is for, and the only one where teaching it
    /// is not in the way of real content.
    ///
    /// Deliberately not `foodItems.isEmpty` — the query holds provider
    /// catalog foods that this screen never lists, and those must not keep
    /// the empty state away.
    var isEmptyLibrary: Bool {
        manualEntries.isEmpty
            && recipes.isEmpty
            && editedProducts.isEmpty
            && mealTemplateCount == 0
    }

    /// Whether there are more favorites than the collapsed view shows, so the
    /// "Show all" / "Show less" disclosure control is worth offering.
    var showsFavoritesDisclosure: Bool {
        favorites.count > FavoriteFoodLogging.collapsedFavoriteLimit
    }
}
