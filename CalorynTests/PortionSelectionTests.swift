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
        preservesExactGrams: Bool = false
    ) -> PortionSelection {
        PortionSelection(shape: shape, initialGrams: grams, preservesExactGrams: preservesExactGrams)
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
        let portion = selection(slicedFood, grams: 90, preservesExactGrams: true)

        #expect(portion.mode == .serving)
        #expect(portion.servingCount == 2)
    }

    /// Otherwise editing "137 g" would silently round to "3 slices" and change
    /// what the user logged.
    @Test("Reopening a saved entry that is not a whole serving falls back to grams")
    func savedOddPortionFallsBackToGrams() {
        let portion = selection(slicedFood, grams: 137, preservesExactGrams: true)

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 137)
    }

    @Test("Reopening a saved recipe entry that is not a listed fraction falls back to grams")
    func savedOddRecipePortionFallsBackToGrams() {
        let portion = selection(recipe, grams: 333, preservesExactGrams: true)

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 333)
    }

    // MARK: - Opening portion precedence

    @Test("A picker with nothing but a default opens on the default serving")
    func openingFallsBackToDefaultServing() {
        let portion = PortionSelection.opening(
            shape: slicedFood,
            defaultServingGrams: 45
        )

        #expect(portion.portionGrams == 45)
    }

    @Test("A picker for a food with no default serving opens on 100g")
    func openingFallsBackToOneHundredGrams() {
        #expect(PortionSelection.opening(shape: plainFood).portionGrams == 100)
    }

    /// The suggestion knows what this user actually logs; the default serving
    /// is a guess printed on a package.
    @Test("A suggested portion outranks the food's default serving")
    func suggestedPortionOutranksDefaultServing() {
        let portion = PortionSelection.opening(
            shape: slicedFood,
            suggestedGrams: 137,
            defaultServingGrams: 45
        )

        #expect(portion.portionGrams == 137)
    }

    @Test("An entry being edited outranks a suggested portion")
    func existingEntryOutranksSuggestedPortion() {
        let portion = PortionSelection.opening(
            shape: slicedFood,
            existingEntryGrams: 90,
            suggestedGrams: 137,
            defaultServingGrams: 45
        )

        #expect(portion.portionGrams == 90)
    }

    /// Tapping a "135 g" suggestion has to open on 135 g, not round it up to
    /// "3 slices" — the number the row promised is the number that gets logged.
    @Test("A suggested portion that is not a whole serving opens in grams")
    func suggestedOddPortionOpensInGrams() {
        let portion = PortionSelection.opening(
            shape: slicedFood,
            suggestedGrams: 137,
            defaultServingGrams: 45
        )

        #expect(portion.mode == .grams)
        #expect(portion.portionGrams == 137)
    }

    @Test("A suggested portion that is a whole number of servings opens in servings")
    func suggestedWholeServingOpensInServings() {
        let portion = PortionSelection.opening(
            shape: slicedFood,
            suggestedGrams: 90,
            defaultServingGrams: 45
        )

        #expect(portion.mode == .serving)
        #expect(portion.servingCount == 2)
    }

    /// A default serving is not specific to this log, so it is free to be
    /// re-expressed on whichever wheel the food supports.
    @Test("A default serving still opens on its expressive wheel")
    func defaultServingOpensInServings() {
        let portion = PortionSelection.opening(
            shape: recipe,
            defaultServingGrams: 800
        )

        #expect(portion.mode == .recipeServing)
    }

    // MARK: - Typing a weight

    @Test("Typing a weight sets the portion to that many grams")
    func typingSetsPortion() {
        var portion = selection(plainFood, grams: 100)
        portion.gramsInput = "250"
        portion.commitGramsInput()

        #expect(portion.portionGrams == 250)
    }

    /// The wheel could only stop on a multiple of five. The whole point of
    /// typing is that 137 is now reachable.
    @Test("A typed weight is not rounded to a step")
    func typedWeightIsNotRounded() {
        var portion = selection(plainFood, grams: 100)
        portion.gramsInput = "137"
        portion.commitGramsInput()

        #expect(portion.portionGrams == 137)
    }

    /// The calorie readout is the whole reason to type a number, so it has to
    /// follow the keystrokes rather than wait for the keypad to be dismissed.
    @Test("The portion follows each keystroke")
    func portionFollowsTyping() {
        var portion = selection(plainFood, grams: 100)

        for (text, expected) in [("3", 3.0), ("34", 34.0), ("340", 340.0)] {
            portion.gramsInput = text
            portion.gramsInputChanged()
            #expect(portion.portionGrams == expected)
        }
    }

    /// Clearing the box to type a new number would otherwise blank the calorie
    /// preview to zero on the way.
    @Test("Clearing the box mid-edit does not zero the portion")
    func clearingMidEditKeepsThePortion() {
        var portion = selection(plainFood, grams: 100)

        portion.gramsInput = ""
        portion.gramsInputChanged()

        #expect(portion.portionGrams == 100)
        // And the half-typed text is left as it is, so the cursor is not fought.
        #expect(portion.gramsInput == "")
    }

    @Test(
        "A weight the field cannot mean leaves the portion alone",
        arguments: ["", "   ", "abc", "-40", "12.5", "1e3"]
    )
    func unusableInputLeavesThePortion(text: String) {
        var portion = selection(plainFood, grams: 100)
        portion.gramsInput = text
        portion.commitGramsInput()

        #expect(portion.portionGrams == 100)
        // And the field snaps back to what is actually logged.
        #expect(portion.gramsInput == "100")
    }

    @Test(
        "A typed weight is clamped to a loggable range",
        arguments: [("0", 1.0), ("99999", 10_000.0), ("1", 1.0), ("10000", 10_000.0)]
    )
    func typedWeightIsClamped(text: String, expected: Double) {
        var portion = selection(plainFood, grams: 100)
        portion.gramsInput = text
        portion.commitGramsInput()

        #expect(portion.portionGrams == expected)
    }

    @Test("Tapping a shortcut sets the portion and the field together")
    func quickOptionSetsPortion() {
        var portion = selection(plainFood, grams: 100)
        portion.quickGramOptionChosen(200)

        #expect(portion.portionGrams == 200)
        #expect(portion.gramsInput == "200")
    }

    /// A portion scaled in from a multi-add copy is not a whole number, and
    /// displaying "137" for 137.5g would log a different amount than it shows.
    /// The separator is the reader's, not this test's — half a gram is "137,5"
    /// in a comma locale, which is where this first failed.
    @Test("A fractional portion keeps its fraction in the field")
    func fractionalPortionSurvives() {
        var portion = selection(plainFood, grams: 137.5, preservesExactGrams: true)

        #expect(portion.gramsInput != "137")
        #expect(portion.gramsInput.contains("137"))
        #expect(portion.gramsInput.contains("5"))
        #expect(portion.portionGrams == 137.5)

        // And committing that text back does not round the half gram away.
        portion.commitGramsInput()
        #expect(portion.portionGrams == 137.5)
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

    @Test("A control that is not the active mode does not move the portion")
    func inactiveControlsAreIgnored() {
        var portion = selection(slicedFood, grams: 45)
        #expect(portion.mode == .serving)

        portion.gramsInput = "300"
        portion.commitGramsInput()
        portion.quickGramOptionChosen(300)

        #expect(portion.portionGrams == 45)
    }

    // MARK: - Switching modes

    /// The gram wheel used to snap to a multiple of five on the way in, so a
    /// mode switch could quietly move the portion. A field has no rows to land
    /// on, so it cannot.
    @Test("Switching to grams keeps the portion exactly")
    func switchingToGramsKeepsThePortion() {
        var portion = selection(slicedFood, grams: 45)
        portion.servingCount = 3
        portion.servingCountChanged()
        #expect(portion.portionGrams == 135)

        portion.mode = .grams
        portion.modeChanged()

        #expect(portion.portionGrams == 135)
        #expect(portion.gramsInput == "135")
    }

    @Test("Switching to grams from an odd serving does not round it away")
    func switchingToGramsFromAnOddServing() {
        let oddServing = PortionSelection.Shape(servingGramsPerUnit: 33, defaultServingGrams: 33)
        var portion = selection(oddServing, grams: 33)
        portion.servingCount = 2
        portion.servingCountChanged()
        #expect(portion.portionGrams == 66)

        portion.mode = .grams
        portion.modeChanged()

        // The wheel would have shown 65 here, logging a gram less than chosen.
        #expect(portion.portionGrams == 66)
        #expect(portion.gramsInput == "66")
    }

    @Test("Switching to servings rounds to the nearest whole serving")
    func switchingToServingsRounds() {
        var portion = selection(slicedFood, grams: 137, preservesExactGrams: true)
        #expect(portion.mode == .grams)

        portion.mode = .serving
        portion.modeChanged()

        // 137g is closest to three 45g slices, which is 135g.
        #expect(portion.servingCount == 3)
        #expect(portion.portionGrams == 135)
    }

    @Test("Switching to recipe servings snaps to the nearest offered fraction")
    func switchingToRecipeServingsSnaps() {
        var portion = selection(recipe, grams: 333, preservesExactGrams: true)
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

    // MARK: - Shortcut amounts

    @Test("A countable food's shortcuts are multiples of its serving")
    func shortcutsFollowTheServing() {
        #expect(selection(slicedFood, grams: 45).quickGramOptions == [45, 90, 135])
    }

    @Test("A recipe's shortcuts are fractions of the whole recipe")
    func recipeShortcutsAreFractions() {
        #expect(selection(recipe, grams: 800).quickGramOptions == [200, 400, 800])
    }

    @Test("A food that knows nothing about its serving gets round numbers")
    func plainFoodGetsRoundShortcuts() {
        #expect(
            selection(plainFood, grams: 100).quickGramOptions
                == PortionSelection.fallbackQuickGramOptions
        )
    }

    /// `defaultServingG` comes from the food API and from a free-text field, so
    /// a nonsense serving reaches this. Every multiple would clamp to the same
    /// ceiling, which is three identical chips — the round numbers are better.
    @Test(
        "An unusable serving size falls back to round shortcuts",
        arguments: [1e12, 1e30, Double.infinity, .nan, -1e30, 0]
    )
    func absurdServingFallsBackToRoundShortcuts(serving: Double) {
        for isRecipe in [false, true] {
            let shape = PortionSelection.Shape(
                isRecipe: isRecipe,
                servingGramsPerUnit: isRecipe ? nil : serving,
                defaultServingGrams: serving
            )
            let options = PortionSelection(
                shape: shape,
                initialGrams: 100,
                preservesExactGrams: false
            ).quickGramOptions

            #expect(options == PortionSelection.fallbackQuickGramOptions)
        }
    }

    @Test("Every shortcut is a weight the field would accept")
    func shortcutsAreAlwaysLoggable() {
        for shape in [plainFood, slicedFood, recipe] {
            let options = PortionSelection(
                shape: shape,
                initialGrams: 100,
                preservesExactGrams: false
            ).quickGramOptions

            #expect(options.count == PortionSelection.quickGramOptionCount)
            #expect(options.allSatisfy { $0 >= PortionSelection.minimumGrams })
            #expect(options.allSatisfy { $0 <= PortionSelection.maximumGrams })
        }
    }

    // MARK: - Wheel ranges

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

    // MARK: - Editing the food underneath

    @Test("Editing the food's serving re-scales the shortcuts to match")
    func editingTheFoodRescalesShortcuts() {
        var portion = selection(plainFood, grams: 100)
        #expect(portion.quickGramOptions == PortionSelection.fallbackQuickGramOptions)

        portion.update(shape: PortionSelection.Shape(servingGramsPerUnit: 60, defaultServingGrams: 60))

        #expect(portion.quickGramOptions == [60, 120, 180])
    }

    /// Saving an inline edit clears the food's serving description, so a food
    /// measured in slices stops having slices. Before this was handled the
    /// picker kept a count wheel with one dead entry and no way back to grams.
    @Test("Losing countable servings to an inline edit falls back to grams")
    func losingServingsFallsBackToGrams() {
        var portion = selection(slicedFood, grams: 90)
        #expect(portion.mode == .serving)

        portion.update(shape: PortionSelection.Shape(defaultServingGrams: 45))

        #expect(portion.mode == .grams)
        #expect(portion.gramsInput == "90")
        // And the field can move the portion again.
        portion.gramsInput = "120"
        portion.commitGramsInput()
        #expect(portion.portionGrams == 120)
    }

    @Test("A recipe that stops being a recipe falls back to grams")
    func losingRecipeFallsBackToGrams() {
        var portion = selection(recipe, grams: 400)
        #expect(portion.mode == .recipeServing)

        portion.update(shape: PortionSelection.Shape(defaultServingGrams: 800))

        #expect(portion.mode == .grams)
        #expect(portion.gramsInput == "400")
    }

    /// The point of the whole exercise: correcting a food's calories must not
    /// quietly change how much of it you logged.
    @Test(
        "Editing the food never changes the portion",
        arguments: [
            PortionSelection.Shape(defaultServingGrams: 45),
            PortionSelection.Shape(servingGramsPerUnit: 50, defaultServingGrams: 50),
            PortionSelection.Shape(isRecipe: true, defaultServingGrams: 600),
            PortionSelection.Shape()
        ]
    )
    func editingNeverMovesThePortion(newShape: PortionSelection.Shape) {
        var portion = selection(slicedFood, grams: 90)

        portion.update(shape: newShape)

        #expect(portion.portionGrams == 90)
    }

    @Test("A mode the new food still supports is kept, with its wheel resynced")
    func supportedModeSurvivesTheEdit() {
        var portion = selection(slicedFood, grams: 90)
        #expect(portion.mode == .serving)

        // Still countable, but each slice is now heavier.
        portion.update(shape: PortionSelection.Shape(servingGramsPerUnit: 30, defaultServingGrams: 30))

        #expect(portion.mode == .serving)
        #expect(portion.portionGrams == 90)
        // 90g is now three 30g slices rather than two 45g ones.
        #expect(portion.servingCount == 3)
    }

    @Test(
        "Every mode is only offered by a food that can express it",
        arguments: [
            (PortionSelection.Mode.serving, false),
            (.recipeServing, false),
            (.grams, true)
        ]
    )
    func plainFoodOnlySupportsGrams(mode: PortionSelection.Mode, supported: Bool) {
        #expect(selection(plainFood, grams: 100).supports(mode) == supported)
    }
}
