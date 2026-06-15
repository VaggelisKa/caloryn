import Foundation

enum NutritionCalculator {
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    static func macroGrams(calories: Double, ratio: Double, caloriesPerGram: Double) -> Double {
        (calories * ratio) / caloriesPerGram
    }

    static func defaultTarget(energyExpenditure: Double, deficit: Double = 500) -> Int {
        Int(max(1200, energyExpenditure - deficit))
    }

    static func defaultTarget(tdee: Double, deficit: Double = 500) -> Int {
        defaultTarget(energyExpenditure: tdee, deficit: deficit)
    }
}
