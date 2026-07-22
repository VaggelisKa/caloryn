import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class FoodProvenancePersistenceTests: XCTestCase {
    func testProviderProvenancePersistsOnSavedFoodAndLogSnapshot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: true
        )
        let food = makeTestFoodItem(name: "Recovered Product", provenance: provenance)

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 125,
            mealType: .lunch,
            logDate: makeTestDate(year: 2026, month: 7, day: 22),
            isNewFood: true,
            modelContext: context
        )
        try context.save()

        let savedFood = try XCTUnwrap(context.fetch(FetchDescriptor<FoodItem>()).first)
        let savedEntry = try XCTUnwrap(context.fetch(FetchDescriptor<FoodLogEntry>()).first)
        XCTAssertEqual(savedFood.provenance, provenance)
        XCTAssertEqual(savedEntry.historicalProvenance, provenance)
        XCTAssertTrue(savedEntry.hasProvenanceSnapshot)
        XCTAssertEqual(entry.lookupProviderSnapshotRaw, FoodSearchProvider.openFoodFacts.rawValue)

        savedFood.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        XCTAssertNil(savedEntry.foodItem)
        XCTAssertEqual(savedEntry.historicalProvenance, provenance)
    }

    func testUpdatingLogEntryRefreshesProvenanceSnapshot() {
        let first = makeTestFoodItem(
            name: "First",
            provenance: FoodProvenance(
                provider: .calorynAPI,
                source: .calorynCatalog,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        let replacement = makeTestFoodItem(
            name: "Replacement",
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: .partial,
                recoveredByFallback: true
            )
        )
        let entry = makeTestEntry(foodItem: first)

        entry.update(
            date: entry.date,
            mealType: .dinner,
            foodItem: replacement,
            portionGrams: 80
        )

        XCTAssertEqual(entry.historicalProvenance, replacement.provenance)
    }

    func testLegacyOptionalFieldsRemainUnknownAfterLightweightMigration() {
        let food = makeTestFoodItem()
        food.lookupProviderRaw = nil
        food.dataSourceRaw = nil
        food.nutritionCompletenessRaw = nil
        food.recoveredByFallbackRaw = nil

        let entry = makeTestEntry(foodItem: food)
        entry.lookupProviderSnapshotRaw = nil
        entry.dataSourceSnapshotRaw = nil
        entry.nutritionCompletenessSnapshotRaw = nil
        entry.recoveredByFallbackSnapshotRaw = nil

        XCTAssertEqual(food.provenance, .unknown)
        XCTAssertFalse(entry.hasProvenanceSnapshot)
        XCTAssertEqual(entry.historicalProvenance, .unknown)

        entry.foodItem = nil
        XCTAssertEqual(entry.historicalProvenance, .unknown)
    }

    func testRecipeIngredientCopiesProviderProvenance() {
        let provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: true
        )
        let food = makeTestFoodItem(name: "Ingredient", provenance: provenance)

        let ingredient = RecipeIngredient(from: food, portionGrams: 150, sortOrder: 0)
        let roundTrippedDraft = RecipeIngredientDraft(from: ingredient)

        XCTAssertEqual(ingredient.provenance, provenance)
        XCTAssertEqual(roundTrippedDraft.provenance, provenance)
    }

    func testRecipeAggregatesIngredientSourceAndCompleteness() {
        let recipe = makeTestFoodItem(name: "Recipe", isRecipe: true)
        let calorynFood = makeTestFoodItem(
            name: "Verified",
            provenance: FoodProvenance(
                provider: .calorynAPI,
                source: .calorynCatalog,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        let communityFood = makeTestFoodItem(
            name: "Community",
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: .partial,
                recoveredByFallback: true
            )
        )
        let ingredients = [
            RecipeIngredient(from: calorynFood, portionGrams: 100, sortOrder: 0),
            RecipeIngredient(from: communityFood, portionGrams: 100, sortOrder: 1)
        ]
        recipe.recipeIngredients = ingredients

        recipe.updateRecipeNutritionFromIngredients()

        XCTAssertEqual(recipe.provenance.provider, nil)
        XCTAssertEqual(recipe.provenance.source, .mixed)
        XCTAssertEqual(recipe.provenance.completeness, .partial)
        XCTAssertTrue(recipe.provenance.recoveredByFallback)
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
    }
}
