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
        gramsText.decimalInputValue ?? 0
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

    /// How a stored weight is shown when the sheet opens: whole grams stay
    /// whole, so a 100g portion is not presented as "100.0" to type around.
    ///
    /// `Int(_:)` is a trap, not a conversion — a value past `Int64` range
    /// terminates the process — and the weight this renders came from a text
    /// field, so it goes through `truncatedSafely`. A non-finite weight is not
    /// a weight at all and opens the field empty.
    static func fieldText(forGrams value: Double) -> String {
        guard value.isFinite else { return "" }
        return value.rounded() == value ? "\(value.truncatedSafely)" : String(format: "%.1f", value)
    }
}
