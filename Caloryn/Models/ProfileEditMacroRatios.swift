import Foundation

nonisolated struct ProfileEditMacroRatios: Equatable {
    static let defaultSplit = ProfileEditMacroRatios(protein: 0.30, carbs: 0.40, fat: 0.30)

    let protein: Double
    let carbs: Double
    let fat: Double

    private init(protein: Double, carbs: Double, fat: Double) {
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    init(dailyCalorieTarget: Int, proteinTargetG: Double, carbTargetG: Double, fatTargetG: Double) {
        let calories = Double(dailyCalorieTarget)
        guard calories > 0 else {
            self = .defaultSplit
            return
        }

        let rawProtein = (proteinTargetG * 4.0) / calories
        let rawCarbs = (carbTargetG * 4.0) / calories
        let rawFat = (fatTargetG * 9.0) / calories
        let total = rawProtein + rawCarbs + rawFat

        guard total.isFinite else {
            self = .defaultSplit
            return
        }

        guard total > 1 else {
            self.init(protein: rawProtein, carbs: rawCarbs, fat: rawFat)
            return
        }

        self.init(protein: rawProtein / total, carbs: rawCarbs / total, fat: rawFat / total)
    }
}
