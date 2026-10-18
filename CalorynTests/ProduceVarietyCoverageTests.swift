import Foundation
import Testing
@testable import Caloryn

/// How a day's fruit and veg are counted as kinds: the breakdown and preview wording for every
/// mix, the ordering within a kind, which spellings collapse into one kind, and the legacy
/// fallback through a recipe's live ingredients.
@MainActor
@Suite("Produce variety coverage")
struct ProduceVarietyCoverageTests {

    // MARK: - Wording

    @Test(
        "given only one kind of produce, when breaking the day down, then only that kind is named, singular for one",
        arguments: [
            (0, 1, "1 vegetable"),
            (0, 3, "3 veg"),
            (1, 0, "1 fruit"),
            (2, 0, "2 fruits"),
            (2, 1, "2 fruits, 1 vegetable"),
            (1, 2, "1 fruit, 2 veg")
        ] as [(Int, Int, String)]
    )
    func breakdownWording(fruits: Int, vegetables: Int, expected: String) {
        let fruitNames = ["Apple", "Banana", "Cherry"].prefix(fruits)
        let vegetableNames = ["Kale", "Leek", "Okra"].prefix(vegetables)
        let entries = fruitNames.map { produce($0, .fruit) } + vegetableNames.map { produce($0, .vegetable) }

        let summary = ProduceVarietySummary(entries: entries)

        #expect(summary.fruitCount == fruits)
        #expect(summary.vegetableCount == vegetables)
        #expect(summary.totalCount == fruits + vegetables)
        #expect(summary.breakdownText == expected)
    }

    @Test("given more than three kinds, when previewing them, then three are named and the rest counted")
    func previewSummarisesBeyondThree() {
        let summary = ProduceVarietySummary(entries: [
            produce("Apple", .fruit),
            produce("Banana", .fruit),
            produce("Kale", .vegetable),
            produce("Leek", .vegetable),
            produce("Okra", .vegetable)
        ])

        #expect(summary.previewText == "Apple, Banana, Kale + 2 more")
    }

    @Test("given exactly three kinds, when previewing them, then all three are named with no overflow")
    func previewOfExactlyThree() {
        let summary = ProduceVarietySummary(entries: [
            produce("Apple", .fruit),
            produce("Kale", .vegetable),
            produce("Leek", .vegetable)
        ])

        #expect(summary.previewText == "Apple, Kale, Leek")
    }

    // MARK: - Ordering

    @Test("given several kinds of the same produce type, when listing them, then fruit comes first and each type is in name order")
    func itemsAreOrderedByTypeThenName() {
        let summary = ProduceVarietySummary(entries: [
            produce("spinach", .vegetable),
            produce("cherry", .fruit),
            produce("Beetroot", .vegetable),
            produce("banana", .fruit),
            produce("Apple", .fruit)
        ])

        #expect(summary.items.map(\.name) == ["Apple", "banana", "cherry", "Beetroot", "spinach"])
        #expect(summary.items.map(\.kind) == [.fruit, .fruit, .fruit, .vegetable, .vegetable])
    }

    // MARK: - What counts as the same kind

    @Test(
        "given a singular and a plural spelling, when counting kinds, then they are one kind",
        arguments: [
            ("Peach", "Peaches"),
            ("Radish", "Radishes"),
            ("Berry", "Berries"),
            ("Kiwi", "Kiwis"),
            ("Fig", "Figs"),
            ("Red apple", "red  APPLES"),
            ("Jalapeño", "jalapenos")
        ] as [(String, String)]
    )
    func singularAndPluralAreOneKind(singular: String, plural: String) throws {
        let summary = ProduceVarietySummary(entries: [produce(singular, .vegetable), produce(plural, .vegetable)])

        #expect(summary.totalCount == 1)
        let item = try #require(summary.items.first)
        #expect(item.name == singular)
    }

