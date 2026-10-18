import Foundation
import Testing
@testable import Caloryn

/// The portion rules at their edges: what a food tells the picker about itself, how grams
/// round onto a serving or a recipe fraction exactly at a half, and the bounds on what can
/// be typed.
@Suite("Portion selection at the edges")
struct PortionSelectionCoverageTests {

    private var recipe: PortionSelection.Shape {
        PortionSelection.Shape(isRecipe: true, defaultServingGrams: 800)
    }

    private var slicedFood: PortionSelection.Shape {
        PortionSelection.Shape(servingGramsPerUnit: 45, defaultServingGrams: 45)
    }

    // MARK: - What a food says about itself

    @MainActor
    @Test("A food with a countable serving description gives the grams in one unit")
    func shapeOfACountableFood() {
        let bread = makeTestFoodItem(defaultServingG: 90, servingDescription: "2 slices")
        let shape = PortionSelection.Shape(foodItem: bread)

        // 90 g over 2 slices
        #expect(shape == PortionSelection.Shape(isRecipe: false, servingGramsPerUnit: 45, defaultServingGrams: 90))
        #expect(shape.hasCountableServing)
    }

    @MainActor
    @Test("A serving described only as a weight is not countable")
    func shapeOfAWeighedFood() {
        let yoghurt = makeTestFoodItem(defaultServingG: 150, servingDescription: "150 g")
        let shape = PortionSelection.Shape(foodItem: yoghurt)

        #expect(shape == PortionSelection.Shape(isRecipe: false, servingGramsPerUnit: nil, defaultServingGrams: 150))
        #expect(shape.hasCountableServing == false)
    }

    @MainActor
    @Test("A recipe carries its total weight as the default serving")
    func shapeOfARecipe() {
        let stew = makeTestFoodItem(defaultServingG: 800, isRecipe: true)

        #expect(PortionSelection.Shape(foodItem: stew) == recipe)
    }

    @Test("A recipe with no recorded total is treated as 100 g")
    func recipeWithoutATotal() {
        let untotalled = PortionSelection.Shape(isRecipe: true)
        var portion = PortionSelection.opening(shape: untotalled)

        #expect(untotalled.recipeTotalGrams == 100)
        #expect(portion.mode == .recipeServing)
        #expect(portion.recipeServingID == "1")
        #expect(portion.quickGramOptions == [25, 50, 100])

        portion.recipeServingID = "4"
        portion.recipeServingChanged()
        #expect(portion.portionGrams == 400)
        #expect(portion.gramsInput == "400")
    }

    @Test("The recipe fractions on offer and their labels")
    func recipeServingOptions() {
        #expect(PortionSelection.recipeServingOptions.map(\.label) == ["1/4", "1/2", "1", "2", "3", "4"])
        #expect(PortionSelection.recipeServingOptions.map(\.multiplier) == [0.25, 0.5, 1, 2, 3, 4])
        #expect(PortionSelection.recipeServingOption(id: "half")?.multiplier == 0.5)
        #expect(PortionSelection.recipeServingOption(id: "bogus") == nil)
    }

    // MARK: - A recipe weighed in grams

    @Test("Typing a weight for a recipe moves the fraction it would snap to")
    func typingMovesTheRecipeFraction() {
        var portion = PortionSelection(shape: recipe, initialGrams: 333, preservesExactGrams: true)
        #expect(portion.mode == .grams)

        portion.gramsInput = "200"
        portion.gramsInputChanged()
        // 200 / 800 = 1/4
        #expect(portion.portionGrams == 200)
        #expect(portion.recipeServingID == "quarter")
        #expect(portion.selectedRecipeServingOption?.label == "1/4")

        portion.quickGramOptionChosen(800)
        #expect(portion.recipeServingID == "1")

        portion.gramsStepped(.more)
        // 810 / 800 = 1.0125, still nearest the whole recipe
        #expect(portion.portionGrams == 810)
        #expect(portion.recipeServingID == "1")
    }

    @Test(
        "A weight exactly between two recipe fractions snaps to the smaller one",
        arguments: [
            (300.0, "quarter"),     // 0.375: 1/8 from both 1/4 and 1/2
            (600.0, "half"),        // 0.75: 1/4 from both 1/2 and 1
            (1_200.0, "1"),         // 1.5: 1/2 from both 1 and 2
            (2_000.0, "2"),         // 2.5: 1/2 from both 2 and 3
            (601.0, "1"),           // just past the midpoint goes up
            (599.0, "half"),
        ]
    )
    func recipeTiesSnapDown(grams: Double, expectedID: String) {
        #expect(PortionSelection.nearestRecipeServingOptionID(for: grams, recipeTotalGrams: 800) == expectedID)
    }

