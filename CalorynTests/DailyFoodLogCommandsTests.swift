import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class DailyFoodLogCommandsTests: XCTestCase {
    func testLogFoodNormalizesSnackIndexWhenPickerSwitchesToSnack() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Skyr")
        context.insert(food)
        let now = makeTestDate(year: 2026, month: 3, day: 4, hour: 9)

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 150,
            mealType: .snack,
            logDate: makeTestDate(year: 2026, month: 3, day: 4),
            isNewFood: false,
            modelContext: context,
            now: now
        )

        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 1)
        XCTAssertEqual(food.lastUsed, now)
    }

    func testLogFoodCollapsesSnacksToSingleSection() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Protein Bar")
        context.insert(food)

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 60,
            mealType: .snack,
            logDate: makeTestDate(year: 2026, month: 3, day: 4),
            isNewFood: false,
            modelContext: context
        )

        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 1)
    }

    func testLogFoodPreservesExplicitSnackSection() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Trail Mix")
        context.insert(food)

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 45,
            mealType: .snack,
            logDate: makeTestDate(year: 2026, month: 3, day: 4),
            isNewFood: false,
            modelContext: context,
            snackIndex: 3
        )

        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 3)
    }

    func testLogFoodInsertsNewFoodAndEntryTogether() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Apple", isCustom: false)

        DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: 120,
            mealType: .breakfast,
            logDate: makeTestDate(year: 2026, month: 3, day: 5),
            isNewFood: true,
            modelContext: context
        )
        try context.save()

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let entries = try context.fetch(FetchDescriptor<FoodLogEntry>())

        XCTAssertEqual(foods.count, 1)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.foodName, "Apple")
        XCTAssertEqual(entries.first?.snackIndex, 0)
    }

    func testCopyLoggedEntriesPreservesMealAndCollapsesSnacksToSingleSection() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Yogurt")
        let sourceDate = makeTestDate(year: 2026, month: 3, day: 5)
        let targetDate = makeTestDate(year: 2026, month: 3, day: 6)
        let sourceEntry = makeTestEntry(
            date: sourceDate,
            mealType: .snack,
            foodItem: food,
            portionGrams: 180,
            snackIndex: 3
        )
        context.insert(food)
        context.insert(sourceEntry)

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [sourceEntry],
            to: targetDate,
            modelContext: context
        )

        XCTAssertEqual(copied.count, 1)
        let copiedEntry = try XCTUnwrap(copied.first)
        XCTAssertEqual(copiedEntry.date, targetDate.startOfDay)
        XCTAssertEqual(copiedEntry.mealType, .snack)
        XCTAssertEqual(copiedEntry.snackIndex, 1)
        XCTAssertEqual(copiedEntry.calories, sourceEntry.calories, accuracy: 0.001)
    }

    func testCopyLoggedEntriesPreservesRecordedSnapshotAfterFoodChanges() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(
            name: "Original Yogurt",
            caloriesPer100g: 120,
            proteinPer100g: 9,
            carbsPer100g: 4,
            fatPer100g: 5,
            fiberPer100g: 1,
            sugarsPer100g: 3,
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let sourceEntry = makeTestEntry(
            mealType: .breakfast,
            foodItem: food,
            portionGrams: 200
        )
        context.insert(food)
        context.insert(sourceEntry)
        try context.save()

        food.name = "Edited Yogurt"
        food.nutritionPer100g = NutritionValues(
            calories: 999,
            proteinG: 1,
            carbsG: 1,
            fatG: 1
        )
        food.nutriscoreGrade = "e"
        food.produceKind = .unclassified

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [sourceEntry],
            to: makeTestDate(year: 2026, month: 3, day: 6),
            modelContext: context
        )

        let copiedEntry = try XCTUnwrap(copied.first)
        XCTAssertTrue(copiedEntry.foodItem === food)
        XCTAssertEqual(copiedEntry.foodName, "Original Yogurt")
        XCTAssertEqual(copiedEntry.portionGrams, 200, accuracy: 0.001)
        XCTAssertEqual(copiedEntry.nutrition, sourceEntry.nutrition)
        XCTAssertEqual(copiedEntry.calories, 240, accuracy: 0.001)
        XCTAssertEqual(copiedEntry.nutriscoreGradeSnapshot, "a")
        XCTAssertEqual(copiedEntry.produceKindSnapshot, .fruit)
    }

    func testCopyLoggedEntriesPreservesCompleteNutritionPayload() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Complete Food")
        let recordedNutrition = NutritionValues(
            calories: 101,
            proteinG: 2,
            carbsG: 3,
            fatG: 4,
            fiberG: 5,
            sugarsG: 6,
            addedSugarsG: 7,
            sucroseG: 8,
            glucoseG: 9,
            fructoseG: 10,
            lactoseG: 11,
            maltoseG: 12,
            maltodextrinsG: 13,
            starchG: 14,
            polyolsG: 15,
            saturatedFatG: 16,
            transFatG: 17,
            monounsaturatedFatG: 18,
            polyunsaturatedFatG: 19,
            omega3FatG: 20,
            omega6FatG: 21,
            omega9FatG: 22,
            saltG: 23,
            sodiumG: 24,
            cholesterolG: 25,
            solubleFiberG: 26,
            insolubleFiberG: 27,
            caseinG: 28,
            serumProteinsG: 29,
            alcoholG: 30
        )
        food.nutritionPer100g = recordedNutrition
        let sourceEntry = makeTestEntry(foodItem: food, portionGrams: 100)
        context.insert(food)
        context.insert(sourceEntry)

        food.nutritionPer100g = .zero

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [sourceEntry],
            to: makeTestDate(year: 2026, month: 3, day: 6),
            modelContext: context
        )

        XCTAssertEqual(copied.first?.nutrition, recordedNutrition)
    }

    func testCopyLoggedEntriesCopiesSnapshotWhenFoodItemIsMissing() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(
            name: "Deleted Food",
            caloriesPer100g: 175,
            proteinPer100g: 12,
            nutriscoreGrade: "b",
            produceKind: .vegetable
        )
        let sourceEntry = makeTestEntry(
            mealType: .lunch,
            foodItem: food,
            portionGrams: 120
        )
        context.insert(food)
        context.insert(sourceEntry)
        try context.save()

        food.deletePreservingLogEntrySnapshots(from: context)
        try context.save()

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [sourceEntry],
            to: makeTestDate(year: 2026, month: 3, day: 6),
            modelContext: context
        )

        let copiedEntry = try XCTUnwrap(copied.first)
        XCTAssertEqual(copied.count, 1)
        XCTAssertNil(copiedEntry.foodItem)
        XCTAssertEqual(copiedEntry.foodName, "Deleted Food")
        XCTAssertEqual(copiedEntry.portionGrams, sourceEntry.portionGrams, accuracy: 0.001)
        XCTAssertEqual(copiedEntry.nutrition, sourceEntry.nutrition)
        XCTAssertEqual(copiedEntry.nutriscoreGradeSnapshot, "b")
        XCTAssertEqual(copiedEntry.produceKindSnapshot, .vegetable)
    }

    func testCopyLoggedEntriesPreservesLegacyQualityMarker() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(
            name: "Legacy Food",
            nutriscoreGrade: "a",
            produceKind: .fruit
        )
        let sourceEntry = makeLegacyTestEntry(foodItem: food, portionGrams: 100)
        context.insert(food)
        context.insert(sourceEntry)

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [sourceEntry],
            to: makeTestDate(year: 2026, month: 3, day: 6),
            modelContext: context
        )

        let copiedEntry = try XCTUnwrap(copied.first)
        XCTAssertFalse(copiedEntry.hasQualitySnapshot)
        XCTAssertNil(copiedEntry.nutriscoreGradeSnapshot)
        XCTAssertNil(copiedEntry.produceKindSnapshotRaw)
        XCTAssertNil(copiedEntry.produceItemsSnapshotRaw)
    }

    func testCopyLoggedEntriesAssignsStableCreationOrder() throws {
        let context = try makeContext()
        let firstFood = makeTestFoodItem(name: "First")
        let secondFood = makeTestFoodItem(name: "Second")
        let firstEntry = makeTestEntry(mealType: .snack, foodItem: firstFood)
        let secondEntry = makeTestEntry(mealType: .snack, foodItem: secondFood)
        context.insert(firstFood)
        context.insert(secondFood)
        context.insert(firstEntry)
        context.insert(secondEntry)
        let now = makeTestDate(year: 2026, month: 3, day: 6, hour: 9)

        let copied = DailyFoodLogCommands.copyLoggedEntries(
            [secondEntry, firstEntry],
            to: now,
            modelContext: context,
            now: now
        )

        XCTAssertEqual(copied.map(\.foodName), ["Second", "First"])
        XCTAssertEqual(copied.map(\.snackIndex), [1, 1])
        XCTAssertEqual(copied[0].createdAt, now)
        XCTAssertEqual(copied[1].createdAt, now.addingTimeInterval(0.001))
    }

    func testUpdateLoggedEntryRefreshesExistingEntryWithoutReplacingIt() throws {
        let context = try makeContext()
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
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 3, day: 10),
            mealType: .breakfast,
            foodItem: originalFood,
            portionGrams: 100
        )
        context.insert(originalFood)
        context.insert(updatedFood)
        context.insert(entry)
        try context.save()
        let originalID = entry.id
        let originalCreatedAt = entry.createdAt
        let now = makeTestDate(year: 2026, month: 3, day: 11, hour: 20)

        let updatedEntry = DailyFoodLogCommands.updateLoggedEntry(
            entry,
            date: now,
            mealType: .snack,
            foodItem: updatedFood,
            portionGrams: 200,
            now: now
        )
        try context.save()

        XCTAssertEqual(updatedEntry.id, originalID)
        XCTAssertEqual(updatedEntry.createdAt, originalCreatedAt)
        XCTAssertEqual(updatedEntry.date, now.startOfDay)
        XCTAssertEqual(updatedEntry.mealType, .snack)
        XCTAssertEqual(updatedEntry.snackIndex, 1)
        XCTAssertEqual(updatedEntry.foodName, "Skyr")
        XCTAssertEqual(updatedEntry.calories, 120, accuracy: 0.001)
        XCTAssertEqual(updatedEntry.proteinG, 22, accuracy: 0.001)
        XCTAssertEqual(updatedEntry.carbsG, 8, accuracy: 0.001)
        XCTAssertEqual(updatedEntry.fatG, 0, accuracy: 0.001)
        XCTAssertEqual(updatedEntry.fiberG, 2, accuracy: 0.001)
        XCTAssertEqual(updatedFood.lastUsed, now)
    }

    func testUpdateLoggedEntryClearsSnackIndexWhenMovedToCoreMeal() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Soup")
        let entry = makeTestEntry(
            mealType: .snack,
            foodItem: food,
            snackIndex: 1
        )
        context.insert(food)
        context.insert(entry)

        DailyFoodLogCommands.updateLoggedEntry(
            entry,
            date: makeTestDate(year: 2026, month: 3, day: 7),
            mealType: .dinner,
            foodItem: food,
            portionGrams: 240,
            now: makeTestDate(year: 2026, month: 3, day: 7)
        )

        XCTAssertEqual(entry.mealType, .dinner)
        XCTAssertEqual(entry.snackIndex, 0)
    }

    func testUpdateLoggedEntryPreservesExplicitSnackSection() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Fruit")
        let entry = makeTestEntry(
            mealType: .snack,
            foodItem: food,
            snackIndex: 3
        )
        context.insert(food)
        context.insert(entry)

        DailyFoodLogCommands.updateLoggedEntry(
            entry,
            date: makeTestDate(year: 2026, month: 3, day: 7),
            mealType: .snack,
            foodItem: food,
            portionGrams: 160,
            snackIndex: 3
        )

        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 3)
    }

    func testDeleteLoggedEntryRemovesOnlyTheLogEntry() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Apple")
        let entry = makeTestEntry(foodItem: food)
        context.insert(food)
        context.insert(entry)
        try context.save()

        DailyFoodLogCommands.deleteLoggedEntry(entry, modelContext: context)
        try context.save()

        let foods = try context.fetch(FetchDescriptor<FoodItem>())
        let entries = try context.fetch(FetchDescriptor<FoodLogEntry>())
        XCTAssertEqual(foods.count, 1)
        XCTAssertTrue(entries.isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self,
            FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
        return ModelContext(container)
    }
}
