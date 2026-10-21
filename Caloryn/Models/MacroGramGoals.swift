import Foundation

struct MacroGramGoals: Equatable {
    var proteinText: String
    var carbText: String
    var fatText: String

    static let empty = MacroGramGoals(proteinText: "", carbText: "", fatText: "")

    static func fieldText(forGrams grams: Double) -> String {
        TrackedNutrient.protein.unit.inputFormatted(grams)
    }

    static func derived(calorieTarget: Int, protein: Double, carbs: Double, fat: Double) -> MacroGramGoals {
        let selection = MacroRatioSelection(
            calorieTarget: calorieTarget,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
        return MacroGramGoals(
            proteinText: fieldText(forGrams: selection.grams(for: .protein)),
            carbText: fieldText(forGrams: selection.grams(for: .carbs)),
            fatText: fieldText(forGrams: selection.grams(for: .fat))
        )
    }

    func text(for macro: MacroRatioSelection.Macro) -> String {
        switch macro {
        case .protein: proteinText
        case .carbs: carbText
        case .fat: fatText
        }
    }

    func grams(for macro: MacroRatioSelection.Macro) -> Double? {
        let trimmed = text(for: macro).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = trimmed.decimalInputValue, value > 0 else { return nil }
        return value
    }

    var isValid: Bool { accountedCalories != nil }

    var accountedCalories: Double? {
        guard let protein = grams(for: .protein),
              let carbs = grams(for: .carbs),
              let fat = grams(for: .fat) else { return nil }
        let total = protein * 4 + carbs * 4 + fat * 9
        return total.isFinite ? total : nil
    }

    var validationMessage: String? {
        isValid ? nil : "Enter a protein, carb, and fat goal."
    }

    func sharePercent(for macro: MacroRatioSelection.Macro, calorieTarget: Int) -> Int {
        guard calorieTarget > 0, let grams = grams(for: macro) else { return 0 }
        return (grams * macro.caloriesPerGram / Double(calorieTarget) * 100).truncatedSafely
    }

    func sharePercentText(for macro: MacroRatioSelection.Macro, calorieTarget: Int) -> String {
        "\(sharePercent(for: macro, calorieTarget: calorieTarget))%"
    }

    func accountSummary(calorieTarget: Int, locale: Locale = .current) -> String? {
        guard let accountedCalories else { return nil }
        let accountedText = accountedCalories.truncatedSafely.formatted(.number.locale(locale))
        let targetText = calorieTarget.formatted(.number.locale(locale))
        return "Macros account for \(accountedText) of \(targetText) kcal"
    }

    func snappedRatios() -> (protein: Double, carbs: Double, fat: Double)? {
        guard let protein = grams(for: .protein),
              let carbs = grams(for: .carbs),
              let fat = grams(for: .fat) else { return nil }
        let proteinCalories = protein * 4
        let carbCalories = carbs * 4
        let fatCalories = fat * 9
        let total = proteinCalories + carbCalories + fatCalories
        guard total > 0, total.isFinite else { return nil }
        return (proteinCalories / total, carbCalories / total, fatCalories / total)
    }
}
