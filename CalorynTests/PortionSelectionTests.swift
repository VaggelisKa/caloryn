import Testing
@testable import Caloryn

/// Covers the portion picker's mode reconciliation — the rules that keep
/// grams, countable servings, and recipe fractions agreeing with each other.
/// Until now these were only reachable by spinning three wheels.
@Suite("Portion selection")
struct PortionSelectionTests {

    // MARK: - Shapes

    private var plainFood: PortionSelection.Shape {
        PortionSelection.Shape()
    }

    /// A food logged in countable units, such as a 45g slice of bread.
    private var slicedFood: PortionSelection.Shape {
        PortionSelection.Shape(servingGramsPerUnit: 45, defaultServingGrams: 45)
    }

    private var recipe: PortionSelection.Shape {
        PortionSelection.Shape(isRecipe: true, defaultServingGrams: 800)
    }

    private func selection(
        _ shape: PortionSelection.Shape,
        grams: Double,
        isExistingEntry: Bool = false
    ) -> PortionSelection {
        PortionSelection(shape: shape, initialGrams: grams, isExistingEntry: isExistingEntry)
    }

    // MARK: - Opening state

    @Test("A food with no serving info opens in grams")
    func plainFoodOpensInGrams() {
        #expect(selection(plainFood, grams: 100).mode == .grams)
    }

    @Test("A new log of a countable food opens in servings")
    func newCountableLogOpensInServings() {
        let portion = selection(slicedFood, grams: 45)

        #expect(portion.mode == .serving)
        #expect(portion.servingCount == 1)
    }

    @Test("A new log of a recipe opens in recipe servings")
    func newRecipeLogOpensInRecipeServings() {
        #expect(selection(recipe, grams: 800).mode == .recipeServing)
    }

    @Test("Reopening a saved entry that is a whole number of servings stays in servings")
    func savedWholeServingStaysInServings() {
        let portion = selection(slicedFood, grams: 90, isExistingEntry: true)

        #expect(portion.mode == .serving)
        #expect(portion.servingCount == 2)
    }

