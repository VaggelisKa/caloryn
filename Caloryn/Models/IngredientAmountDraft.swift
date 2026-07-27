import Foundation

/// The editable state of the ingredient amount sheet: one typed weight, and the
/// nutrition it implies.
///
/// Deliberately built from a `NutritionValues` rather than an ingredient — the
/// per-100g figures are the only fact the amount maths depends on, and taking
/// just those keeps the sheet's rules usable for anything measured in grams.
struct IngredientAmountDraft: Equatable {
    /// Per-100g figures the typed weight is scaled against.
    let nutritionPer100g: NutritionValues

    /// Free text, because the field is being typed into: it is legitimately
    /// empty or half-written between keystrokes.
    var gramsText: String

    init(nutritionPer100g: NutritionValues, initialGrams: Double) {
        self.nutritionPer100g = nutritionPer100g
        gramsText = Self.fieldText(forGrams: initialGrams)
    }

    // MARK: - The typed amount

    /// Unparseable text reads as zero, which is what stops the sheet saving.
    var grams: Double {
        Self.parseDecimal(gramsText) ?? 0
    }

    /// An ingredient that weighs nothing contributes nothing, so it is not an
    /// amount worth saving.
    var canSave: Bool {
        grams > 0
    }

    // MARK: - Preview

    var previewNutrition: NutritionValues {
        nutritionPer100g.scaled(by: grams / 100)
    }

    var previewCalories: Double { previewNutrition.calories }
    var previewProtein: Double { previewNutrition.proteinG }
    var previewCarbs: Double { previewNutrition.carbsG }
    var previewFat: Double { previewNutrition.fatG }

    // MARK: - Rules

    /// Accepts both "." and "," as the decimal separator, so the field behaves
    /// the same whichever one the keyboard produces.
    ///
    /// Only plain decimal text is a weight. `Double(_:)` on its own also reads
    /// exponent notation, hex floats, "inf" and "nan" — none of which a decimal
    /// keypad can produce, and all of which arrive as amounts no kitchen scale
    /// could mean ("1e3" was a saveable kilogram). So the characters are checked
    /// before the conversion, and anything else reads as no amount at all.
    static func parseDecimal(_ string: String) -> Double? {
        let normalized = string
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty else { return nil }
        let isPlainDecimal = normalized.allSatisfy { character in
            (character.isASCII && character.isNumber) || character == "." || character == "-" || character == "+"
        }
        guard isPlainDecimal else { return nil }
        return Double(normalized)
    }

    /// How a stored weight is shown when the sheet opens: whole grams stay
    /// whole, so a 100g portion is not presented as "100.0" to type around.
    static func fieldText(forGrams value: Double) -> String {
        value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
    }
}
