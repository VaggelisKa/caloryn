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

    func testLaterFoodEditsDoNotRewriteLegacyProvenanceHistory() {
        let food = makeTestFoodItem(
            provenance: FoodProvenance(
                provider: .calorynAPI,
                source: .calorynCatalog,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        let entry = makeTestEntry(foodItem: food)
        entry.lookupProviderSnapshotRaw = nil
        entry.dataSourceSnapshotRaw = nil
        entry.nutritionCompletenessSnapshotRaw = nil
        entry.recoveredByFallbackSnapshotRaw = nil

        XCTAssertFalse(entry.hasProvenanceSnapshot)
        XCTAssertEqual(entry.historicalProvenance, .unknown)

        food.provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: true
        )

        XCTAssertEqual(entry.historicalProvenance, .unknown)
    }

    func testUserNutritionEditsReplaceProviderAttributionAndSnapshotCompleteness() {
        let food = makeTestFoodItem(
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: .complete,
                recoveredByFallback: true
            )
        )
        let editedNutrition = NutritionValues(
            calories: 110,
            proteinG: 12,
            carbsG: 18,
            fatG: 0,
            fiberG: 3
        )

        food.applyUserNutritionEdit(
            editedNutrition,
            suppliedProtein: 12,
            suppliedCarbohydrates: 18,
            suppliedFat: nil
        )

        XCTAssertNil(food.provenance.provider)
        XCTAssertEqual(food.provenance.source, .userEntered)
        XCTAssertEqual(food.provenance.completeness, .partial)
        XCTAssertFalse(food.provenance.recoveredByFallback)
        XCTAssertNil(food.lookupProviderRaw)
        XCTAssertEqual(food.dataSourceRaw, FoodDataSource.userEntered.rawValue)
        XCTAssertEqual(food.nutritionCompletenessRaw, NutritionCompleteness.partial.rawValue)
        XCTAssertEqual(food.recoveredByFallbackRaw, false)
        XCTAssertEqual(food.provenance.completeness.warningLabel, "Some nutrition missing")
        let partialEntry = makeTestEntry(foodItem: food)
        XCTAssertEqual(partialEntry.historicalProvenance, food.provenance)
        XCTAssertEqual(
            partialEntry.historicalProvenance.completeness.warningLabel,
            "Some nutrition missing"
        )

        food.applyUserNutritionEdit(
            editedNutrition,
            suppliedProtein: 12,
            suppliedCarbohydrates: 18,
            suppliedFat: 0
        )

        XCTAssertEqual(food.provenance, .userEntered)
        XCTAssertEqual(food.nutritionCompletenessRaw, NutritionCompleteness.complete.rawValue)
        XCTAssertNil(food.provenance.completeness.warningLabel)
        let completeEntry = makeTestEntry(foodItem: food)
        XCTAssertEqual(completeEntry.historicalProvenance, .userEntered)
        XCTAssertNil(completeEntry.historicalProvenance.completeness.warningLabel)

        // The earlier partial snapshot stays partial after a later complete edit.
        XCTAssertEqual(partialEntry.historicalProvenance.completeness, .partial)
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

    // MARK: - Which foods are worth a nutrition notice

    /// A food saved before the provenance fields existed carries unknown
    /// completeness *and* unknown source. Warning about those meant a permanent
    /// notice on ordinary foods describing our schema rather than the food.
    func testAFoodThatMerelyPredatesProvenanceIsNotWorthANotice() {
        XCTAssertFalse(FoodProvenance.unknown.warrantsNutritionNotice)
    }

    /// But unknown completeness from a known provider is a real signal: it
    /// means `hasMinimumUsableNutrition` failed, or a recipe ingredient had
    /// unknown completeness. Those numbers may genuinely be unusable.
    func testUnknownCompletenessFromAKnownSourceIsWorthANotice() {
        for source in [FoodDataSource.calorynCatalog, .openFoodFactsCommunity, .userEntered, .mixed] {
            let provenance = FoodProvenance(
                provider: nil,
                source: source,
                completeness: .unknown,
                recoveredByFallback: false
            )

            XCTAssertTrue(
                provenance.warrantsNutritionNotice,
                "\(source) with unknown completeness should still warn"
            )
        }
    }

    func testPartialNutritionIsAlwaysWorthANotice() {
        for source in [FoodDataSource.unknown, .calorynCatalog, .userEntered, .mixed] {
            let provenance = FoodProvenance(
                provider: nil,
                source: source,
                completeness: .partial,
                recoveredByFallback: false
            )

            XCTAssertTrue(provenance.warrantsNutritionNotice, "\(source) with partial data should warn")
        }
    }

    func testCompleteNutritionIsNeverWorthANotice() {
        for source in [FoodDataSource.unknown, .calorynCatalog, .userEntered, .mixed] {
            let provenance = FoodProvenance(
                provider: nil,
                source: source,
                completeness: .complete,
                recoveredByFallback: false
            )

            XCTAssertFalse(provenance.warrantsNutritionNotice, "\(source) with complete data should be quiet")
        }
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