    /// Otherwise editing "137 g" would silently round to "3 slices" and change
    /// what the user logged.
    @Test("Reopening a saved entry that is not a whole serving falls back to grams")
    func savedOddPortionFallsBackToGrams() {
        let portion = selection(slicedFood, grams: 137, isExistingEntry: true)

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 137)
    }

    @Test("Reopening a saved recipe entry that is not a listed fraction falls back to grams")
    func savedOddRecipePortionFallsBackToGrams() {
        let portion = selection(recipe, grams: 333, isExistingEntry: true)

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 333)
    }

    // MARK: - Moving the wheels

    @Test("Moving the gram wheel sets the portion to that many grams")
    func gramWheelSetsPortion() {
        var portion = selection(plainFood, grams: 100)
        portion.gramStep = 250
        portion.gramStepChanged()

        #expect(portion.portionGrams == 250)
    }

    @Test("Changing the serving count multiplies out to grams")
    func servingCountMultipliesOut() {
        var portion = selection(slicedFood, grams: 45)
        portion.servingCount = 3
        portion.servingCountChanged()

        #expect(portion.portionGrams == 135)
    }

    @Test("Choosing a recipe fraction takes that share of the recipe")
    func recipeFractionTakesItsShare() {
        var portion = selection(recipe, grams: 800)
        portion.recipeServingID = "half"
        portion.recipeServingChanged()

        #expect(portion.portionGrams == 400)
    }

    @Test("A wheel that is not the active mode does not move the portion")
    func inactiveWheelsAreIgnored() {
        var portion = selection(slicedFood, grams: 45)
        #expect(portion.mode == .serving)

        portion.gramStep = 300
        portion.gramStepChanged()

        #expect(portion.portionGrams == 45)
    }

    // MARK: - Switching modes

    @Test("Switching to grams snaps the portion to the nearest 5g step")
    func switchingToGramsSnaps() {
        var portion = selection(slicedFood, grams: 45)
        portion.servingCount = 3
        portion.servingCountChanged()
        #expect(portion.portionGrams == 135)

        portion.mode = .grams
        portion.modeChanged()

        #expect(portion.portionGrams == 135)
        #expect(portion.gramStep == 135)
    }

    @Test("Switching to servings rounds to the nearest whole serving")
    func switchingToServingsRounds() {
        var portion = selection(slicedFood, grams: 137, isExistingEntry: true)
        #expect(portion.mode == .grams)

        portion.mode = .serving
        portion.modeChanged()

        // 137g is closest to three 45g slices, which is 135g.
        #expect(portion.servingCount == 3)
        #expect(portion.portionGrams == 135)
    }

    @Test("Switching to recipe servings snaps to the nearest offered fraction")
    func switchingToRecipeServingsSnaps() {
        var portion = selection(recipe, grams: 333, isExistingEntry: true)
        #expect(portion.mode == .grams)

        portion.mode = .recipeServing
        portion.modeChanged()

        // 333g of an 800g recipe is closest to a half.
        #expect(portion.recipeServingID == "half")
        #expect(portion.portionGrams == 400)
    }

    /// Switching back and forth should settle, not drift a little further each
    /// time — which is what makes this worth a test rather than an eyeball.
    @Test("Switching modes repeatedly settles instead of drifting")
    func modeSwitchingIsStable() {
        var portion = selection(slicedFood, grams: 90)

        portion.mode = .grams
        portion.modeChanged()
        let afterFirstSwitch = portion.portionGrams

        for _ in 0..<5 {
            portion.mode = .serving
            portion.modeChanged()
            portion.mode = .grams
            portion.modeChanged()
        }

        #expect(portion.portionGrams == afterFirstSwitch)
    }

    @Test("Switching to servings on a food that has none leaves the portion alone")
    func servingModeOnAPlainFoodIsInert() {
        var portion = selection(plainFood, grams: 137)
        portion.mode = .serving
        portion.modeChanged()

        #expect(portion.portionGrams == 137)
    }

    // MARK: - Wheel ranges

    @Test("The gram wheel always reaches at least 500g")
    func gramWheelReachesFiveHundred() {
        let options = selection(plainFood, grams: 100).gramOptions

        #expect(options.first == 5)
        #expect(options.contains(500))
    }

    @Test("A recipe's gram wheel reaches four whole recipes")
    func recipeGramWheelCoversFourServings() {
        let options = selection(recipe, grams: 800).gramOptions

        #expect(options.contains(3_200))
    }

    @Test("The serving wheel offers at least two counts, so it is never a wheel of one")
    func servingWheelOffersAChoice() {
        #expect(selection(slicedFood, grams: 45).maxServingCount >= 2)
    }

    @Test("The serving wheel is capped so it stays usable")
    func servingWheelIsCapped() {
        let tinyServing = PortionSelection.Shape(servingGramsPerUnit: 5, defaultServingGrams: 5)

        #expect(selection(tinyServing, grams: 5).maxServingCount == 10)
    }

    // MARK: - Recipe fraction snapping

    @Test(
        "Grams snap to the closest offered recipe fraction",
        arguments: [
            (100.0, "quarter"),
            (400.0, "half"),
            (800.0, "1"),
            (1_600.0, "2"),
            (3_200.0, "4")
        ]
    )
    func gramsSnapToNearestFraction(grams: Double, expectedID: String) {
        #expect(
            PortionSelection.nearestRecipeServingOptionID(for: grams, recipeTotalGrams: 800)
                == expectedID
        )
    }

    /// A recipe with no recorded yield would otherwise divide by zero.
    @Test("A recipe with no recorded total falls back to a whole serving")
    func zeroTotalRecipeFallsBack() {
        #expect(
            PortionSelection.nearestRecipeServingOptionID(for: 250, recipeTotalGrams: 0)
                == PortionSelection.RecipeServingOption.one.id
        )
    }

    // MARK: - Gram snapping

    @Test(
        "Grams round to the nearest 5g step within the wheel's range",
        arguments: [(0.0, 5), (2.0, 5), (7.0, 5), (8.0, 10), (137.0, 135), (10_000.0, 500)]
    )
    func gramsSnapToSteps(grams: Double, expected: Int) {
        #expect(PortionSelection.normalizedGramStep(grams, limit: 500) == expected)
    }

    // MARK: - Editing the food underneath

    @Test("Editing the food's serving widens the gram wheel to match")
    func editingTheFoodWidensTheWheel() {
        var portion = selection(plainFood, grams: 100)
        #expect(!portion.gramOptions.contains(1_000))

        portion.shape = PortionSelection.Shape(defaultServingGrams: 1_000)

        #expect(portion.gramOptions.contains(1_000))
    }
}
