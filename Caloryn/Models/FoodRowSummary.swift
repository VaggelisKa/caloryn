import Foundation

/// What a food row says: the line under its name, and the figure on its right with the
/// unit that figure is counted in.
///
/// A row that shows an amount prices that amount: 40 g of a 380 kcal per 100 g food reads
/// "152" over "kcal", and the line under the name says what the amount is and what the food
/// is worth, "Quaker, 40 g · per 100 g: 380 kcal". The amount is a specific portion (a
/// suggestion's "150 g"), or the food's serving, written as declared ("1 pot 150 g") or as
/// its weight ("250 g"). A row with no amount whose grams are known falls back to the food's
/// value, "kcal per 100 g", and a recipe's figure is the whole thing, "kcal total".
/// See `docs/design/plate-market.md`, "Row".
struct FoodRowSummary: Equatable {
    /// Brand and amount, with what 100 g is worth. `nil` when there is nothing to say.
    let subtitle: String?
    /// The subtitle as VoiceOver reads it: the same facts, without the middle dot and colon
    /// it would read out or skip.
    let subtitleAccessibilityLabel: String?
    /// The kcal figure, rounded and grouped: "152", "1,900".
    let figure: String
    /// What the figure counts: "kcal", "kcal per 100 g" or "kcal total".
    let figureCaption: String

    /// - Parameters:
    ///   - servingDescription: The food's declared serving, "1 pot (150g)".
    ///   - servingGrams: What that serving weighs. When it is missing, a weight written in
    ///     the description ("40 g", "1 pot (150g)") stands in for it.
    ///   - detail: A line that replaces brand and amount, for a row that is not one food
    ///     (a saved meal's "Saved meal, 3 items").
    ///   - caloriesPerServing: What the serving adds, when the caller knows it better than
    ///     its weight does; a recipe's whole.
    ///   - portionGrams: A specific portion the row is about, which outranks the serving.
    ///   - portionCalories: What that portion, or the row's `detail`, adds.
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
            // A recipe has no serving of its own to show; its figure is the whole recipe.
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
            // Nothing to price but the food itself: a serving of unknown weight ("1 cup") is
            // still described, and the figure says it is per 100 g.
            let parts = [shownBrand, description].compactMap { $0 }
            let line = parts.isEmpty ? nil : parts.joined(separator: ", ")
            subtitle = line
            subtitleAccessibilityLabel = line
            figure = Self.kcalFigure(caloriesPer100g)
            figureCaption = "kcal per 100 g"
        }
    }

    /// "Arla, 150 g" and "Arla, 150 grams".
    private static func amount(grams: Double, brand: String?) -> (text: String, spoken: String) {
        (
            joined(brand, grams.spacedMacroFormatted),
            joined(brand, TrackedNutrientUnit.grams.spokenFormatted(grams))
        )
    }

    /// "Quaker, 40 g · per 100 g: 380 kcal".
    private static func priced(_ amount: String, caloriesPer100g: Double) -> String {
        "\(amount) · per 100 g: \(kcalFigure(caloriesPer100g)) kcal"
    }

    /// "Quaker, 40 grams, 380 kcal per 100 grams".
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

    /// Every figure rounds to the nearest kcal, as the Portion sheet's preview, the
    /// multi-add review and the logged row on Today do, so a pot of 94.5 kcal reads 95 on
    /// the row, on the sheet it opens and in the meal it lands in; grouped for the locale,
    /// as every other kcal figure is ("1.900").
    private static func kcalFigure(_ kcal: Double) -> String {
        kcal.roundedCalories.formatted()
    }
}
