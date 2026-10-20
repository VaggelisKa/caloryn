import Foundation
import Testing
@testable import Caloryn

@MainActor
struct FoodSearchListingTests {
    private static let loggingMode = FoodSearchListing.Mode(
        includesRecipes: true,
        supportsMultiSelection: true
    )

    private static let ingredientMode = FoodSearchListing.Mode(
        includesRecipes: false,
        supportsMultiSelection: false
    )

    private func listing(
        mode: FoodSearchListing.Mode = FoodSearchListingTests.loggingMode,
        searchText: String = "",
        recentFoods: [FoodItem] = [],
        mealTemplates: [MealTemplate] = [],
        providerResults: [FoodSearchResult] = [],
        suggestions: [ContextualFoodSuggestion] = []
    ) -> FoodSearchListing {
        FoodSearchListing(
            mode: mode,
            searchText: searchText,
            recentFoods: recentFoods,
            mealTemplates: mealTemplates,
            providerResults: providerResults,
            suggestions: suggestions
        )
    }

    private func manualEntry(name: String, brand: String? = nil) -> FoodItem {
        makeTestFoodItem(name: name, brand: brand, isCustom: true)
    }

    private func recipe(name: String) -> FoodItem {
        makeTestFoodItem(name: name, isCustom: true, isRecipe: true)
    }

    private func editedProduct(name: String, barcode: String) -> FoodItem {
        let food = makeTestFoodItem(name: name, isCustom: true)
        food.providerProductIdentityRaw = barcode
        return food
    }

    private func mealTemplate(named name: String) -> MealTemplate {
        MealTemplate(
            name: name,
            defaultMeal: .lunch,
            defaultSnackIndex: 0,
            creationOperationID: UUID(),
            creationFingerprint: "listing-test"
        )
    }

    private func suggestion(for food: FoodItem) -> ContextualFoodSuggestion {
        ContextualFoodSuggestion(
            foodID: food.id,
            resolvedPortionGrams: 100,
            score: ContextualFoodSuggestion.Score(
                meal: 20, time: 20, weekday: 10, recency: 10, frequency: 10
            ),
            lastLogDate: makeTestDate(year: 2026, month: 1, day: 1),
            reasons: [.recentlyUsed]
        )
    }

    private func providerResult(barcode: String, name: String) throws -> FoodSearchResult {
        let product = try JSONDecoder().decode(
            OpenFoodFactsProduct.self,
            from: Data(
                """
                {
                  "code": "\(barcode)",
                  "product_name": "\(name)",
                  "nutriments": { "energy-kcal_100g": 100 }
                }
                """.utf8
            )
        )
        return makeTestSearchResult(product: product)
    }

    @Test("An empty field rests on recents rather than searching")
    func emptyQueryShowsRecents() {
        #expect(listing(searchText: "").showingRecent)
    }

    @Test("Whitespace alone is still resting, not a search for a space")
    func whitespaceOnlyQueryShowsRecents() {
        #expect(listing(searchText: "   ").showingRecent)
        #expect(listing(searchText: " \t ").showingRecent)
    }

    @Test("Any non-blank character leaves the resting state")
    func nonBlankQueryLeavesRestingState() {
        #expect(!listing(searchText: "a").showingRecent)
        #expect(!listing(searchText: "  a  ").showingRecent)
    }

    @Test("The query is trimmed and case-folded once")
    func queryIsNormalized() {
        #expect(listing(searchText: "  ChIcKeN  ").query == "chicken")
    }

    @Test("Recents exclude the user's own foods, which have their own sections")
    func recentsExcludeUserCreatedFoods() {
        let catalog = makeTestFoodItem(name: "Provider Yoghurt")
        let listing = listing(
            recentFoods: [catalog, manualEntry(name: "My Shake"), recipe(name: "Chili")]
        )

        #expect(listing.displayedRecentFoods.map(\.name) == ["Provider Yoghurt"])
    }

    @Test("An edited catalog product stays in recents despite being user-created")
    func recentsKeepEditedCatalogProducts() {
        let edited = editedProduct(name: "Fixed Skyr", barcode: "5711953150388")

        #expect(listing(recentFoods: [edited]).displayedRecentFoods.map(\.name) == ["Fixed Skyr"])
    }

