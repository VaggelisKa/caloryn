import Foundation
import SwiftData

struct PinnedFoodLogPlan: Equatable {
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
enum PinnedFoodLogging {
    enum LoggingError: LocalizedError {
        case stalePlan
        case quantityRequired
        case unavailable

        var errorDescription: String? {
            switch self {
            case .stalePlan:
                "This pinned food changed. Please try again."
            case .quantityRequired:
                "Choose a valid quantity before logging."
            case .unavailable:
                "This pinned food is unavailable. Edit or unpin it before logging."
            }
        }
    }

    static func plan(
        for food: FoodItem,
        destinationMeal: MealType,
        destinationDate: Date,
        destinationSnackIndex: Int = 0,
        calendar: Calendar = .current
    ) -> PinnedFoodLogPlan {
        let date = calendar.startOfDay(for: destinationDate)
        let snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )

        guard isAvailableForLogging(food) else {
            return PinnedFoodLogPlan(
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

        return PinnedFoodLogPlan(
            foodID: food.id,
            destinationDate: date,
            destinationMeal: destinationMeal,
            destinationSnackIndex: snackIndex,
            action: action
        )
    }

    static func confirmedPlan(
        for food: FoodItem,
        portionGrams: Double,
        destinationMeal: MealType,
        destinationDate: Date,
        destinationSnackIndex: Int = 0,
        calendar: Calendar = .current
    ) -> PinnedFoodLogPlan {
        let date = calendar.startOfDay(for: destinationDate)
        let snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )
        let action: PinnedFoodLogPlan.Action

        if !isAvailableForLogging(food) {
            action = .unavailable
        } else if isSafePortion(portionGrams) {
            action = .log(portionGrams: portionGrams)
        } else {
            action = .confirmQuantity
        }

        return PinnedFoodLogPlan(
            foodID: food.id,
            destinationDate: date,
            destinationMeal: destinationMeal,
            destinationSnackIndex: snackIndex,
            action: action
        )
    }

    @discardableResult
    static func log(
        plan: PinnedFoodLogPlan,
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

    static func sortedPinnedFoods(from foods: [FoodItem]) -> [FoodItem] {
        foods
            .filter(\.isPinned)
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

    static func suggestedPortion(for food: FoodItem) -> Double {
        let defaultPortion = food.defaultServingG ?? 100
        guard isSafePortion(defaultPortion) else { return 100 }
        return defaultPortion
    }

    static func maximumConfirmationPortion(for food: FoodItem) -> Double {
        let suggestedPortion = suggestedPortion(for: food)
        let suggestedLimit = ceil(suggestedPortion * 4 / 5) * 5
        return min(100_000, max(500, max(suggestedPortion, suggestedLimit)))
    }

    static func setPinned(
        _ pinned: Bool,
        for food: FoodItem,
        modelContext: ModelContext,
        at date: Date = Date()
    ) throws {
        let previousRawValue = food.isPinnedRaw
        let previousPinnedAt = food.pinnedAt
        food.setPinned(pinned, at: date)

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
    ) -> PinnedFoodLogPlan.Action {
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
