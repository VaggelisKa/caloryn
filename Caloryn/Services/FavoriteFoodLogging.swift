import Foundation
import SwiftData

struct FavoriteFoodLogPlan: Equatable {
    enum Action: Equatable {
        case log(portionGrams: Double)
        case confirmQuantity
        case unavailable
    }

    let foodID: UUID
    let destinationDate: Date
    let destinationMeal: MealType
    let destinationSnackIndex: Int
    let action: Action
}

@MainActor
enum FavoriteFoodLogging {
    static let collapsedFavoriteLimit = 5

    enum FavoriteError: LocalizedError, Equatable {
        case requiresUserCreatedFood

        var errorDescription: String? {
            switch self {
            case .requiresUserCreatedFood:
                "Only manual entries and recipes can be added to Favorites."
            }
        }
    }

    enum LoggingError: LocalizedError {
        case stalePlan
        case quantityRequired
        case unavailable

        var errorDescription: String? {
            switch self {
            case .stalePlan:
                "This favorite changed. Please try again."
            case .quantityRequired:
                "Choose a valid quantity before logging."
            case .unavailable:
                "This favorite is unavailable. Edit it or remove it from Favorites before logging."
            }
        }
    }

    static func plan(
        for food: FoodItem,
        destinationMeal: MealType,
        destinationDate: Date,
        destinationSnackIndex: Int = 0,
        calendar: Calendar = .current
    ) -> FavoriteFoodLogPlan {
        let date = calendar.startOfDay(for: destinationDate)
        let snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )

        guard isAvailableForLogging(food) else {
            return FavoriteFoodLogPlan(
                foodID: food.id,
                destinationDate: date,
                destinationMeal: destinationMeal,
                destinationSnackIndex: snackIndex,
                action: .unavailable
            )
        }

        let action = lastPortionAction(
            for: food,
            onOrBefore: date,
            calendar: calendar
        )

        return FavoriteFoodLogPlan(
            foodID: food.id,
            destinationDate: date,
            destinationMeal: destinationMeal,
            destinationSnackIndex: snackIndex,
            action: action
        )
    }

    @discardableResult
    static func log(
        plan: FavoriteFoodLogPlan,
        food: FoodItem,
        modelContext: ModelContext,
        now: Date = Date()
    ) throws -> FoodLogEntry {
        guard plan.foodID == food.id else {
            throw LoggingError.stalePlan
        }

        let portionGrams: Double
        switch plan.action {
        case .log(let portion):
            portionGrams = portion
        case .confirmQuantity:
            throw LoggingError.quantityRequired
        case .unavailable:
            throw LoggingError.unavailable
        }

        guard isAvailableForLogging(food) else {
            throw LoggingError.unavailable
        }
        guard isSafePortion(portionGrams) else {
            throw LoggingError.quantityRequired
        }

        let entry = DailyFoodLogCommands.logFood(
            foodItem: food,
            portionGrams: portionGrams,
            mealType: plan.destinationMeal,
            logDate: plan.destinationDate,
            isNewFood: false,
            modelContext: modelContext,
            snackIndex: plan.destinationSnackIndex,
            now: now
        )
        try modelContext.save()
        return entry
    }

    static func sortedFavorites(from foods: [FoodItem]) -> [FoodItem] {
        foods
            .filter(\.isFavorite)
            .sorted { lhs, rhs in
                let lhsDate = lhs.pinnedAt ?? .distantPast
                let rhsDate = rhs.pinnedAt ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }

                let nameComparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
                if nameComparison != .orderedSame {
                    return nameComparison == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func visibleFavorites(
        from foods: [FoodItem],
        showsAll: Bool
    ) -> [FoodItem] {
        let favorites = sortedFavorites(from: foods)
        guard !showsAll else { return favorites }
        return Array(favorites.prefix(collapsedFavoriteLimit))
    }

    static func hiddenFavoriteCount(
        from foods: [FoodItem],
        showsAll: Bool
    ) -> Int {
        guard !showsAll else { return 0 }
        return max(0, sortedFavorites(from: foods).count - collapsedFavoriteLimit)
    }

    static func setFavorite(
        _ favorite: Bool,
        for food: FoodItem,
        modelContext: ModelContext,
        at date: Date = Date()
    ) throws {
        guard !favorite || food.isUserCreatedFood else {
            throw FavoriteError.requiresUserCreatedFood
        }

        let previousRawValue = food.isPinnedRaw
        let previousPinnedAt = food.pinnedAt
        food.setFavorite(favorite, at: date)

        do {
            try modelContext.save()
        } catch {
            food.isPinnedRaw = previousRawValue
            food.pinnedAt = previousPinnedAt
            throw error
        }
    }

    static func isSafePortion(_ portionGrams: Double) -> Bool {
        portionGrams.isFinite && portionGrams > 0 && portionGrams <= 100_000
    }

    static func isAvailableForLogging(_ food: FoodItem) -> Bool {
        guard !food.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let requiredNutrition = [
            food.caloriesPer100g,
            food.proteinPer100g,
            food.carbsPer100g,
            food.fatPer100g,
            food.fiberPer100g,
        ]
        guard requiredNutrition.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return false
        }

        if food.isRecipe {
            guard let totalGrams = food.defaultServingG,
                  isSafePortion(totalGrams),
                  !(food.recipeIngredients ?? []).isEmpty else {
                return false
            }
        }

        return true
    }

    private static func lastPortionAction(
        for food: FoodItem,
        onOrBefore destinationDate: Date,
        calendar: Calendar
    ) -> FavoriteFoodLogPlan.Action {
        let start = calendar.startOfDay(for: destinationDate)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return .confirmQuantity
        }

        let entries = (food.logEntries ?? [])
            .filter { $0.date < end }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date {
                    return lhs.date > rhs.date
                }
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.id.uuidString > rhs.id.uuidString
            }

        guard let latest = entries.first else {
            return .confirmQuantity
        }

        let equallyRecentPortions = entries
            .prefix {
                $0.date == latest.date && $0.createdAt == latest.createdAt
            }
            .map(\.portionGrams)

        guard equallyRecentPortions.allSatisfy({ $0 == latest.portionGrams }) else {
            return .confirmQuantity
        }

        return isSafePortion(latest.portionGrams)
            ? .log(portionGrams: latest.portionGrams)
            : .confirmQuantity
    }
}