    @Test("A weight beyond the largest fraction snaps to four recipes, and nothing to a quarter")
    func recipeFractionExtremes() {
        #expect(PortionSelection.nearestRecipeServingOptionID(for: 80_000, recipeTotalGrams: 800) == "4")
        #expect(PortionSelection.nearestRecipeServingOptionID(for: 0, recipeTotalGrams: 800) == "quarter")
        #expect(PortionSelection.nearestRecipeServingOptionID(for: 250, recipeTotalGrams: -800) == "1")
    }

    @Test("Switching a tied recipe weight onto the fraction wheel lands on the smaller fraction")
    func switchingATiedRecipeWeight() {
        var portion = PortionSelection(shape: recipe, initialGrams: 600, preservesExactGrams: true)
        #expect(portion.mode == .grams)

        portion.mode = .recipeServing
        portion.modeChanged()

        // 0.75 of 800 sits between a half and a whole; it settles on the half.
        #expect(portion.recipeServingID == "half")
        #expect(portion.portionGrams == 400)
    }

    @Test("Reopening a recipe entry that is exactly a listed fraction opens on that fraction")
    func reopeningAnExactRecipeFraction() {
        let portion = PortionSelection(shape: recipe, initialGrams: 200, preservesExactGrams: true)

        #expect(portion.mode == .recipeServing)
        #expect(portion.recipeServingID == "quarter")
        #expect(portion.portionGrams == 200)
    }

    @Test("An unknown recipe fraction leaves the portion where it was")
    func unknownRecipeFraction() {
        var portion = PortionSelection(shape: recipe, initialGrams: 400, preservesExactGrams: false)
        portion.recipeServingID = "bogus"
        portion.recipeServingChanged()

        #expect(portion.selectedRecipeServingOption == nil)
        #expect(portion.portionGrams == 400)
    }

    @Test("A recipe that gains weight in an edit keeps its grams and re-snaps the fraction")
    func recipeEditResnapsTheFraction() {
        var portion = PortionSelection(shape: recipe, initialGrams: 400, preservesExactGrams: false)
        #expect(portion.recipeServingID == "half")

        portion.update(shape: PortionSelection.Shape(isRecipe: true, defaultServingGrams: 1_600))

        // 400 / 1600 = 1/4
        #expect(portion.mode == .recipeServing)
        #expect(portion.portionGrams == 400)
        #expect(portion.recipeServingID == "quarter")

        portion.recipeServingID = "half"
        portion.recipeServingChanged()
        #expect(portion.portionGrams == 800)
    }

    // MARK: - Countable servings at a half

    @Test(
        "Grams round to the nearest whole serving, a half rounding up, never below one or above the cap",
        arguments: [
            (67.5, 2),      // 1.5 servings
            (22.5, 1),      // 0.5 servings
            (22.4, 1),      // 0.498 servings rounds to 0, held at 1
            (0.0, 1),
            (112.5, 3),     // 2.5 servings
            (1_000.0, 10),  // 22.2 servings, capped
        ]
    )
    func servingCountRounding(grams: Double, expected: Int) {
        #expect(PortionSelection.normalizedServingCount(for: grams, shape: slicedFood) == expected)
    }

    @Test("A food with no countable serving always counts one")
    func servingCountWithoutAServing() {
        #expect(PortionSelection.normalizedServingCount(for: 450, shape: PortionSelection.Shape()) == 1)
        #expect(PortionSelection.maxServingCount(for: PortionSelection.Shape()) == 1)
    }

    @Test("Switching half-way servings onto the wheel rounds up and moves the grams with it")
    func switchingHalfServingsOntoTheWheel() {
        var portion = PortionSelection(shape: slicedFood, initialGrams: 112.5, preservesExactGrams: true)
        // 2.5 servings is not a whole one, so it opens in grams.
        #expect(portion.mode == .grams)

        portion.mode = .serving
        portion.modeChanged()

        // 3 × 45
        #expect(portion.servingCount == 3)
        #expect(portion.portionGrams == 135)
    }

