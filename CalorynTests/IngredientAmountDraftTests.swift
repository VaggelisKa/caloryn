import Foundation
import Testing
@testable import Caloryn

/// Covers the ingredient amount sheet's rules: how a stored weight is shown
/// when the sheet opens, what counts as a usable typed amount, and the
/// nutrition preview that follows from it.
@Suite("Ingredient amount draft")
struct IngredientAmountDraftTests {

    /// 50 kcal, 5g protein, 10g carbs, 2g fat per 100g.
    private var perHundredGrams: NutritionValues {
        NutritionValues(calories: 50, proteinG: 5, carbsG: 10, fatG: 2, fiberG: 1)
    }

    private func draft(grams: Double) -> IngredientAmountDraft {
        IngredientAmountDraft(nutritionPer100g: perHundredGrams, initialGrams: grams)
    }

    private func draft(typing text: String) -> IngredientAmountDraft {
        var draft = self.draft(grams: 100)
        draft.gramsText = text
        return draft
    }

    // MARK: - Opening the sheet

    @Test("A whole-gram amount opens without a decimal point")
    func wholeGramsOpenWithoutDecimal() {
        #expect(draft(grams: 100).gramsText == "100")
    }

    @Test("A fractional amount keeps one decimal place")
    func fractionalGramsKeepOneDecimal() {
        #expect(draft(grams: 42.5).gramsText == "42.5")
    }

    /// Characterizes today's behaviour: the field shows one decimal place, so
    /// reopening a finer amount and saving it rounds the ingredient to 100g.
    @Test("An amount finer than a tenth of a gram is shown rounded")
    func finerThanATenthIsRounded() {
        let opened = draft(grams: 100.04)

        #expect(opened.gramsText == "100.0")
        #expect(opened.grams == 100)
    }

    /// `Int(_:)` on a `Double` terminates the process rather than throwing, so
    /// a weight no `Int` can hold has to come back as text. This cannot assert
    /// the absence of a trap — a trap takes the runner with it — so it asserts
    /// the result is text the field can hold instead.
    @Test("A weight beyond Int range opens the field with a number, not a crash")
    func unconvertibleWeightOpensAsText() {
        #expect(IngredientAmountDraft.fieldText(forGrams: 1e300) == "\(Int.max)")
        #expect(IngredientAmountDraft.fieldText(forGrams: -1e300) == "\(Int.min)")
    }

    @Test("A non-finite weight opens the field empty", arguments: [
        Double.infinity, -.infinity, .nan
    ])
    func nonFiniteWeightOpensEmpty(value: Double) {
        let opened = draft(grams: value)

        #expect(opened.gramsText == "")
        #expect(opened.canSave == false)
    }

    // MARK: - The typed amount

    @Test("A typed whole number is the amount")
    func typedWholeNumberIsTheAmount() {
        let typed = draft(typing: "250")

        #expect(typed.grams == 250)
        #expect(typed.canSave)
    }

    @Test("A decimal comma is accepted, so the field behaves the same on either keyboard")
    func decimalCommaIsAccepted() {
        #expect(draft(typing: "12,5").grams == 12.5)
    }

    @Test("Surrounding spaces are ignored")
    func surroundingSpacesAreIgnored() {
        #expect(draft(typing: "  75 ").grams == 75)
    }

    @Test("An empty field cannot be saved")
    func emptyFieldCannotBeSaved() {
        let typed = draft(typing: "")

        #expect(typed.grams == 0)
        #expect(typed.canSave == false)
    }

    @Test("Text that is not a number cannot be saved")
    func nonNumericTextCannotBeSaved() {
        let typed = draft(typing: "abc")

        #expect(typed.grams == 0)
        #expect(typed.canSave == false)
    }

    @Test("Zero grams cannot be saved")
    func zeroCannotBeSaved() {
        #expect(draft(typing: "0").canSave == false)
    }

    @Test("A negative amount cannot be saved")
    func negativeCannotBeSaved() {
        let typed = draft(typing: "-5")

        #expect(typed.grams == -5)
        #expect(typed.canSave == false)
    }

    /// The field is a decimal keypad, so exponent notation can only arrive by
    /// paste — and it arrives as an amount nobody weighed out.
    @Test("Exponent notation is not an amount")
    func exponentNotationIsRejected() {
        let typed = draft(typing: "1e3")

        #expect(typed.grams == 0)
        #expect(typed.canSave == false)
    }

    @Test("The other spellings Double accepts are not amounts either", arguments: [
        "1E3", "0x1p4", "inf", "-inf", "infinity", "nan", "1e400"
    ])
    func nonDecimalSpellingsAreRejected(text: String) {
        let typed = draft(typing: text)

        #expect(typed.grams == 0)
        #expect(typed.canSave == false)
    }

    @Test("Plain decimals still parse once the stricter check is in place", arguments: [
        ("12.5", 12.5), ("12,5", 12.5), ("0.5", 0.5), ("+7", 7.0), ("1000", 1000.0)
    ])
    func plainDecimalsStillParse(text: String, expected: Double) {
        #expect(draft(typing: text).grams == expected)
    }

    // MARK: - Preview

    @Test("The preview scales the per-100g values by the typed amount")
    func previewScalesByAmount() {
        let typed = draft(typing: "250")

        #expect(abs(typed.previewCalories - 125) < 0.0001)
        #expect(abs(typed.previewProtein - 12.5) < 0.0001)
        #expect(abs(typed.previewCarbs - 25) < 0.0001)
        #expect(abs(typed.previewFat - 5) < 0.0001)
        #expect(abs((typed.previewNutrition.fiberG) - 2.5) < 0.0001)
    }

    @Test("An unusable amount previews as nothing rather than as the last good value")
    func unusableAmountPreviewsAsZero() {
        let typed = draft(typing: "")

        #expect(typed.previewCalories == 0)
        #expect(typed.previewProtein == 0)
    }

    @Test("A nutrient the ingredient never stated stays unstated in the preview")
    func unstatedNutrientStaysUnstated() {
        var typed = IngredientAmountDraft(
            nutritionPer100g: NutritionValues(calories: 50, sugarsG: 4),
            initialGrams: 100
        )
        typed.gramsText = "50"

        #expect(typed.previewNutrition.sugarsG == 2)
        #expect(typed.previewNutrition.alcoholG == nil)
    }

    @MainActor
    @Test("An ingredient built from a food previews that food's nutrition")
    func ingredientFromFoodPreviewsItsNutrition() {
        let food = makeTestFoodItem(
            name: "Tomato",
            caloriesPer100g: 18,
            proteinPer100g: 0.9,
            carbsPer100g: 3.9,
            fatPer100g: 0.2,
            defaultServingG: 150
        )
        let ingredient = RecipeIngredientDraft(from: food, sortOrder: 0)
        let opened = IngredientAmountDraft(
            nutritionPer100g: ingredient.nutritionPer100g,
            initialGrams: ingredient.portionGrams
        )

        #expect(opened.gramsText == "150")
        #expect(abs(opened.previewCalories - 27) < 0.0001)
    }

    /// A food with no stated serving opens the sheet at 100g.
    @MainActor
    @Test("A food with no default serving opens at 100g")
    func foodWithoutServingOpensAtHundredGrams() {
        let food = makeTestFoodItem(name: "Flour", defaultServingG: nil)
        let ingredient = RecipeIngredientDraft(from: food, sortOrder: 0)

        #expect(ingredient.portionGrams == 100)
    }
}
