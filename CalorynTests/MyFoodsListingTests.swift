import Foundation
import Testing
@testable import Caloryn

/// Behaviour of the "My Foods" screen's partitioning and section-visibility
/// rules, extracted from `MyFoodsView` so they can be exercised without a
/// view.
@MainActor
struct MyFoodsListingTests {

    // MARK: - Helpers

    private func listing(
        foodItems: [FoodItem],
        showsAllFavorites: Bool = false
    ) -> MyFoodsListing {
        MyFoodsListing(foodItems: foodItems, showsAllFavorites: showsAllFavorites)
    }

    private func manualEntry(name: String, favorite: Bool = false) -> FoodItem {
        let food = makeTestFoodItem(name: name, isCustom: true)
        if favorite {
            food.setFavorite(true)
        }
        return food
    }

    private func recipe(name: String, favorite: Bool = false) -> FoodItem {
        let food = makeTestFoodItem(name: name, isCustom: true, isRecipe: true)
        if favorite {
            food.setFavorite(true)
        }
        return food
    }

    private func editedProduct(name: String, barcode: String) -> FoodItem {
        let food = makeTestFoodItem(name: name, isCustom: true)
        food.providerProductIdentityRaw = barcode
        return food
    }

    // MARK: - Partitions

    @Test("Manual entries, edited products and recipes are three disjoint kinds")
    func partitionsByKind() {
        let manual = manualEntry(name: "Shake")
        let edited = editedProduct(name: "Fixed Skyr", barcode: "5711953150388")
        let aRecipe = recipe(name: "Chili")
        let catalogFood = makeTestFoodItem(name: "Provider Yoghurt")
        let listing = listing(foodItems: [manual, edited, aRecipe, catalogFood])

        #expect(listing.manualEntries.map(\.name) == ["Shake"])
        #expect(listing.editedProducts.map(\.name) == ["Fixed Skyr"])
        #expect(listing.recipes.map(\.name) == ["Chili"])
    }

    @Test("Favorites are only ever manual entries or recipes marked favorite")
    func favoritesAreUserCreatedAndPinned() {
        let favoritedManual = manualEntry(name: "Oats", favorite: true)
        let plainManual = manualEntry(name: "Milk")
        let favoritedRecipe = recipe(name: "Chili", favorite: true)
        let listing = listing(
            foodItems: [favoritedManual, plainManual, favoritedRecipe]
        )

        #expect(Set(listing.favorites.map(\.name)) == ["Oats", "Chili"])
    }

    @Test("Visible favorites respects the showsAllFavorites flag via the collapsed limit")
    func visibleFavoritesHonorsDisclosureState() {
        let favorites = (1...6).map { manualEntry(name: "Favorite \($0)", favorite: true) }

        let collapsed = listing(foodItems: favorites, showsAllFavorites: false)
        let expanded = listing(foodItems: favorites, showsAllFavorites: true)

        #expect(collapsed.visibleFavorites.count == FavoriteFoodLogging.collapsedFavoriteLimit)
        #expect(expanded.visibleFavorites.count == 6)
    }

    @Test("Non-favorite manual entries and recipes exclude anything already shown under Favorites")
    func nonFavoritePartitionsExcludeFavorites() {
        let favoritedManual = manualEntry(name: "Oats", favorite: true)
        let plainManual = manualEntry(name: "Milk")
        let favoritedRecipe = recipe(name: "Chili", favorite: true)
        let plainRecipe = recipe(name: "Soup")
        let listing = listing(
            foodItems: [favoritedManual, plainManual, favoritedRecipe, plainRecipe]
        )

        #expect(listing.nonFavoriteManualEntries.map(\.name) == ["Milk"])
        #expect(listing.nonFavoriteRecipes.map(\.name) == ["Soup"])
    }

    // MARK: - Section visibility

    @Test("An empty library shows the empty-state rows for recipes and manual entries")
    func emptyLibraryShowsEmptyStates() {
        let listing = listing(foodItems: [])

        #expect(listing.showsEmptyRecipesSection)
        #expect(!listing.showsRecipesSection)
        #expect(listing.showsEmptyManualEntriesSection)
        #expect(!listing.showsManualEntriesSection)
    }

    @Test("Recipes that exist but are all favorited hide the dedicated section rather than showing it blank")
    func allFavoritedRecipesHideTheirSection() {
        let listing = listing(foodItems: [recipe(name: "Chili", favorite: true)])

        #expect(!listing.showsEmptyRecipesSection)
        #expect(!listing.showsRecipesSection)
    }

    @Test("Manual entries that exist but are all favorited hide the dedicated section rather than showing it blank")
    func allFavoritedManualEntriesHideTheirSection() {
        let listing = listing(foodItems: [manualEntry(name: "Oats", favorite: true)])

        #expect(!listing.showsEmptyManualEntriesSection)
        #expect(!listing.showsManualEntriesSection)
    }

    @Test("A non-favorited recipe or manual entry shows its dedicated section")
    func nonFavoritedItemsShowTheirSection() {
        let listing = listing(
            foodItems: [recipe(name: "Chili"), manualEntry(name: "Oats")]
        )

        #expect(listing.showsRecipesSection)
        #expect(listing.showsManualEntriesSection)
    }

    // MARK: - Favorites disclosure

    @Test("The disclosure control only appears once favorites exceed the collapsed limit")
    func disclosureAppearsOnlyAboveTheLimit() {
        let atLimit = (1...FavoriteFoodLogging.collapsedFavoriteLimit)
            .map { manualEntry(name: "Favorite \($0)", favorite: true) }
        let overLimit = atLimit + [manualEntry(name: "One More", favorite: true)]

        #expect(!listing(foodItems: atLimit).showsFavoritesDisclosure)
        #expect(listing(foodItems: overLimit).showsFavoritesDisclosure)
    }
}
