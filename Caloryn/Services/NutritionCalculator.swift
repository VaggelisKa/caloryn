import Foundation

enum EnergyCalculationMode: String, Codable, CaseIterable, Identifiable {
    case lifestyleEstimate
    case dynamicHealth

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lifestyleEstimate:
            "Activity Level Estimate"
        case .dynamicHealth:
            "Auto-adjust Calories"
        }
    }

    var shortDescription: String {
        switch self {
        case .lifestyleEstimate:
            "Uses your selected activity level."
        case .dynamicHealth:
            "Uses Apple Health when activity data is available."
        }
    }
}

enum NutritionCalculator {
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// Grams of a macro for a share of a calorie budget.
    ///
    /// A zero `caloriesPerGram` has no meaningful answer, so it yields 0 rather
    /// than an infinity: an infinite gram target reads as a plausible number all
    /// the way into `UserProfile`, and only fails much later at the formatter.
    static func macroGrams(calories: Double, ratio: Double, caloriesPerGram: Double) -> Double {
        guard caloriesPerGram != 0 else { return 0 }
        return (calories * ratio) / caloriesPerGram
    }

    static func defaultTarget(energyExpenditure: Double, deficit: Double = 500) -> Int {
        // `max` returns the floor for NaN. The result is clamped rather than
        // merely made finite: callers subtract from it and sum it over a
        // period, and `Int.max` would only move the trap to their arithmetic.
        let target = max(1200, energyExpenditure - deficit)
        // `target` is now the floor or above, never NaN — `max` returns the
        // floor for NaN — so only an infinity is left to name.
        guard target.isFinite else { return CalorieDomain.maximum }
        // Truncated, not rounded: the target has always been the whole number
        // below the calculation, and a goal is not the place to change that.
        return CalorieDomain.clamped(target.truncatedSafely)
    }

    static func defaultTarget(tdee: Double, deficit: Double = 500) -> Int {
        defaultTarget(energyExpenditure: tdee, deficit: deficit)
    }
}
