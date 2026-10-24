import Foundation
import SwiftData

@MainActor
enum DailyFoodLogCommands {
    enum CommandError: LocalizedError, Equatable {
        case missingEntry
        case invalidImportedEntry

        var errorDescription: String? {
            switch self {
            case .missingEntry:
                "This log entry is no longer available."
            case .invalidImportedEntry:
                "This food can’t be logged because its name, portion or nutrition values aren’t valid."
            }
        }
    }

    private static let importedCalorieRange = 0.0...20_000

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
        if foodItem.isFavorite {
            CalorynAppShortcutRefresh.favoritesChanged()
        }
        return entry
    }

    @discardableResult
    static func logImported(
        name: String,
        calories: Double,
        portionGrams: Double,
        proteinG: Double?,
        carbsG: Double?,
        fatG: Double?,
        mealType: MealType,
        snackIndex: Int?,
        logDate: Date,
        modelContext: ModelContext
    ) throws -> FoodLogEntry {
        let foodName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !foodName.isEmpty,
              importedCalorieRange.contains(calories),
              FavoriteFoodLogging.isSafePortion(portionGrams),
              [proteinG, carbsG, fatG].allSatisfy({
                  isValidImportedMacro($0, portionGrams: portionGrams)
              }) else {
            throw CommandError.invalidImportedEntry
        }

        let snapshot = FoodLogEntrySnapshot(
            foodName: foodName,
            portionGrams: portionGrams,
            nutrition: NutritionValues(
                calories: calories,
                proteinG: proteinG ?? 0,
                carbsG: carbsG ?? 0,
                fatG: fatG ?? 0
            ),
            provenance: FoodProvenance(
                provider: nil,
                source: .linkImport,
                completeness: .assessingCoreNutrition(
                    protein: proteinG,
                    carbohydrates: carbsG,
                    fat: fatG
                ),
                recoveredByFallback: false
            ),
            mealType: mealType,
            snackIndex: normalizedSnackIndex(
                for: mealType,
                requestedSnackIndex: snackIndex
            )
        )
        let entry = FoodLogEntry(
            date: logDate,
            mealType: mealType,
            foodItem: nil,
            snapshot: snapshot,
            snackIndex: snapshot.snackIndex
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
        let copiedEntries = entries.enumerated().map { offset, entry in
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
        if copiedEntries.contains(where: { $0.foodItem?.isFavorite == true }) {
            CalorynAppShortcutRefresh.favoritesChanged()
        }
        return copiedEntries
    }

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
        if foodItem.isFavorite {
            CalorynAppShortcutRefresh.favoritesChanged()
        }
        return entry
    }

    static func deleteLoggedEntry(
        _ entry: FoodLogEntry,
        modelContext: ModelContext
    ) {
        let refreshFavoriteShortcuts = entry.foodItem?.isFavorite == true
        modelContext.delete(entry)
        if refreshFavoriteShortcuts {
            CalorynAppShortcutRefresh.favoritesChanged()
        }
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
              FavoriteFoodLogging.isSafePortion(entry.portionGrams),
              FavoriteFoodLogging.isSafePortion(portionGrams) else {
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

    @discardableResult
    static func saveSnapshotEntry(
        _ entry: FoodLogEntry,
        date: Date,
        mealType: MealType,
        portionGrams: Double,
        modelContext: ModelContext,
        snackIndex: Int? = nil,
        save: (ModelContext) throws -> Void = { try $0.save() }
    ) throws -> FoodLogEntry {
        let entryID = entry.id
        let transactionContext = makeTransactionContext(from: modelContext)
        guard let storedEntry = try transactionContext.fetch(
            FetchDescriptor<FoodLogEntry>(
                predicate: #Predicate { candidate in
                    candidate.id == entryID
                }
            )
        ).first else {
            throw CommandError.missingEntry
        }

        try updateSnapshotEntry(
            storedEntry,
            date: date,
            mealType: mealType,
            portionGrams: portionGrams,
            snackIndex: snackIndex
        )
        try save(transactionContext)
        return storedEntry
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

    private static func isValidImportedMacro(_ grams: Double?, portionGrams: Double) -> Bool {
        guard let grams else { return true }
        return grams >= 0 && grams <= portionGrams
    }

    private static func makeTransactionContext(from sourceContext: ModelContext) -> ModelContext {
        let context = ModelContext(sourceContext.container)
        context.autosaveEnabled = false
        return context
    }
}
