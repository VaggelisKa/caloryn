import Testing
@testable import Caloryn

/// What a food row says on its right and under its name. See `FoodRowSummary`.
@Suite("Food row summary")
struct FoodRowSummaryTests {
    @Test("A food with a countable serving shows what one of them is worth, rounded like the Portion preview")
    func countableServing() {
        let summary = FoodRowSummary(
            brand: "Arla",
            servingDescription: "1 pot (150g)",
            caloriesPer100g: 63,
            caloriesPerServing: 94.5,
            servingUnitName: "pot",
            servingUnitCount: 1
        )

        #expect(summary.figure == "95")
        #expect(summary.figureCaption == "kcal a pot")
        #expect(summary.subtitle == "Arla, 1 pot 150 g")
    }

    @Test("A serving of several units is worth its figure as a whole, so it says plain kcal")
    func multiUnitServing() {
        let summary = FoodRowSummary(
            brand: "Marabou",
            servingDescription: "2 squares (20g)",
            caloriesPer100g: 590,
            caloriesPerServing: 118,
            servingUnitName: "square",
            servingUnitCount: 2
        )

        #expect(summary.figure == "118")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Marabou, 2 squares 20 g")
    }

    @Test(
        "The serving unit takes the article it is spoken with",
        arguments: [("egg", "kcal an egg"), ("slice", "kcal a slice"), ("  ", "kcal a serving")]
    )
    func servingArticle(unit: String, expected: String) {
        let summary = FoodRowSummary(caloriesPer100g: 100, caloriesPerServing: 70, servingUnitName: unit)
        #expect(summary.figureCaption == expected)
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

        #expect(summary.figureCaption == "kcal total")
        #expect(summary.subtitle == nil)
    }

    @Test("A row about one specific portion says that portion, in plain kcal")
    func specificPortion() {
        let summary = FoodRowSummary(
            brand: "Arla",
            servingDescription: "1 pot (150g)",
            detail: "Arla, 160 g",
            caloriesPer100g: 63,
            caloriesPerServing: 94.5,
            servingUnitName: "pot",
            portionCalories: 100.8
        )

        #expect(summary.figure == "101")
        #expect(summary.figureCaption == "kcal")
        #expect(summary.subtitle == "Arla, 160 g")
    }

    @Test("Brand and serving are joined by a comma, never a middle dot, and blanks are dropped")
    func subtitleJoin() {
        #expect(FoodRowSummary(brand: "Quaker", servingDescription: "40 g", caloriesPer100g: 380).subtitle == "Quaker, 40 g")
        #expect(FoodRowSummary(brand: " ", servingDescription: "40 g", caloriesPer100g: 380).subtitle == "40 g")
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

    @Test("A suggestion's line is its brand and the portion it would be logged at")
    func suggestionDetail() {
        #expect(FoodLogSheetCopy.suggestionDetail(brand: "Arla", portionGrams: 150) == "Arla, 150 g")
        #expect(FoodLogSheetCopy.suggestionDetail(brand: nil, portionGrams: 159.6) == "160 g")
        #expect(FoodLogSheetCopy.suggestionDetail(brand: "  ", portionGrams: 45) == "45 g")
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
