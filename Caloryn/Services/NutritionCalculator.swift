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
}

enum NutritionCalculator {
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    static func macroGrams(calories: Double, ratio: Double, caloriesPerGram: Double) -> Double {
        guard caloriesPerGram != 0 else { return 0 }
        return (calories * ratio) / caloriesPerGram
    }

    static func defaultTarget(energyExpenditure: Double, deficit: Double = 500) -> Int {
        // `max` returns the floor for NaN. The result is clamped rather than
        // merely made finite: callers subtract from it and sum it over a
        // period, and `Int.max` would only move the trap to their arithmetic.
        let target = max(1200, energyExpenditure - deficit)
        guard target.isFinite else { return CalorieDomain.maximum }
        return CalorieDomain.clamped(target.truncatedSafely)
    }

    static func defaultTarget(tdee: Double, deficit: Double = 500) -> Int {
        defaultTarget(energyExpenditure: tdee, deficit: deficit)
    }
}
