import Testing
@testable import Caloryn

/// Covers the manual-food form's arithmetic and provenance bookkeeping, which
/// until now were only reachable by typing into thirteen text fields.
@MainActor
@Suite("Custom food draft")
struct CustomFoodDraftTests {

    // MARK: - Parsing

    @Test(
        "Decimals parse the same whichever separator the keyboard produces",
        arguments: [("12.5", 12.5), ("12,5", 12.5), ("  7 ", 7.0), ("0", 0.0)]
    )
    func decimalsParse(text: String, expected: Double) {
        #expect(CustomFoodDraft.parseDecimal(text) == expected)
    }

    @Test(
        "Text that is not a number does not parse",
        arguments: ["", "abc", "1.2.3", "--4"]
    )
    func nonNumbersDoNotParse(text: String) {
        #expect(CustomFoodDraft.parseDecimal(text) == nil)
    }

    // MARK: - Save gating

    @Test("A name and a calorie figure are enough to save")
    func minimalDraftCanSave() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        #expect(draft.canSave)
    }

    @Test("A name of only whitespace does not count as a name")
    func whitespaceNameBlocksSaving() {
        var draft = CustomFoodDraft()
        draft.name = "   "
        draft.caloriesPerServing = "380"

        #expect(!draft.canSave)
    }

    @Test("Calories must be present and non-negative")
    func caloriesAreRequired() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"

        draft.caloriesPerServing = ""
        #expect(!draft.canSave)

        draft.caloriesPerServing = "-1"
        #expect(!draft.canSave)

        draft.caloriesPerServing = "0"
        #expect(draft.canSave)
    }

    @Test("A negative optional nutrient blocks saving; leaving it blank does not")
    func negativeOptionalNutrientsBlockSaving() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        draft.sodiumPerServing = "-3"
        #expect(!draft.optionalTrackedInputsAreValid)
        #expect(!draft.canSave)

        draft.sodiumPerServing = ""
        #expect(draft.canSave)
    }

    // MARK: - Serving size

    @Test(
        "A serving that is blank, unparseable, or non-positive falls back to 100g",
        arguments: ["", "abc", "0", "-50"]
    )
    func unusableServingsFallBack(text: String) {
        var draft = CustomFoodDraft()
        draft.servingSizeGrams = text

        #expect(draft.effectiveServingGrams == CustomFoodDraft.fallbackServingGrams)
        // The fallback is only for the arithmetic; nothing unusable is stored.
        #expect(draft.storedServingGrams == nil)
    }

    @Test("A stated serving is both used and stored")
    func statedServingIsStored() {
        var draft = CustomFoodDraft()
        draft.servingSizeGrams = "40"

        #expect(draft.effectiveServingGrams == 40)
        #expect(draft.storedServingGrams == 40)
    }

    // MARK: - Per-serving to per-100g

    @Test("Values typed per serving are scaled to per 100g")
    func perServingScalesToPer100g() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "152"
        draft.proteinPerServing = "5.2"
        draft.servingSizeGrams = "40"

        // 152 kcal in 40 g is 380 kcal in 100 g.
        #expect(abs(draft.nutritionPer100g.calories - 380) < 0.001)
        #expect(abs((draft.proteinPer100g ?? 0) - 13) < 0.001)
    }

    @Test("A 100g serving passes the typed numbers through unchanged")
    func hundredGramServingIsIdentity() {
        var draft = CustomFoodDraft()
        draft.caloriesPerServing = "380"
        draft.servingSizeGrams = "100"

        #expect(abs(draft.nutritionPer100g.calories - 380) < 0.001)
    }

    @Test("A macro left blank stays unstated rather than becoming zero")
    func blankMacrosStayUnstated() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        #expect(draft.suppliedProtein == nil)
        #expect(draft.proteinPer100g == nil)
        // The nutrition figure still needs a number, so it reads as zero there.
        #expect(draft.nutritionPerServing.proteinG == 0)
    }

    @Test("A macro typed as zero is a stated zero, not an absence")
    func zeroMacroIsStated() {
        var draft = CustomFoodDraft()
        draft.proteinPerServing = "0"

        #expect(draft.suppliedProtein == 0)
        #expect(draft.proteinPer100g == 0)
    }

    @Test("Milligram nutrients are stored in grams")
    func milligramNutrientsConvert() {
        var draft = CustomFoodDraft()
        draft.sodiumPerServing = "500"
        draft.servingSizeGrams = "100"

        // 500 mg is 0.5 g.
        #expect(abs((draft.nutritionPerServing.sodiumG ?? 0) - 0.5) < 0.001)
    }

    // MARK: - Provenance

    @Test("For a new food, every field with content counts as user-supplied")
    func newFoodReportsFilledFields() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        let edited = draft.userEditedRecoveryFields(isEditingExistingFood: false)

        #expect(edited.contains(.name))
        #expect(edited.contains(.calories))
        #expect(!edited.contains(.protein))
        #expect(!edited.contains(.produceKind))
    }

    @Test("Classifying produce on a new food counts as a supplied field")
    func produceKindCountsWhenSet() {
        var draft = CustomFoodDraft()
        draft.name = "Apple"
        draft.produceKind = .fruit

        #expect(draft.userEditedRecoveryFields(isEditingExistingFood: false).contains(.produceKind))
    }

    @Test("Opening an existing food and saving it untouched claims nothing as the user's")
    func untouchedEditClaimsNothing() {
        let food = makeTestFoodItem(name: "Rolled Oats", caloriesPer100g: 380, defaultServingG: 40)
        var draft = CustomFoodDraft()
        draft.populate(from: food)

        #expect(draft.userEditedRecoveryFields(isEditingExistingFood: true).isEmpty)
    }

    @Test("Editing one field on an existing food claims only that field")
    func editedFieldIsClaimed() {
        let food = makeTestFoodItem(name: "Rolled Oats", caloriesPer100g: 380, defaultServingG: 40)
        var draft = CustomFoodDraft()
        draft.populate(from: food)
        draft.name = "Steel Cut Oats"

        let edited = draft.userEditedRecoveryFields(isEditingExistingFood: true)

        #expect(edited == [.name])
    }

    @Test("Changing the produce classification on an existing food is claimed")
    func editedProduceKindIsClaimed() {
        let food = makeTestFoodItem(name: "Apple", caloriesPer100g: 52)
        var draft = CustomFoodDraft()
        draft.populate(from: food)
        draft.produceKind = .fruit

        #expect(draft.userEditedRecoveryFields(isEditingExistingFood: true).contains(.produceKind))
    }

    // MARK: - Loading an existing food

    @Test("Loading a food shows its nutrition for the serving it is stored against")
    func populateShowsPerServingValues() {
        let food = makeTestFoodItem(
            name: "Rolled Oats",
            caloriesPer100g: 380,
            proteinPer100g: 13,
            defaultServingG: 40
        )
        var draft = CustomFoodDraft()
        draft.populate(from: food)

        #expect(draft.name == "Rolled Oats")
        #expect(draft.servingSizeGrams == "40")
        // 380 kcal per 100 g is 152 per 40 g.
        #expect(draft.caloriesPerServing == "152")
        #expect(draft.proteinPerServing == "5.2")
    }

    @Test("Loading then saving a food unchanged preserves its nutrition")
    func populateRoundTripsNutrition() {
        let food = makeTestFoodItem(
            name: "Rolled Oats",
            caloriesPer100g: 380,
            proteinPer100g: 13,
            carbsPer100g: 67,
            fatPer100g: 7,
            defaultServingG: 40
        )
        var draft = CustomFoodDraft()
        draft.populate(from: food)

        let round = draft.nutritionPer100g

        #expect(abs(round.calories - 380) < 1)
        #expect(abs(round.proteinG - 13) < 0.5)
        #expect(abs(round.carbsG - 67) < 0.5)
        #expect(abs(round.fatG - 7) < 0.5)
    }

    // MARK: - Brand

    @Test("A blank brand is stored as no brand rather than an empty string")
    func blankBrandIsNil() {
        var draft = CustomFoodDraft()
        #expect(draft.trimmedBrand == nil)

        draft.brand = " Quaker "
        #expect(draft.trimmedBrand == "Quaker")
    }

    // MARK: - Writing values back into the form

    @Test("A nutrient the food does not record is shown blank")
    func absentNutrientShowsBlank() {
        #expect(CustomFoodDraft.optionalPerServingText(nil, serving: 40) == "")
    }

    @Test("A gram nutrient is scaled to the serving")
    func gramNutrientScalesToServing() {
        // 10 g per 100 g is 4 g in a 40 g serving.
        #expect(CustomFoodDraft.optionalPerServingText(10, serving: 40) == "4")
    }

    @Test("A milligram nutrient is shown in milligrams")
    func milligramNutrientShowsAsMilligrams() {
        // 0.5 g of sodium per 100 g is 0.2 g in a 40 g serving, shown as 200 mg.
        #expect(
            CustomFoodDraft.optionalPerServingText(0.5, serving: 40, unit: .milligramsFromGrams)
                == "200"
        )
    }

    @Test("A value written out and typed back in survives the round trip")
    func perServingTextRoundTrips() {
        let text = CustomFoodDraft.optionalPerServingText(13, serving: 40)

        #expect(CustomFoodDraft.parseDecimal(text) == 5.2)
    }

    @Test("A macro the provider never stated is shown blank, not as zero")
    func missingCoreMacroShowsBlank() {
        #expect(CustomFoodDraft.editableCoreText(0, origin: .missing) == "")
        #expect(CustomFoodDraft.editableCoreText(0, origin: .user) == "0")
        #expect(CustomFoodDraft.editableCoreText(13, origin: .provider) == "13")
    }

    // MARK: - The barcode recovery payload

    @Test("A new food's recovery payload carries the typed values scaled to per 100g")
    func personalEditCarriesScaledValues() {
        var draft = CustomFoodDraft()
        draft.name = "  Rolled Oats  "
        draft.brand = "Quaker"
        draft.caloriesPerServing = "152"
        draft.proteinPerServing = "5.2"
        draft.sodiumPerServing = "200"
        draft.servingSizeGrams = "40"

        let edit = draft.personalEdit(isEditingExistingFood: false)

        #expect(edit.name == "Rolled Oats")
        #expect(edit.brand == "Quaker")
        #expect(abs(edit.caloriesPer100g - 380) < 0.001)
        #expect(abs((edit.proteinPer100g ?? 0) - 13) < 0.001)
        #expect(edit.defaultServingG == 40)
        // 200 mg in 40 g is 0.5 g per 100 g.
        #expect(abs((edit.sodiumPer100g ?? 0) - 0.5) < 0.001)
    }

    @Test("A macro left blank stays absent in the recovery payload")
    func personalEditPreservesAbsentMacros() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        let edit = draft.personalEdit(isEditingExistingFood: false)

        #expect(edit.proteinPer100g == nil)
        #expect(edit.carbohydratesPer100g == nil)
        #expect(edit.fatPer100g == nil)
        #expect(edit.fiberPer100g == nil)
    }

    @Test("An unusable serving is not stored, even though the maths still uses 100g")
    func personalEditOmitsAnUnusableServing() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"
        draft.servingSizeGrams = "0"

        let edit = draft.personalEdit(isEditingExistingFood: false)

        #expect(edit.defaultServingG == nil)
        #expect(abs(edit.caloriesPer100g - 380) < 0.001)
    }

    @Test("The recovery payload claims only the fields the user actually supplied")
    func personalEditClaimsSuppliedFieldsOnly() {
        var draft = CustomFoodDraft()
        draft.name = "Rolled Oats"
        draft.caloriesPerServing = "380"

        let claimed = draft.personalEdit(isEditingExistingFood: false).userEditedFields ?? []

        #expect(claimed.contains(.name))
        #expect(claimed.contains(.calories))
        #expect(!claimed.contains(.protein))
    }

    // MARK: - Input formatting

    @Test(
        "Values are written back without a pointless trailing zero",
        arguments: [(40.0, "40"), (5.25, "5.3"), (0.0, "0"), (12.5, "12.5")]
    )
    func manualInputFormatting(value: Double, expected: String) {
        #expect(value.manualInputFormatted == expected)
    }
}
