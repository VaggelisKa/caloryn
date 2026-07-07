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
                snackIndex: entry.snackIndex
            )
            modelContext.insert(copiedEntry)
            return copiedEntry
        }
    }

    static func normalizedSnackIndex(
        for mealType: MealType,
        requestedSnackIndex: Int
    ) -> Int {
        mealType == .snack ? max(1, requestedSnackIndex) : 0
    }
}
