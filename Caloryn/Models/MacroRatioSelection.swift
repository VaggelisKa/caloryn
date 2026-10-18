import Foundation

struct MacroRatioSelection: Equatable {
    static let defaultSplit = ProfileEditMacroRatios.defaultSplit

    static let totalTolerance = 0.01

    enum Macro: CaseIterable {
        case protein
        case carbs
        case fat

        var displayName: String {
            switch self {
            case .protein: "Protein"
            case .carbs: "Carbs"
            case .fat: "Fat"
            }
        }

        var caloriesPerGram: Double {
            switch self {
            case .protein, .carbs: 4
            case .fat: 9
            }
        }

        var sliderRange: ClosedRange<Double> {
            switch self {
            case .protein: 0.10...0.50
            case .carbs: 0.10...0.60
            case .fat: 0.10...0.50
            }
        }
    }

    let calorieTarget: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    init(calorieTarget: Int, protein: Double, carbs: Double, fat: Double) {
        self.calorieTarget = calorieTarget
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    func ratio(for macro: Macro) -> Double {
        switch macro {
        case .protein: protein
        case .carbs: carbs
        case .fat: fat
        }
    }

    var total: Double {
        protein + carbs + fat
    }

    var isValid: Bool {
        abs(total - 1.0) <= Self.totalTolerance
    }

    func grams(for macro: Macro) -> Double {
        NutritionCalculator.macroGrams(
            calories: Double(calorieTarget),
            ratio: ratio(for: macro),
            caloriesPerGram: macro.caloriesPerGram
        )
    }

    func percentText(for macro: Macro) -> String {
        "\(Self.percent(ratio(for: macro)))%"
    }

    func gramsText(for macro: Macro) -> String {
        Double(grams(for: macro).truncatedSafely).spacedMacroFormatted
    }

    var validationMessage: String? {
        guard !isValid else { return nil }
        let shownTotal = Macro.allCases
            .reduce(0.0) { $0 + Double(Self.percent(ratio(for: $1))) }
            .truncatedSafely
        return "Ratios should total 100% (currently \(shownTotal)%)"
    }

    private static func percent(_ ratio: Double) -> Int {
        (ratio * 100).truncatedSafely
    }
}
