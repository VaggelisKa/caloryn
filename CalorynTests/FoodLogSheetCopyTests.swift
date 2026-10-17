import Foundation
import Testing
@testable import Caloryn

/// What a food row says on its right and under its name. See `FoodRowSummary`.
@Suite("Food row summary")
struct FoodRowSummaryTests {
    @Test("A food with a weighed serving prices that amount in plain kcal and says what 100 g is worth")
    func weighedServing() {
        let summary = FoodRowSummary(
            brand: "Quaker",
            servingDescription: "40 g",
            servingGrams: 40,
            caloriesPer100g: 380
        )

        #expect(summary.figure == "152")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Quaker, 40 g · per 100 g: 380 kcal")
    }

    @Test("A serving's weight written in its description stands in for a missing weight")
    func weightFromTheDescription() {
        let summary = FoodRowSummary(servingDescription: "40 g", caloriesPer100g: 380)

        #expect(summary.figure == "152")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "40 g · per 100 g: 380 kcal")
    }

    @Test("A countable serving is priced as a whole, rounded like the Portion preview")
    func countableServing() {
        let summary = FoodRowSummary(
            brand: "Arla",
            servingDescription: "1 pot (150g)",
            servingGrams: 150,
            caloriesPer100g: 63
        )

        #expect(summary.figure == "95")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Arla, 1 pot 150 g · per 100 g: 63 kcal")
    }

    @Test("A serving of several units is worth its figure as a whole")
    func multiUnitServing() {
        let summary = FoodRowSummary(
            brand: "Marabou",
            servingDescription: "2 squares (20g)",
            servingGrams: 20,
            caloriesPer100g: 590
        )

        #expect(summary.figure == "118")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Marabou, 2 squares 20 g · per 100 g: 590 kcal")
    }

    @Test("A known serving figure outranks its weight")
    func caloriesPerServingOutranksTheWeight() {
        let summary = FoodRowSummary(servingDescription: "1 pot (150g)", caloriesPer100g: 63, caloriesPerServing: 94.5)

        #expect(summary.figure == "95")
        #expect(summary.figureCaption == "kcal")
    }

    @Test("A serving with no description is written as its weight, grouped for the locale")
    func servingWithoutADescription() {
        let summary = FoodRowSummary(servingGrams: 1_500, caloriesPer100g: 120)

        #expect(summary.figure == 1_800.formatted())
        #expect(summary.subtitle == "\(1_500.0.spacedMacroFormatted) · per 100 g: 120 kcal")
    }

    @Test("A serving of unknown weight is described but not priced, so the figure stays per 100 g")
    func servingOfUnknownWeight() {
        let summary = FoodRowSummary(brand: "Oatly", servingDescription: "1 glass", caloriesPer100g: 46)

        #expect(summary.figure == "46")
        #expect(summary.figureCaption == "kcal per 100 g")
        #expect(summary.subtitle == "Oatly, 1 glass")
    }

    @Test("A food with no serving falls back to its value per 100 g, rounded like the Portion sheet's")
    func per100g() {
        let summary = FoodRowSummary(brand: nil, caloriesPer100g: 883.6)

        #expect(summary.figure == "884")
        #expect(summary.figureCaption == "kcal per 100 g")
        #expect(summary.subtitle == nil)
    }

    @Test("A recipe's figure is the whole thing, and its brand is never shown")
    func recipe() {
        let summary = FoodRowSummary(
            brand: "ignored",
            servingDescription: "4 servings",
            caloriesPer100g: 145,
            caloriesPerServing: 1_160,
            isRecipe: true
        )

        #expect(summary.figure == 1_160.formatted())
        #expect(summary.figureCaption == "kcal total")
        #expect(summary.subtitle == nil)
    }

    @Test("A row about one specific portion shows and prices that portion rather than the serving")
    func specificPortion() {
        let summary = FoodRowSummary(
            brand: "Arla",
            servingDescription: "1 pot (150g)",
            servingGrams: 150,
            caloriesPer100g: 63,
            portionGrams: 159.6,
            portionCalories: 100.5
        )

        #expect(summary.figure == "101")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Arla, 160 g · per 100 g: 63 kcal")
    }

    @Test("A recipe's portion leaves out the brand")
    func recipePortion() {
        let summary = FoodRowSummary(brand: "ignored", caloriesPer100g: 145, isRecipe: true, portionGrams: 300)

        #expect(summary.figure == "435")
        #expect(summary.subtitle == "300 g · per 100 g: 145 kcal")
    }

    @Test("A row that is not one food says its own line and what it adds")
    func savedMeal() {
        let summary = FoodRowSummary(detail: "Saved meal, 3 items", caloriesPer100g: 0, portionCalories: 612.4)

        #expect(summary.subtitle == "Saved meal, 3 items")
        #expect(summary.figure == "612")
        #expect(summary.figureCaption == "kcal")
    }

