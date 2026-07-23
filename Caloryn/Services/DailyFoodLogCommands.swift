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
        isNewFood: Bool,
        modelContext: ModelContext,
        snackIndex: Int? = nil,
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
                requestedSnackIndex: snackIndex
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
                snackIndex: normalizedSnackIndex(for: entry.mealType)
            )
            modelContext.insert(copiedEntry)
            return copiedEntry
        }
    }

    /// Updates an existing log entry in memory. Callers remain responsible for saving the model context.
    @discardableResult
    static func updateLoggedEntry(
        _ entry: FoodLogEntry,
        date: Date,
        mealType: MealType,
        foodItem: FoodItem,
        portionGrams: Double,
        snackIndex: Int? = nil,
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
                requestedSnackIndex: snackIndex
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

    static func normalizedSnackIndex(for mealType: MealType) -> Int {
        normalizedSnackIndex(for: mealType, requestedSnackIndex: nil)
    }

    static func normalizedSnackIndex(
        for mealType: MealType,
        requestedSnackIndex: Int?
    ) -> Int {
        guard mealType == .snack else { return 0 }
        return max(1, requestedSnackIndex ?? 1)
    }
}
