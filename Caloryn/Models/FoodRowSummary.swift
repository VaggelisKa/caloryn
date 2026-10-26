import Foundation

struct FoodRowSummary: Equatable {
    let subtitle: String?
    let subtitleAccessibilityLabel: String?
    let figure: String
    let figureCaption: String

    init(
        brand: String? = nil,
        servingDescription: String? = nil,
        servingGrams: Double? = nil,
        detail: String? = nil,
        caloriesPer100g: Double,
        caloriesPerServing: Double? = nil,
        isRecipe: Bool = false,
        portionGrams: Double? = nil,
        portionCalories: Double? = nil
    ) {
        let shownBrand = isRecipe ? nil : Self.nonEmpty(brand)

        if let detail = Self.nonEmpty(detail) {
            subtitle = detail
            subtitleAccessibilityLabel = detail
            figure = Self.kcalFigure(portionCalories ?? caloriesPer100g)
            figureCaption = portionCalories == nil ? "kcal per 100 g" : "kcal"
            return
        }

        if let portionGrams, portionGrams.isFinite, portionGrams > 0 {
            let amount = Self.amount(grams: portionGrams.rounded(), brand: shownBrand)
            subtitle = Self.priced(amount.text, caloriesPer100g: caloriesPer100g)
            subtitleAccessibilityLabel = Self.spokenPriced(amount.spoken, caloriesPer100g: caloriesPer100g)
            figure = Self.kcalFigure(portionCalories ?? caloriesPer100g * portionGrams / 100)
            figureCaption = "kcal"
            return
        }

        if isRecipe {
            subtitle = nil
            subtitleAccessibilityLabel = nil
            if let caloriesPerServing {
                figure = Self.kcalFigure(caloriesPerServing)
                figureCaption = "kcal total"
            } else {
                figure = Self.kcalFigure(caloriesPer100g)
                figureCaption = "kcal per 100 g"
            }
            return
        }

        let description = Self.nonEmpty(servingDescription).map(FoodLogSheetCopy.serving)
        let grams = servingGrams.flatMap(Self.positive)
            ?? servingDescription.flatMap(FoodLogSheetCopy.servingGrams)
        let servingKcal = caloriesPerServing.flatMap(Self.finite)
            ?? grams.map { caloriesPer100g * $0 / 100 }

        if let servingKcal, let amountText = description ?? grams.map({ $0.rounded().spacedMacroFormatted }) {
            let spokenAmount = description
                ?? grams.map { TrackedNutrientUnit.grams.spokenFormatted($0.rounded()) }
                ?? amountText
            subtitle = Self.priced(Self.joined(shownBrand, amountText), caloriesPer100g: caloriesPer100g)
            subtitleAccessibilityLabel = Self.spokenPriced(
                Self.joined(shownBrand, spokenAmount),
                caloriesPer100g: caloriesPer100g
            )
            figure = Self.kcalFigure(servingKcal)
            figureCaption = "kcal"
        } else {
            let parts = [shownBrand, description].compactMap { $0 }
            let line = parts.isEmpty ? nil : parts.joined(separator: ", ")
            subtitle = line
            subtitleAccessibilityLabel = line
            figure = Self.kcalFigure(caloriesPer100g)
            figureCaption = "kcal per 100 g"
        }
    }

    private static func amount(grams: Double, brand: String?) -> (text: String, spoken: String) {
        (
            joined(brand, grams.spacedMacroFormatted),
            joined(brand, TrackedNutrientUnit.grams.spokenFormatted(grams))
        )
    }

    private static func priced(_ amount: String, caloriesPer100g: Double) -> String {
        "\(amount) · per 100 g: \(kcalFigure(caloriesPer100g)) kcal"
    }

    private static func spokenPriced(_ amount: String, caloriesPer100g: Double) -> String {
        "\(amount), \(kcalFigure(caloriesPer100g)) kcal per 100 grams"
    }

    private static func joined(_ brand: String?, _ amount: String) -> String {
        guard let brand else { return amount }
        return "\(brand), \(amount)"
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func positive(_ grams: Double) -> Double? {
        grams.isFinite && grams > 0 ? grams : nil
    }

    private static func finite(_ kcal: Double) -> Double? {
        kcal.isFinite ? kcal : nil
    }

    private static func kcalFigure(_ kcal: Double) -> String {
        kcal.roundedCalories.formatted()
    }
}