    @Test("VoiceOver hears the same amount and value, in words rather than a middle dot and a colon")
    func spokenSubtitle() {
        let weighed = FoodRowSummary(brand: "Quaker", servingDescription: "40 g", servingGrams: 40, caloriesPer100g: 380)
        let unnamed = FoodRowSummary(servingGrams: 40, caloriesPer100g: 380)
        let portion = FoodRowSummary(caloriesPer100g: 63, portionGrams: 150)

        #expect(weighed.subtitleAccessibilityLabel == "Quaker, 40 g, 380 kcal per 100 grams")
        #expect(unnamed.subtitleAccessibilityLabel == "40 grams, 380 kcal per 100 grams")
        #expect(portion.subtitleAccessibilityLabel == "150 grams, 63 kcal per 100 grams")
    }

    @Test("Blank brand and serving are dropped rather than joined")
    func blanksAreDropped() {
        #expect(FoodRowSummary(brand: " ", servingDescription: "40 g", caloriesPer100g: 380).subtitle == "40 g · per 100 g: 380 kcal")
        #expect(FoodRowSummary(brand: "Quaker", servingDescription: " ", caloriesPer100g: 380).subtitle == "Quaker")
    }
}

/// The sentences the Add Food and Portion sheets build out of data.
@Suite("Food log sheet copy")
struct FoodLogSheetCopyTests {
    @Test(
        "The suggestions heading names the meal in sentence case",
        arguments: [
            (MealType.breakfast, "Usually at breakfast"),
            (.lunch, "Usually at lunch"),
            (.dinner, "Usually at dinner"),
            (.snack, "Usually as a snack"),
        ]
    )
    func suggestionsTitle(meal: MealType, expected: String) {
        #expect(FoodLogSheetCopy.suggestionsTitle(for: meal) == expected)
    }

    @Test(
        "A serving's description gives its weight only when it is written in grams",
        arguments: [
            ("40 g", 40.0 as Double?),
            ("170g", 170),
            ("1 pot (150g)", 150),
            ("1 pot 150 g", 150),
            ("2 squares ( 20 g )", 20),
            ("12,5 g", 12.5),
            ("250 ml", nil),
            ("1 glass", nil),
            ("0 g", nil),
        ]
    )
    func servingGrams(description: String, expected: Double?) {
        #expect(FoodLogSheetCopy.servingGrams(description) == expected)
    }

    @Test(
        "A saved meal counts its items, and says when it cannot be read",
        arguments: [(0, "Unavailable meal"), (1, "Saved meal, 1 item"), (3, "Saved meal, 3 items")]
    )
    func savedMealDetail(count: Int, expected: String) {
        #expect(FoodLogSheetCopy.savedMealDetail(itemCount: count) == expected)
    }

    @Test("The Portion sheet's line is brand, serving and the value of 100 g")
    func portionDetail() {
        #expect(
            FoodLogSheetCopy.portionDetail(
                brand: "Arla",
                servingDescription: "1 pot (150g)",
                isRecipe: false,
                caloriesPer100g: 63
            ) == "Arla, 1 pot 150 g, 63 kcal per 100 g"
        )
        #expect(
            FoodLogSheetCopy.portionDetail(
                brand: nil,
                servingDescription: "4 servings",
                isRecipe: true,
                caloriesPer100g: 145.4
            ) == "145 kcal per 100 g"
        )
    }

    @Test(
        "A serving reads as a count and a weight, with no brackets and a space before the unit",
        arguments: [
            ("1 pot (150g)", "1 pot 150 g"),
            ("2 squares ( 20 g )", "2 squares 20 g"),
            ("1 glass (250ml)", "1 glass 250 ml"),
            ("(30g)", "30 g"),
            ("170g", "170 g"),
            ("40 g", "40 g"),
            ("  1 slice (45 g) ", "1 slice 45 g"),
            ("1 cup, prepared", "1 cup, prepared"),
            ("4 servings", "4 servings"),
        ]
    )
    func serving(description: String, expected: String) {
        #expect(FoodLogSheetCopy.serving(description) == expected)
    }

    @Test("A new log names the meal it lands in; an edit saves changes")
    func portionSaveTitle() {
        #expect(FoodLogSheetCopy.portionSaveTitle(isEditing: false, meal: .lunch) == "Log to lunch")
        #expect(FoodLogSheetCopy.portionSaveTitle(isEditing: false, meal: .snack) == "Log to snack")
        #expect(FoodLogSheetCopy.portionSaveTitle(isEditing: true, meal: .dinner) == "Save changes")
    }
}
