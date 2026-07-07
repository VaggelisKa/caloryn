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