    @Test(
        "The wheel offers up to 500 g of servings, between two and ten of them",
        arguments: [
            (45.0, 10),     // 11.1, capped at 10
            (50.0, 10),     // exactly 10
            (51.0, 9),      // 9.8 truncated
            (100.0, 5),
            (250.0, 2),
            (300.0, 2),     // 1.67 truncated to 1, floored at 2
            (1_000.0, 2),   // 0.5 truncated to 0, floored at 2
        ]
    )
    func servingWheelSize(gramsPerUnit: Double, expected: Int) {
        let shape = PortionSelection.Shape(servingGramsPerUnit: gramsPerUnit, defaultServingGrams: gramsPerUnit)
        #expect(PortionSelection.maxServingCount(for: shape) == expected)
    }

    @Test("Changing the serving count does nothing while the portion is weighed in grams")
    func servingCountIgnoredInGrams() {
        var portion = PortionSelection(shape: slicedFood, initialGrams: 137, preservesExactGrams: true)
        #expect(portion.mode == .grams)

        portion.servingCount = 5
        portion.servingCountChanged()

        #expect(portion.portionGrams == 137)
    }

    @Test("Committing the field while counting servings snaps the text back to the logged grams")
    func committingInServingMode() {
        var portion = PortionSelection(shape: slicedFood, initialGrams: 90, preservesExactGrams: false)
        #expect(portion.mode == .serving)

        portion.gramsInput = "abc"
        portion.commitGramsInput()

        #expect(portion.gramsInput == "90")
        #expect(portion.portionGrams == 90)
    }

