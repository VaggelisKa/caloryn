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

    func testCopyLoggedEntriesSkipsEntriesWithoutFoodItem() throws {
        let context = try makeContext()
        let food = makeTestFoodItem(name: "Deleted Food")
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

        XCTAssertTrue(copied.isEmpty)
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