    @Test("A food already offered as a suggestion is not repeated in recents")
    func recentsDropFoodsAlreadySuggested() {
        let suggested = makeTestFoodItem(name: "Oats")
        let other = makeTestFoodItem(name: "Milk")
        let listing = listing(
            recentFoods: [suggested, other],
            suggestions: [suggestion(for: suggested)]
        )

        #expect(listing.displayedRecentFoods.map(\.name) == ["Milk"])
    }

    @Test("Recents are capped, and the cap keeps the head of the list")
    func recentsAreCapped() {
        let foods = (1...25).map { makeTestFoodItem(name: "Food \($0)") }
        let displayed = listing(recentFoods: foods).displayedRecentFoods

        #expect(displayed.count == FoodSearchListing.recentFoodLimit)
        #expect(displayed.first?.name == "Food 1")
        #expect(displayed.last?.name == "Food 20")
    }

    @Test("Foods the recents section hides do not use up its cap")
    func hiddenFoodsDoNotUseUpTheRecentsCap() {
        let suggested = makeTestFoodItem(name: "Oats")
        let head = [
            manualEntry(name: "My Shake"),
            manualEntry(name: "My Bar"),
            recipe(name: "Chili"),
            suggested
        ]
        let catalog = (1...25).map { makeTestFoodItem(name: "Food \($0)") }
        let displayed = listing(
            recentFoods: head + catalog,
            suggestions: [suggestion(for: suggested)]
        ).displayedRecentFoods

        #expect(displayed.map(\.name) == catalog.prefix(FoodSearchListing.recentFoodLimit).map(\.name))
    }

    @Test("The recents cap does not cut short the other sections")
    func recentsCapLeavesOtherSectionsWhole() {
        let catalog = (1...25).map { makeTestFoodItem(name: "Food \($0)") }
        let tail = [
            manualEntry(name: "Late Shake"),
            recipe(name: "Late Stew"),
            editedProduct(name: "Late Skyr", barcode: "5711953150388")
        ]
        let mode = FoodSearchListing.Mode(includesRecipes: true, supportsMultiSelection: false)
        let resting = listing(mode: mode, recentFoods: catalog + tail)
        let searching = listing(mode: mode, searchText: "late", recentFoods: catalog + tail)

        #expect(resting.manualEntries.map(\.name) == ["Late Shake"])
        #expect(resting.recipes.map(\.name) == ["Late Stew"])
        #expect(resting.editedProducts.map(\.name) == ["Late Skyr"])
        #expect(searching.matchingManualEntries.map(\.name) == ["Late Shake"])
        #expect(searching.matchingRecipes.map(\.name) == ["Late Stew"])
        #expect(searching.matchingEditedProducts.map(\.name) == ["Late Skyr"])
    }

    @Test("Suggestions resolve to the food they point at, in suggestion order")
    func suggestionsPairWithTheirFood() {
        let first = makeTestFoodItem(name: "Eggs")
        let second = makeTestFoodItem(name: "Toast")
        let listing = listing(
            recentFoods: [second, first],
            suggestions: [suggestion(for: first), suggestion(for: second)]
        )

        #expect(listing.contextualSuggestions.map(\.0.name) == ["Eggs", "Toast"])
    }

    @Test("A suggested food of the user's own still keeps its own section")
    func suggestedManualEntryStaysInItsSection() {
        let shake = manualEntry(name: "My Shake")
        let listing = listing(recentFoods: [shake], suggestions: [suggestion(for: shake)])

        #expect(listing.contextualSuggestions.map(\.0.name) == ["My Shake"])
        #expect(listing.manualEntries.map(\.name) == ["My Shake"])
    }

    @Test("Two foods sharing an id resolve a suggestion to the later one in the list")
    func duplicateIDsResolveToTheLaterFood() {
        let earlier = makeTestFoodItem(name: "Oats")
        let later = makeTestFoodItem(name: "Porridge Oats")
        later.id = earlier.id
        let listing = listing(
            recentFoods: [earlier, later],
            suggestions: [suggestion(for: earlier)]
        )

        #expect(listing.contextualSuggestions.map(\.0.name) == ["Porridge Oats"])
        #expect(listing.displayedRecentFoods.isEmpty)
    }

