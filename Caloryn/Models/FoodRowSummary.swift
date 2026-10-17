import Foundation

/// What a food row says: the line under its name, and the figure on its right with the
/// unit that figure is counted in.
///
/// The figure's unit depends on what the row knows. A row describing one specific
/// portion says plain "kcal"; a recipe's figure is the whole thing, "kcal total"; a food
/// whose declared serving is one countable unit says what it is worth, "kcal a pot"; a
/// serving of several units ("2 squares") is worth its figure as a whole, plain "kcal",
/// since the line beside it already says how many; one with only a declared serving,
/// "kcal a serving"; and a food with neither falls back to its value, "kcal per 100 g".
/// See `docs/design/plate-market.md`, "Row".
struct FoodRowSummary: Equatable {
    /// Brand and serving, joined by a comma. `nil` when there is nothing to say.
    let subtitle: String?
    /// The kcal figure, "94".
    let figure: String
    /// What the figure counts: "kcal a pot", "kcal per 100 g", "kcal total" or "kcal".
    let figureCaption: String

    /// - Parameters:
    ///   - caloriesPerServing: What the food's declared serving adds, the serving
    ///     `servingDescription` describes.
    ///   - servingUnitName: The countable unit that serving is counted in, "pot".
    ///   - servingUnitCount: How many of those units the serving is: 1 for "1 pot (150g)",
    ///     2 for "2 squares (20g)".
    init(
        brand: String? = nil,
        servingDescription: String? = nil,
        detail: String? = nil,
        caloriesPer100g: Double,
        caloriesPerServing: Double? = nil,
        servingUnitName: String? = nil,
        servingUnitCount: Double? = nil,
        isRecipe: Bool = false,
        portionCalories: Double? = nil
    ) {
        subtitle = Self.subtitle(
            brand: brand,
            servingDescription: servingDescription,
            detail: detail,
            isRecipe: isRecipe
        )

        if let portionCalories {
            figure = Self.kcalFigure(portionCalories)
            figureCaption = "kcal"
        } else if let caloriesPerServing {
            figure = Self.kcalFigure(caloriesPerServing)
            figureCaption = isRecipe
                ? "kcal total"
                : Self.perServingCaption(unitName: servingUnitName, unitCount: servingUnitCount)
        } else {
            figure = Self.kcalFigure(caloriesPer100g)
            figureCaption = "kcal per 100 g"
        }
    }

    /// A row that describes a specific portion (`detail`) says that; a recipe otherwise
    /// says nothing, since its brand is meaningless and it has no serving of its own.
    private static func subtitle(
        brand: String?,
        servingDescription: String?,
        detail: String?,
        isRecipe: Bool
    ) -> String? {
        if let detail = detail?.trimmingCharacters(in: .whitespaces), !detail.isEmpty {
            return detail
        }
        guard !isRecipe else { return nil }

        let parts = [brand, servingDescription.map(FoodLogSheetCopy.serving)]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// "kcal a pot", "kcal an egg", or "kcal a serving" when the unit has no name. Plain
    /// "kcal" when the serving is several units: "kcal a square" beside "2 squares" would
    /// read as the cost of one while the figure is the cost of both.
    private static func perServingCaption(unitName: String?, unitCount: Double?) -> String {
        if let unitCount, abs(unitCount - 1) > 0.001 {
            return "kcal"
        }
        guard let unit = unitName?.trimmingCharacters(in: .whitespaces), !unit.isEmpty else {
            return "kcal a serving"
        }
        let article = unit.lowercased().first.map { "aeiou".contains($0) } == true ? "an" : "a"
        return "kcal \(article) \(unit)"
    }

    /// Every figure rounds to the nearest kcal, as the Portion sheet's preview, the
    /// multi-add review and the logged row on Today do, so a pot of 94.5 kcal reads 95 on
    /// the row, on the sheet it opens and in the meal it lands in.
    private static func kcalFigure(_ kcal: Double) -> String {
        "\(kcal.rounded().truncatedSafely)"
    }
}
