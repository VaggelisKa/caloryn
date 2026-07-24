import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class FoodLogEntryTests: XCTestCase {
    func testEntrySnapshotsFoodNutritionAndNormalizesDateToStartOfDay() {
        let date = makeTestDate(year: 2026, month: 2, day: 14, hour: 18, minute: 45)
        let food = makeTestFoodItem(
            name: "Greek Yogurt",
            caloriesPer100g: 120,
            proteinPer100g: 9,
            carbsPer100g: 4,
            fatPer100g: 5,
            fiberPer100g: 1,
            sugarsPer100g: 3,
            addedSugarsPer100g: 1,
            saturatedFatPer100g: 2,
            sodiumPer100g: 0.05,
            cholesterolPer100g: 0.01
        )

        let entry = FoodLogEntry(
            date: date,
            mealType: .lunch,
            foodItem: food,
            portionGrams: 200,
            snackIndex: 4
        )

        XCTAssertEqual(entry.date, date.startOfDay)
        XCTAssertEqual(entry.mealType, .lunch)
        XCTAssertEqual(entry.snackIndex, 0)
        XCTAssertEqual(entry.foodName, "Greek Yogurt")
        XCTAssertEqual(entry.calories, 240, accuracy: 0.001)
        XCTAssertEqual(entry.proteinG, 18, accuracy: 0.001)
        XCTAssertEqual(entry.carbsG, 8, accuracy: 0.001)
        XCTAssertEqual(entry.fatG, 10, accuracy: 0.001)
        XCTAssertEqual(entry.fiberG, 2, accuracy: 0.001)
        XCTAssertEqual(entry.sugarsG ?? -1, 6, accuracy: 0.001)
        XCTAssertEqual(entry.addedSugarsG ?? -1, 2, accuracy: 0.001)
        XCTAssertEqual(entry.saturatedFatG ?? -1, 4, accuracy: 0.001)
        XCTAssertEqual(entry.sodiumG ?? -1, 0.1, accuracy: 0.001)
        XCTAssertEqual(entry.cholesterolG ?? -1, 0.02, accuracy: 0.001)
    }

    func testReusableSnapshotCapturesSourceIdentityMealContextAndPayload() {
        let food = makeTestFoodItem(
            name: "Greek Yogurt",
            caloriesPer100g: 120,
            proteinPer100g: 9,
            carbsPer100g: 4,
            fatPer100g: 5,
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let entry = makeTestEntry(
            mealType: .snack,
            foodItem: food,
            portionGrams: 200,
            snackIndex: 3
        )

        let snapshot = FoodLogEntrySnapshot(entry: entry)

        XCTAssertEqual(snapshot.sourceFoodID, food.id)
        XCTAssertEqual(snapshot.mealType, .snack)
        XCTAssertEqual(snapshot.snackIndex, 3)
        XCTAssertEqual(snapshot.foodName, "Greek Yogurt")
        XCTAssertEqual(snapshot.portionGrams, 200, accuracy: 0.001)
        XCTAssertEqual(snapshot.nutrition, entry.nutrition)
        XCTAssertEqual(snapshot.nutriscoreGradeSnapshot, "a")
        XCTAssertEqual(snapshot.produceKindSnapshotRaw, ProduceKind.fruit.rawValue)
    }

    func testReusableSnapshotRoundTripsForFuturePersistence() throws {
        let provenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .partial,
            recoveredByFallback: true
        )
        let food = makeTestFoodItem(
            name: "Persistent Yogurt",
            caloriesPer100g: 120,
            sugarsPer100g: 3,
            nutriscoreGrade: "a",
            produceKind: .fruit,
            provenance: provenance
        )
        let entry = makeTestEntry(
            mealType: .breakfast,
            foodItem: food,
            portionGrams: 175
        )
        let snapshot = FoodLogEntrySnapshot(entry: entry)

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(FoodLogEntrySnapshot.self, from: encoded)

        XCTAssertEqual(decoded, snapshot)
        XCTAssertEqual(decoded.lookupProviderSnapshotRaw, provenance.provider?.rawValue)
        XCTAssertEqual(decoded.dataSourceSnapshotRaw, provenance.source.rawValue)
        XCTAssertEqual(
            decoded.nutritionCompletenessSnapshotRaw,
            provenance.completeness.rawValue
        )
        XCTAssertEqual(decoded.recoveredByFallbackSnapshotRaw, true)
    }

    func testReusableSnapshotDecodesLegacyPayloadWithoutProvenanceFields() throws {
        let snapshot = FoodLogEntrySnapshot(
            foodItem: makeTestFoodItem(name: "Legacy"),
            portionGrams: 100
        )
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "lookupProviderSnapshotRaw")
        object.removeValue(forKey: "dataSourceSnapshotRaw")
        object.removeValue(forKey: "nutritionCompletenessSnapshotRaw")
        object.removeValue(forKey: "recoveredByFallbackSnapshotRaw")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(
            FoodLogEntrySnapshot.self,
            from: legacyData
        )

        XCTAssertNil(decoded.lookupProviderSnapshotRaw)
        XCTAssertNil(decoded.dataSourceSnapshotRaw)
        XCTAssertNil(decoded.nutritionCompletenessSnapshotRaw)
        XCTAssertNil(decoded.recoveredByFallbackSnapshotRaw)
    }

    func testSnackEntriesPreserveSnackIndexForDisplay() {
        let entry = makeTestEntry(mealType: .snack, snackIndex: 3)

        XCTAssertEqual(entry.snackIndex, 3)
        XCTAssertEqual(entry.mealType.displayName(snackIndex: entry.snackIndex), "Snack 3")
    }

    func testUpdatingEntryRefreshesMealPortionAndNutritionSnapshot() {
        let originalFood = makeTestFoodItem(
            name: "Toast",
            caloriesPer100g: 250,
            proteinPer100g: 8,
            carbsPer100g: 45,
            fatPer100g: 3
        )
        let updatedFood = makeTestFoodItem(
            name: "Skyr",
            caloriesPer100g: 60,
            proteinPer100g: 11,
            carbsPer100g: 4,
            fatPer100g: 0,
            fiberPer100g: 1
        )
        let originalDate = makeTestDate(year: 2026, month: 3, day: 10, hour: 8)
        let updatedDate = makeTestDate(year: 2026, month: 3, day: 11, hour: 20)
        let entry = FoodLogEntry(
            date: originalDate,
            mealType: .breakfast,
            foodItem: originalFood,
            portionGrams: 100
        )
        let originalID = entry.id
        let originalCreatedAt = entry.createdAt

        entry.update(
            date: updatedDate,
            mealType: .snack,
            foodItem: updatedFood,
            portionGrams: 200,
            snackIndex: 2
        )

        XCTAssertEqual(entry.id, originalID)
        XCTAssertEqual(entry.createdAt, originalCreatedAt)
        XCTAssertEqual(entry.date, updatedDate.startOfDay)
        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 2)
        XCTAssertEqual(entry.foodName, "Skyr")
        XCTAssertEqual(entry.calories, 120, accuracy: 0.001)
        XCTAssertEqual(entry.proteinG, 22, accuracy: 0.001)
        XCTAssertEqual(entry.carbsG, 8, accuracy: 0.001)
        XCTAssertEqual(entry.fatG, 0, accuracy: 0.001)
        XCTAssertEqual(entry.fiberG, 2, accuracy: 0.001)
    }

    func testUpdatingEntryClearsOptionalNutritionMissingFromUpdatedFood() {
        let originalFood = makeTestFoodItem(
            name: "Sweet Yogurt",
            caloriesPer100g: 120,
            sugarsPer100g: 8,
            sodiumPer100g: 0.05,
            cholesterolPer100g: 0.01
        )
        let updatedFood = makeTestFoodItem(
            name: "Plain Rice",
            caloriesPer100g: 130
        )
        let entry = FoodLogEntry(
            date: makeTestDate(year: 2026, month: 3, day: 10),
            mealType: .breakfast,
            foodItem: originalFood,
            portionGrams: 100
        )

        entry.update(
            date: makeTestDate(year: 2026, month: 3, day: 11),
            mealType: .lunch,
            foodItem: updatedFood,
            portionGrams: 100
        )

        XCTAssertEqual(entry.foodName, "Plain Rice")
        XCTAssertNil(entry.sugarsG)
        XCTAssertNil(entry.sodiumG)
        XCTAssertNil(entry.cholesterolG)
    }

    func testEntrySnapshotsNutriscoreAndProduceClassificationAtCreation() {
        let food = makeTestFoodItem(
            name: "Apple",
            nutriscoreGrade: "a",
            produceKind: .fruit
        )

        let entry = makeTestEntry(foodItem: food, portionGrams: 150)

        XCTAssertTrue(entry.hasQualitySnapshot)
        XCTAssertEqual(entry.nutriscoreGradeSnapshot, "a")
        XCTAssertEqual(entry.produceKindSnapshot, .fruit)
        XCTAssertNil(entry.produceItemsSnapshotRaw)
        XCTAssertEqual(entry.historicalNutriscoreGrade, "a")
        XCTAssertEqual(entry.historicalProduceKind, .fruit)
    }

    func testEntrySnapshotKeepsUnknownQualityDistinctFromLegacy() {
        let food = makeTestFoodItem(name: "Mystery Bar")

        let entry = makeTestEntry(foodItem: food, portionGrams: 40)

        // Snapshotted entry with genuinely unknown grade / unclassified kind.
        XCTAssertTrue(entry.hasQualitySnapshot)
        XCTAssertNil(entry.nutriscoreGradeSnapshot)
        XCTAssertEqual(entry.produceKindSnapshot, .unclassified)

        // Later edits to the food must not backfill the unknown snapshot.
        food.nutriscoreGrade = "b"
        food.produceKind = .fruit
        XCTAssertNil(entry.historicalNutriscoreGrade)
        XCTAssertEqual(entry.historicalProduceKind, .unclassified)
    }

    func testEditingFoodAfterLoggingDoesNotChangeEntryQualitySnapshot() {
        let food = makeTestFoodItem(
            name: "Apple",
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let entry = makeTestEntry(foodItem: food, portionGrams: 150)

        food.nutriscoreGrade = "e"
        food.produceKind = .unclassified

        XCTAssertEqual(entry.historicalNutriscoreGrade, "a")
        XCTAssertEqual(entry.historicalProduceKind, .fruit)
    }

    func testUpdatingEntryRefreshesQualitySnapshot() {
        let originalFood = makeTestFoodItem(
            name: "Apple",
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let updatedFood = makeTestFoodItem(
            name: "Cereal",
            nutriscoreGrade: "c"
        )
        let entry = makeTestEntry(foodItem: originalFood, portionGrams: 150)

        entry.update(
            date: makeTestDate(year: 2026, month: 3, day: 11),
            mealType: .breakfast,
            foodItem: updatedFood,
            portionGrams: 60
        )

        XCTAssertEqual(entry.nutriscoreGradeSnapshot, "c")
        XCTAssertEqual(entry.produceKindSnapshot, .unclassified)
    }

    func testRecipeEntrySnapshotsIngredientProduceItems() {
        let recipe = makeTestFoodItem(name: "Smoothie", isRecipe: true)
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Strawberries",
                portionGrams: 80,
                caloriesPer100g: 32,
                proteinPer100g: 0.7,
                carbsPer100g: 7.7,
                fatPer100g: 0.3,
                sortOrder: 1,
                produceKind: .fruit
            ),
            RecipeIngredient(
                name: "Spinach",
                portionGrams: 30,
                caloriesPer100g: 23,
                proteinPer100g: 2.9,
                carbsPer100g: 3.6,
                fatPer100g: 0.4,
                sortOrder: 0,
                produceKind: .vegetable
            ),
            RecipeIngredient(
                name: "Zero Portion Kale",
                portionGrams: 0,
                caloriesPer100g: 35,
                proteinPer100g: 2.9,
                carbsPer100g: 4.4,
                fatPer100g: 0.9,
                sortOrder: 2,
                produceKind: .vegetable
            )
        ]

        let entry = makeTestEntry(foodItem: recipe, portionGrams: 110)

        let items = entry.produceItemsSnapshot
        XCTAssertEqual(items?.map(\.name), ["Spinach", "Strawberries"])
        XCTAssertEqual(items?.map(\.kind), [.vegetable, .fruit])
    }

    func testLegacyEntryFallsBackToLiveRelationshipForQuality() {
        let food = makeTestFoodItem(
            name: "Apple",
            nutriscoreGrade: "b",
            produceKind: .fruit
        )
        let legacyEntry = makeLegacyTestEntry(foodItem: food, portionGrams: 100)

        XCTAssertFalse(legacyEntry.hasQualitySnapshot)
        XCTAssertEqual(legacyEntry.historicalNutriscoreGrade, "b")
        XCTAssertEqual(legacyEntry.historicalProduceKind, .fruit)

        // Once the saved food is gone, a legacy entry reports unknown.
        legacyEntry.foodItem = nil
        XCTAssertNil(legacyEntry.historicalNutriscoreGrade)
        XCTAssertNil(legacyEntry.historicalProduceKind)
    }

    func testDeletingReusableFoodPreservesQualitySnapshot() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let food = makeTestFoodItem(
            name: "Apple",
            caloriesPer100g: 52,
            nutriscoreGrade: "a",
            produceKind: .fruit,
            isCustom: true
        )
        let entry = makeTestEntry(foodItem: food, portionGrams: 150)
        context.insert(food)
        context.insert(entry)
        try context.save()

        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<FoodLogEntry>())
        let preservedEntry = try XCTUnwrap(entries.first)
        XCTAssertNil(preservedEntry.foodItem)
        XCTAssertEqual(preservedEntry.historicalNutriscoreGrade, "a")
        XCTAssertEqual(preservedEntry.historicalProduceKind, .fruit)
    }

    func testDeletingReusableFoodThroughAppPathPreservesLoggedEntrySnapshot() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let food = makeTestFoodItem(
            name: "Greek Yogurt",
            caloriesPer100g: 120,
            proteinPer100g: 9,
            carbsPer100g: 4,
            fatPer100g: 5,
            isCustom: true
        )
        let entry = makeTestEntry(
            mealType: .lunch,
            foodItem: food,
            portionGrams: 200
        )
        context.insert(food)
        context.insert(entry)
        try context.save()

        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<FoodLogEntry>())
        let preservedEntry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(preservedEntry.foodItem)
        XCTAssertEqual(preservedEntry.foodName, "Greek Yogurt")
        XCTAssertEqual(preservedEntry.calories, 240, accuracy: 0.001)
        XCTAssertEqual(preservedEntry.proteinG, 18, accuracy: 0.001)
    }
}