    @Test("given a plural formed with -oes, when counting kinds, then it is matched to its singular")
    func pluralsInOesAreSingularised() {
        let summary = ProduceVarietySummary(entries: [
            produce("Tomato", .vegetable),
            produce("Tomatoes", .vegetable),
            produce("Potatoes", .vegetable),
            produce("Mango", .fruit),
            produce("Mangoes", .fruit)
        ])

        #expect(summary.totalCount == 3)
        #expect(summary.items.map(\.id) == ["fruit:mango", "vegetable:potato", "vegetable:tomato"])
    }

    @Test("given the same name logged as a fruit and as a vegetable, when counting kinds, then each type keeps its own")
    func theSameNameUnderTwoTypesIsTwoKinds() {
        let summary = ProduceVarietySummary(entries: [produce("Pumpkin", .fruit), produce("Pumpkin", .vegetable)])

        #expect(summary.items.map(\.id) == ["fruit:pumpkin", "vegetable:pumpkin"])
        #expect(summary.breakdownText == "1 fruit, 1 vegetable")
    }

    @Test("given a name padded with spaces, when listing it, then it is shown trimmed")
    func namesAreTrimmedForDisplay() {
        let summary = ProduceVarietySummary(entries: [produce("  Kale \n", .vegetable)])

        #expect(summary.items.map(\.name) == ["Kale"])
        #expect(summary.items.map(\.id) == ["vegetable:kale"])
    }

    @Test(
        "given a name with no letters or digits, when counting kinds, then it contributes nothing",
        arguments: ["   ", "—", "!!"]
    )
    func namesWithoutLettersAreIgnored(name: String) {
        let entry = produce(name, .fruit)

        let summary = ProduceVarietySummary(entries: [entry])

        #expect(summary.totalCount == 0)
        #expect(summary.breakdownText == "No fruit or veg logged")
    }

    // MARK: - Legacy recipes

    @Test("given a legacy recipe entry, when counting kinds, then its live ingredients with a portion are counted instead of the recipe")
    func legacyRecipeEntriesCountLiveIngredients() {
        let recipe = makeTestFoodItem(name: "Stew", produceKind: .unclassified, isRecipe: true)
        recipe.recipeIngredients = [
            ingredient("Carrots", grams: 80, kind: .vegetable, sortOrder: 0),
            ingredient("Onion", grams: 0, kind: .vegetable, sortOrder: 1),
            ingredient("Prunes", grams: 30, kind: .fruit, sortOrder: 2),
            ingredient("Beef", grams: 200, kind: .unclassified, sortOrder: 3)
        ]
        let legacyEntry = makeLegacyTestEntry(foodItem: recipe, portionGrams: 310)

        let summary = ProduceVarietySummary(entries: [legacyEntry])

        #expect(summary.items.map(\.name) == ["Prunes", "Carrots"])
        #expect(summary.items.map(\.id) == ["fruit:prune", "vegetable:carrot"])
    }

    @Test("given a legacy recipe entry with no ingredients left, when counting kinds, then the recipe's own classification is used")
    func legacyRecipeWithoutIngredientsUsesItsOwnKind() {
        let recipe = makeTestFoodItem(name: "Fruit salad", produceKind: .fruit, isRecipe: true)
        recipe.recipeIngredients = []
        let legacyEntry = makeLegacyTestEntry(foodItem: recipe, portionGrams: 150)

        let summary = ProduceVarietySummary(entries: [legacyEntry])

        #expect(summary.items.map(\.name) == ["Fruit salad"])
        #expect(summary.fruitCount == 1)
    }

    // MARK: - Fixtures

    private func produce(_ name: String, _ kind: ProduceKind, grams: Double = 80) -> FoodLogEntry {
        makeTestEntry(foodItem: makeTestFoodItem(name: name, produceKind: kind), portionGrams: grams)
    }

    private func ingredient(_ name: String, grams: Double, kind: ProduceKind, sortOrder: Int) -> RecipeIngredient {
        RecipeIngredient(
            name: name,
            portionGrams: grams,
            caloriesPer100g: 40,
            proteinPer100g: 1,
            carbsPer100g: 8,
            fatPer100g: 0.2,
            sortOrder: sortOrder,
            produceKind: kind
        )
    }
}
