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
            requestedSnackIndex: 0,
            isNewFood: false,
            modelContext: context,
            now: now
        )

        XCTAssertEqual(entry.mealType, .snack)
        XCTAssertEqual(entry.snackIndex, 1)
        XCTAssertEqual(food.lastUsed, now)
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

    func testCopyLoggedEntriesPreservesMealAndSnackIndex() throws {
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
        XCTAssertEqual(copiedEntry.snackIndex, 3)
        XCTAssertEqual(copiedEntry.calories, sourceEntry.calories, accuracy: 0.001)
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