    /// "12 crackers (60 g)" is 5 g a cracker, and the wheel stops at ten, so it cannot show
    /// the default. The picker opens in grams on the 60 g that will be logged.
    @Test("A default serving with more units than the wheel holds opens in grams")
    func defaultServingPastTheWheelCap() {
        let crackers = PortionSelection.Shape(servingGramsPerUnit: 5, defaultServingGrams: 60)
        let portion = PortionSelection.opening(shape: crackers, defaultServingGrams: 60)

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 60)
        #expect(portion.gramsInput == "60")
    }

    @Test("A default serving the 500 g ceiling keeps off the wheel opens in grams")
    func defaultServingPastTheGramCeiling() {
        // 500 g / 100 g caps the wheel at five pots; the default is six.
        let pots = PortionSelection.Shape(servingGramsPerUnit: 100, defaultServingGrams: 600)
        let portion = PortionSelection.opening(shape: pots, defaultServingGrams: 600)

        #expect(portion.maxServingCount == 5)
        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 600)
    }

    @Test("A default serving at the wheel's cap still opens on the wheel")
    func defaultServingAtTheWheelCap() {
        let crackers = PortionSelection.Shape(servingGramsPerUnit: 5, defaultServingGrams: 50)
        let portion = PortionSelection.opening(shape: crackers, defaultServingGrams: 50)

        #expect(portion.mode == .serving)
        #expect(portion.servingCount == 10)
        #expect(portion.portionGrams == 50)
    }

    // MARK: - Shortcut amounts

    @Test(
        "Shortcut amounts round each multiple to whole grams, a half rounding up, and keep both ends of the loggable range",
        arguments: [
            (PortionSelection.Shape(servingGramsPerUnit: 37.5), [38, 75, 113]),   // 37.5, 75, 112.5
            (PortionSelection.Shape(servingGramsPerUnit: 1.4), [1, 3, 4]),        // 1.4, 2.8, 4.2
            (PortionSelection.Shape(isRecipe: true, defaultServingGrams: 5), [1, 3, 5]),  // 1.25, 2.5, 5
            (PortionSelection.Shape(servingGramsPerUnit: 3_333.3), [3_333, 6_667, 10_000]),
            (PortionSelection.Shape(servingGramsPerUnit: 1), [1, 2, 3]),          // exactly 1 g is loggable
            (PortionSelection.Shape(isRecipe: true, defaultServingGrams: 10_000), [2_500, 5_000, 10_000]),  // exactly 10 kg is too
        ]
    )
    func shortcutRounding(shape: PortionSelection.Shape, expected: [Int]) {
        #expect(PortionSelection.quickGramOptions(for: shape) == expected)
    }

    @Test(
        "Shortcuts fall back to round numbers once a multiple leaves the loggable range",
        arguments: [
            PortionSelection.Shape(servingGramsPerUnit: 4_000),      // 12 000 g is past 10 kg
            PortionSelection.Shape(servingGramsPerUnit: 3_333.4),    // 10 000.2 g is past 10 kg
            PortionSelection.Shape(servingGramsPerUnit: 0.5),        // 0.5 g is under a gram
            PortionSelection.Shape(isRecipe: true, defaultServingGrams: 3),  // 0.75 g is under a gram
        ]
    )
    func shortcutFallback(shape: PortionSelection.Shape) {
        #expect(PortionSelection.quickGramOptions(for: shape) == PortionSelection.fallbackQuickGramOptions)
        #expect(PortionSelection.fallbackQuickGramOptions == [50, 100, 200])
    }

    @Test("A shortcut's label names the count only for a whole number of usable servings")
    func shortcutLabelsAtTheEdges() {
        let slice = ServingInfo(unitName: "slice", gramsPerUnit: 37.5, pluralName: "slices")
        let pot = ServingInfo(unitName: "pot", gramsPerUnit: 10, pluralName: "pots")

        // 3 × 37.5 = 112.5, which rounds to the 113 g chip, so it is three slices.
        #expect(PortionSelection.quickGramOptionLabel(113, serving: slice) == "3 slices, 113 g")
        #expect(PortionSelection.quickGramOptionLabel(112, serving: slice) == "112 g")
        // Ten is the most a label counts.
        #expect(PortionSelection.quickGramOptionLabel(100, serving: pot) == "10 pots, 100 g")
        #expect(PortionSelection.quickGramOptionLabel(110, serving: pot) == "110 g")
        #expect(PortionSelection.quickGramOptionLabel(0, serving: pot) == "0 g")

        for unusable in [0.0, -10.0, .infinity, .nan] {
            let broken = ServingInfo(unitName: "pot", gramsPerUnit: unusable, pluralName: "pots")
            #expect(PortionSelection.quickGramOptionLabel(150, serving: broken) == "150 g")
        }
    }

    // MARK: - What can be typed

    @Test(
        "Typed text is trimmed, read as whole grams and clamped to 1 g – 10 kg",
        arguments: [
            ("  250 ", 250),
            ("\t75", 75),
            ("007", 7),
            ("0", 1),
            ("10001", 10_000),
        ]
    )
    func parsedGramsAccepts(text: String, expected: Int) {
        #expect(PortionSelection.parsedGrams(text) == expected)
    }

    @Test("A sign, a separator or a gap inside the number is not a weight", arguments: ["+5", "2 50", "1,000", "٫5"])
    func parsedGramsRejects(text: String) {
        #expect(PortionSelection.parsedGrams(text) == nil)
    }

    @Test("A number too long for an integer is not clamped like a merely large one")
    func parsedGramsOverflow() {
        #expect(PortionSelection.parsedGrams("99999") == 10_000)
        // Current behaviour, suspected bug: twenty nines overflow `Int(_:)`, so the field reverts instead of clamping to 10 kg.
        #expect(PortionSelection.parsedGrams("99999999999999999999") == nil)
    }

    @Test("Clamping holds every integer inside the loggable range")
    func clampedGramsBounds() {
        #expect(PortionSelection.clampedGrams(.min) == 1)
        #expect(PortionSelection.clampedGrams(-5) == 1)
        #expect(PortionSelection.clampedGrams(0) == 1)
        #expect(PortionSelection.clampedGrams(5_000) == 5_000)
        #expect(PortionSelection.clampedGrams(.max) == 10_000)
    }

    @Test("The field writes whole grams without a point or grouping, and a non-number as the minimum")
    func formattedGramsEdges() {
        #expect(PortionSelection.formattedGrams(250) == "250")
        #expect(PortionSelection.formattedGrams(10_000) == "10000")
        #expect(PortionSelection.formattedGrams(-0.0) == "0")
        #expect(PortionSelection.formattedGrams(.nan) == "1")
        #expect(PortionSelection.formattedGrams(-.infinity) == "1")
    }

    @Test("Two weights match when they differ by less than a thousandth of a gram")
    func approximateEquality() {
        #expect(PortionSelection.isApproximatelyEqual(100, 100.0005))
        #expect(PortionSelection.isApproximatelyEqual(0, 0.001) == false)
        #expect(PortionSelection.isApproximatelyEqual(100, 100.002) == false)
    }
}