    @Test("A suggestion whose food has left the library is dropped, not crashed on")
    func suggestionsForMissingFoodsAreDropped() {
        let deleted = makeTestFoodItem(name: "Deleted")
        let listing = listing(recentFoods: [], suggestions: [suggestion(for: deleted)])

        #expect(listing.contextualSuggestions.isEmpty)
    }

    @Test("Modes without multi-selection show no suggestions at all")
    func suggestionsRequireMultiSelection() {
        let food = makeTestFoodItem(name: "Eggs")
        let listing = listing(
            mode: Self.ingredientMode,
            recentFoods: [food],
            suggestions: [suggestion(for: food)]
        )

        #expect(listing.contextualSuggestions.isEmpty)
    }

    @Test("Recipes are hidden entirely from modes that cannot use them")
    func recipesAreHiddenFromIngredientSelection() {
        #expect(listing(mode: Self.ingredientMode, recentFoods: [recipe(name: "Chili")])
            .recipes.isEmpty)
        #expect(listing(mode: Self.ingredientMode, searchText: "chili",
                        recentFoods: [recipe(name: "Chili")]).matchingRecipes.isEmpty)
    }

    @Test("Recipe search matches names case-insensitively on a substring")
    func recipeSearchMatchesSubstrings() {
        let foods = [recipe(name: "Turkey Chili"), recipe(name: "Pasta Bake")]

        #expect(listing(searchText: "CHIL", recentFoods: foods).matchingRecipes.map(\.name)
            == ["Turkey Chili"])
    }

    @Test("An empty query matches no recipes, rather than all of them")
    func emptyQueryMatchesNoRecipes() {
        #expect(listing(searchText: "  ", recentFoods: [recipe(name: "Chili")])
            .matchingRecipes.isEmpty)
    }

    @Test("Manual entry search matches the brand as well as the name")
    func manualEntrySearchMatchesBrand() {
        let foods = [
            manualEntry(name: "Protein Bar", brand: "Grenade"),
            manualEntry(name: "Rice Cakes", brand: "Kallo")
        ]

        #expect(listing(searchText: "grenade", recentFoods: foods)
            .matchingManualEntries.map(\.name) == ["Protein Bar"])
    }

    @Test("A missing brand is not a match for anything")
    func missingBrandNeverMatches() {
        let food = manualEntry(name: "Shake", brand: nil)

        #expect(listing(searchText: "grenade", recentFoods: [food]).matchingManualEntries.isEmpty)
    }

    @Test("Recipes are not manual entries, so they never appear twice")
    func recipesAreNotManualEntries() {
        let listing = listing(searchText: "chili", recentFoods: [recipe(name: "Chili")])

        #expect(listing.matchingManualEntries.isEmpty)
        #expect(listing.matchingRecipes.count == 1)
    }

    @Test("An edited catalog product is not a manual entry either")
    func editedProductsAreNotManualEntries() {
        let edited = editedProduct(name: "Fixed Skyr", barcode: "5711953150388")

        #expect(listing(searchText: "skyr", recentFoods: [edited]).matchingManualEntries.isEmpty)
    }

    @Test("Meal search matches names case-insensitively")
    func mealSearchMatchesNames() {
        let meals = [mealTemplate(named: "Sunday Roast"), mealTemplate(named: "Breakfast")]

        #expect(listing(searchText: "roast", mealTemplates: meals).matchingMeals.map(\.name)
            == ["Sunday Roast"])
    }

    @Test("Modes without multi-selection cannot add meals, so none are offered")
    func mealsRequireMultiSelection() {
        let meals = [mealTemplate(named: "Sunday Roast")]

        #expect(listing(mode: Self.ingredientMode, searchText: "roast", mealTemplates: meals)
            .matchingMeals.isEmpty)
    }

    @Test("An edited product hides the provider row it was made from")
    func editedProductsOverlayTheirProviderResult() throws {
        let barcode = "5711953150388"
        let edited = editedProduct(name: "My Skyr", barcode: barcode)
        let results = [
            try providerResult(barcode: barcode, name: "Skyr"),
            try providerResult(barcode: "3017620422003", name: "Nutella")
        ]
        let listing = listing(searchText: "skyr", recentFoods: [edited], providerResults: results)

        #expect(listing.matchingEditedProducts.map(\.name) == ["My Skyr"])
        #expect(listing.visibleProviderSearchResults.map(\.product.id) == ["3017620422003"])
    }

    @Test("A provider hit surfaces the user's edited copy even under a renamed food")
    func editedProductsSurfaceForRenamedFoods() throws {
        let barcode = "5711953150388"
        let renamed = editedProduct(name: "Breakfast Pot", barcode: barcode)
        let listing = listing(
            searchText: "skyr",
            recentFoods: [renamed],
            providerResults: [try providerResult(barcode: barcode, name: "Skyr")]
        )

        #expect(listing.matchingEditedProducts.map(\.name) == ["Breakfast Pot"])
        #expect(listing.visibleProviderSearchResults.isEmpty)
    }

    @Test("A query with nothing behind it reports no matches of any kind")
    func nothingMatchesAnEmptyLibrary() {
        let listing = listing(searchText: "chicken")

        #expect(!listing.hasLocalMatches)
        #expect(!listing.hasCategorizedLocalMatches)
        #expect(!listing.hasProductSearchResults)
    }

    @Test("An edited product counts as a local match but not a categorized one")
    func editedProductsAreUncategorizedLocalMatches() throws {
        let edited = editedProduct(name: "Fixed Skyr", barcode: "5711953150388")
        let listing = listing(searchText: "skyr", recentFoods: [edited])

        #expect(listing.hasLocalMatches)
        #expect(!listing.hasCategorizedLocalMatches)
        #expect(listing.hasProductSearchResults)
    }

    @Test("A manual entry match is categorized, and is not a product result")
    func manualEntriesAreCategorizedMatches() {
        let listing = listing(searchText: "shake", recentFoods: [manualEntry(name: "Shake")])

        #expect(listing.hasCategorizedLocalMatches)
        #expect(listing.hasLocalMatches)
        #expect(!listing.hasProductSearchResults)
    }

    @Test("At rest the count spans suggestions, meals and recents")
    func restingCountSpansEverySection() {
        let suggested = makeTestFoodItem(name: "Oats")
        let listing = listing(
            recentFoods: [suggested, makeTestFoodItem(name: "Milk")],
            mealTemplates: [mealTemplate(named: "Sunday Roast")],
            suggestions: [suggestion(for: suggested)]
        )

        #expect(listing.selectableOptionCount() == 3)
    }

    @Test("Searching counts every result section")
    func searchingCountsEveryResultSection() throws {
        let barcode = "5711953150388"
        let listing = listing(
            searchText: "s",
            recentFoods: [
                manualEntry(name: "Shake"),
                recipe(name: "Stew"),
                editedProduct(name: "Skyr", barcode: barcode)
            ],
            mealTemplates: [mealTemplate(named: "Sunday Roast")],
            providerResults: [try providerResult(barcode: "3017620422003", name: "Nutella")]
        )

        #expect(listing.selectableOptionCount() == 5)
    }

    @Test("A barcode lookup in flight makes nothing selectable underneath it")
    func barcodeLookupSuppressesSelection() {
        let listing = listing(recentFoods: [makeTestFoodItem(name: "Milk")])

        #expect(listing.selectableOptionCount() == 1)
        #expect(listing.selectableOptionCount(isLookingUpBarcode: true) == 0)
        #expect(listing.selectableOptionCount(hasBarcodeLookupError: true) == 0)
    }

    @Test("Mode carries the two facts filtering asks for, taken from FoodSearchMode")
    func modeIsDerivedFromFoodSearchMode() {
        #expect(FoodSearchListing.Mode(.logging) == Self.loggingMode)
        #expect(
            FoodSearchListing.Mode(.ingredientSelection { _ in }) == Self.ingredientMode
        )
        #expect(
            FoodSearchListing.Mode(.mealComponentSelection { _ in })
                == FoodSearchListing.Mode(includesRecipes: true, supportsMultiSelection: false)
        )
    }
}
