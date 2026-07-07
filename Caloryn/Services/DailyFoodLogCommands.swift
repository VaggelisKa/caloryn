import Foundation
import SwiftData

@MainActor
enum DailyFoodLogCommands {
    @discardableResult
    static func logFood(
        foodItem: FoodItem,
        portionGrams: Double,
        mealType: MealType,
        logDate: Date,
        requestedSnackIndex: Int = 0,
        isNewFood: Bool,
        modelContext: ModelContext,
        now: Date = Date()
    ) -> FoodLogEntry {
        if isNewFood {
            modelContext.insert(foodItem)
        }

        foodItem.lastUsed = now

        let entry = FoodLogEntry(
            date: logDate,
            mealType: mealType,
            foodItem: foodItem,
            portionGrams: portionGrams,
            snackIndex: normalizedSnackIndex(
                for: mealType,
                requestedSnackIndex: requestedSnackIndex
            )
        )
        modelContext.insert(entry)
        return entry
    }

    @discardableResult
    static func copyLoggedEntries(
        _ entries: [FoodLogEntry],
        to date: Date,
        modelContext: ModelContext
    ) -> [FoodLogEntry] {
        entries.compactMap { entry in
            guard let food = entry.foodItem else { return nil }

            let copiedEntry = FoodLogEntry(
                date: date,
                mealType: entry.mealType,
                foodItem: food,
                portionGrams: entry.portionGrams,
                snackIndex: normalizedSnackIndex(
                    for: entry.mealType,
                    requestedSnackIndex: entry.snackIndex
                )
            )
            modelContext.insert(copiedEntry)
            return copiedEntry
        }
    }

    @discardableResult
    static func updateLoggedEntry(
        _ entry: FoodLogEntry,
        date: Date,
        mealType: MealType,
        foodItem: FoodItem,
        portionGrams: Double,
        requestedSnackIndex: Int = 0,
        modelContext: ModelContext,
        now: Date = Date()
    ) -> FoodLogEntry {
        foodItem.lastUsed = now
        entry.update(
            date: date,
            mealType: mealType,
            foodItem: foodItem,
            portionGrams: portionGrams,
            snackIndex: normalizedSnackIndex(
                for: mealType,
                requestedSnackIndex: requestedSnackIndex
            )
        )
        return entry
    }

    static func deleteLoggedEntry(
        _ entry: FoodLogEntry,
        modelContext: ModelContext
    ) {
        modelContext.delete(entry)
    }

    static func normalizedSnackIndex(
        for mealType: MealType,
        requestedSnackIndex: Int
    ) -> Int {
        mealType == .snack ? 1 : 0
    }
}
