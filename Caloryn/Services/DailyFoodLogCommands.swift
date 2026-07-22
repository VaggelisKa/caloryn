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
        modelContext: ModelContext,
        now: Date = Date()
    ) -> [FoodLogEntry] {
        entries.enumerated().map { offset, entry in
            let snapshot = FoodLogEntrySnapshot(entry: entry)
            let copiedEntry = FoodLogEntry(
                date: date,
                mealType: snapshot.mealType,
                foodItem: entry.foodItem,
                snapshot: snapshot,
                snackIndex: normalizedSnackIndex(for: snapshot.mealType),
                createdAt: now.addingTimeInterval(Double(offset) / 1_000)
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

    @discardableResult
    static func updateSnapshotEntry(
        _ entry: FoodLogEntry,
        date: Date,
        mealType: MealType,
        portionGrams: Double,
        snackIndex: Int? = nil
    ) throws -> FoodLogEntry {
        guard entry.foodItem == nil,
              PinnedFoodLogging.isSafePortion(entry.portionGrams),
              PinnedFoodLogging.isSafePortion(portionGrams) else {
            throw MealTemplateCommands.CommandError.invalidSnapshot(entry.foodName)
        }
        entry.updateFromSnapshot(
            date: date,
            mealType: mealType,
            portionGrams: portionGrams,
            snackIndex: normalizedSnackIndex(
                for: mealType,
                requestedSnackIndex: snackIndex
            )
        )
        return entry
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
