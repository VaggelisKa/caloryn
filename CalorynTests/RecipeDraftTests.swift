import Foundation
import Testing
@testable import Caloryn

@Suite("Recipe draft")
struct RecipeDraftTests {
    private func ingredient(
        _ name: String = "Tomato",
        grams: Double,
        sortOrder: Int = 0,
        id: UUID = UUID()
    ) -> RecipeIngredientDraft {
        RecipeIngredientDraft(
            id: id,
            name: name,
            brand: nil,
            portionGrams: grams,
            caloriesPer100g: 50,
            proteinPer100g: 5,
            carbsPer100g: 10,
            fatPer100g: 2,
            fiberPer100g: 1,
            sortOrder: sortOrder
        )
    }

    private func draftWith(name: String, ingredients: [RecipeIngredientDraft]) -> RecipeDraft {
        var draft = RecipeDraft()
        _ = draft.seed(name: name, ingredients: ingredients)
        return draft
    }

    @Test("An empty form cannot be saved")
    func emptyFormCannotBeSaved() {
        #expect(RecipeDraft().canSave == false)
    }

    @Test("A recipe with ingredients but no name cannot be saved")
    func unnamedRecipeCannotBeSaved() {
        #expect(draftWith(name: "", ingredients: [ingredient(grams: 200)]).canSave == false)
    }

    @Test("A name of only spaces does not count as a name")
    func whitespaceNameCannotBeSaved() {
        #expect(draftWith(name: "   ", ingredients: [ingredient(grams: 200)]).canSave == false)
    }

    @Test("A named recipe with no ingredients cannot be saved")
    func namedRecipeWithoutIngredientsCannotBeSaved() {
        #expect(draftWith(name: "Greek Salad", ingredients: []).canSave == false)
    }

    @Test("A recipe whose ingredients all weigh nothing cannot be saved")
    func weightlessRecipeCannotBeSaved() {
        let draft = draftWith(name: "Air", ingredients: [ingredient(grams: 0), ingredient(grams: 0)])

        #expect(draft.totalGrams == 0)
        #expect(draft.canSave == false)
    }

    @Test("A named recipe with a weighed ingredient can be saved")
    func namedWeighedRecipeCanBeSaved() {
        #expect(draftWith(name: "Greek Salad", ingredients: [ingredient(grams: 200)]).canSave)
    }

    @Test("The saved name is trimmed")
    func savedNameIsTrimmed() {
        #expect(draftWith(name: "  Greek Salad  ", ingredients: []).trimmedName == "Greek Salad")
    }

    @Test("Totals are the sum of each ingredient's share of its per-100g values")
    func totalsSumIngredientPortions() {
        let draft = draftWith(
            name: "Salad",
            ingredients: [
                ingredient("Tomato", grams: 200, sortOrder: 0),
                ingredient("Cucumber", grams: 50, sortOrder: 1)
            ]
        )

        #expect(draft.totalGrams == 250)
        #expect(abs(draft.totalCalories - 125) < 0.0001)
        #expect(abs(draft.totalProtein - 12.5) < 0.0001)
        #expect(abs(draft.totalCarbs - 25) < 0.0001)
        #expect(abs(draft.totalFat - 5) < 0.0001)
        #expect(abs(draft.totalFiber - 2.5) < 0.0001)
    }

    @Test("An empty recipe totals zero")
    func emptyRecipeTotalsZero() {
        let draft = RecipeDraft()

        #expect(draft.totalGrams == 0)
        #expect(draft.totalCalories == 0)
        #expect(draft.totalFiber == 0)
    }

    @Test("The calorie caption omits the yield until there is one")
    func captionOmitsYieldWhenEmpty() {
        #expect(RecipeDraft().totalCaloriesCaption == "calories")
    }

    @Test("The calorie caption states the recipe's yield in whole grams")
    func captionStatesYield() {
        let draft = draftWith(name: "Salad", ingredients: [ingredient(grams: 249.6)])

        #expect(draft.totalCaloriesCaption == "calories in 250 g")
    }

    @Test("A sub-gram recipe is savable and states its real yield")
    func subGramRecipeStatesItsYield() {
        let draft = draftWith(name: "Pinch of salt", ingredients: [ingredient(grams: 0.4)])

        #expect(draft.canSave)
        #expect(draft.totalCaloriesCaption(locale: Locale(identifier: "en_US")) == "calories in 0.4 g")
    }

    @Test("A yield too small for one decimal is stated as under a tenth of a gram")
    func vanishinglySmallYieldIsStatedAsUnderATenth() {
        let draft = draftWith(name: "Dusting", ingredients: [ingredient(grams: 0.004)])

        #expect(draft.canSave)
        #expect(draft.totalCaloriesCaption(locale: Locale(identifier: "en_US")) == "calories in <0.1 g")
    }

    @Test("A yield of half a gram or more rounds up to whole grams")
    func halfAGramRoundsUpToWholeGrams() {
        let draft = draftWith(name: "Salt", ingredients: [ingredient(grams: 0.6)])

        #expect(draft.totalCaloriesCaption == "calories in 1 g")
    }

    @Test("An unconvertible yield is captioned rather than trapped on")
    func unconvertibleYieldIsCaptioned() {
        let draft = draftWith(name: "Overflow", ingredients: [ingredient(grams: 1e300)])
        let caption = draft.totalCaloriesCaption(locale: Locale(identifier: "en_US"))

        #expect(caption.hasPrefix("calories in 1,000,000,000,"))
        #expect(caption.hasSuffix(",000 g"))
    }

    @Test("A new ingredient is appended at the end")
    func newIngredientIsAppended() {
        var draft = RecipeDraft()
        draft.upsert(ingredient("Tomato", grams: 100))
        draft.upsert(ingredient("Feta", grams: 50))

        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Feta"])
        #expect(draft.sortedIngredients.map(\.sortOrder) == [0, 1])
    }

    @Test("Saving an amount for an ingredient already in the recipe replaces it in place")
    func upsertReplacesInPlace() {
        let tomatoID = UUID()
        var draft = RecipeDraft()
        draft.upsert(ingredient("Tomato", grams: 100, id: tomatoID))
        draft.upsert(ingredient("Feta", grams: 50))
        draft.upsert(ingredient("Tomato", grams: 300, id: tomatoID))

        #expect(draft.ingredients.count == 2)
        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Feta"])
        #expect(draft.totalGrams == 350)
    }

    @Test("An appended ingredient takes the next position regardless of the order it carries")
    func appendIgnoresIncomingSortOrder() {
        var draft = RecipeDraft()
        draft.upsert(ingredient("Tomato", grams: 100, sortOrder: 7))
        draft.upsert(ingredient("Feta", grams: 50, sortOrder: 99))

        #expect(draft.sortedIngredients.map(\.sortOrder) == [0, 1])
        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Feta"])
    }

    @Test("Deleting from the middle renumbers the rest without a gap")
    func deletionRenumbers() {
        var draft = RecipeDraft()
        let feta = ingredient("Feta", grams: 50)
        draft.upsert(ingredient("Tomato", grams: 100))
        draft.upsert(feta)
        draft.upsert(ingredient("Olive", grams: 20))

        draft.remove(feta)

        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Olive"])
        #expect(draft.sortedIngredients.map(\.sortOrder) == [0, 1])
    }

    @Test("Deleting the last ingredient leaves a recipe that cannot be saved")
    func deletingLastIngredientBlocksSaving() {
        var draft = RecipeDraft()
        draft.name = "Greek Salad"
        let tomato = ingredient("Tomato", grams: 100)
        draft.upsert(tomato)
        draft.remove(tomato)

        #expect(draft.ingredients.isEmpty)
        #expect(draft.canSave == false)
    }

    @Test("Deleting an ingredient that is not in the recipe changes nothing")
    func deletingUnknownIngredientIsANoop() {
        var draft = RecipeDraft()
        draft.upsert(ingredient("Tomato", grams: 100))
        draft.remove(ingredient("Feta", grams: 50))

        #expect(draft.sortedIngredients.map(\.name) == ["Tomato"])
    }

    @Test("Ingredients are handed over for saving renumbered from zero")
    func ingredientsForSavingAreRenumbered() {
        let draft = draftWith(
            name: "Salad",
            ingredients: [
                ingredient("Olive", grams: 20, sortOrder: 9),
                ingredient("Tomato", grams: 100, sortOrder: 5)
            ]
        )

        #expect(draft.ingredientsForSaving.map(\.name) == ["Tomato", "Olive"])
        #expect(draft.ingredientsForSaving.map(\.sortOrder) == [0, 1])
    }

    @Test("A new recipe starts empty and asks for the name field")
    func newRecipeStartsEmpty() {
        var draft = RecipeDraft()

        #expect(draft.seed(name: nil, ingredients: []) == .startedEmpty)
        #expect(draft.name.isEmpty)
        #expect(draft.ingredients.isEmpty)
    }

    @Test("Seeding from a saved recipe restores its name and ingredients in saved order")
    func seedingRestoresSavedRecipe() {
        var draft = RecipeDraft()
        let outcome = draft.seed(
            name: "Greek Salad",
            ingredients: [
                ingredient("Olive", grams: 20, sortOrder: 2),
                ingredient("Tomato", grams: 100, sortOrder: 0),
                ingredient("Feta", grams: 50, sortOrder: 1)
            ]
        )

        #expect(outcome == .populated)
        #expect(draft.name == "Greek Salad")
        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Feta", "Olive"])
    }

    @Test("Seeding a second time leaves the edited recipe alone")
    func secondSeedIsIgnored() {
        var draft = RecipeDraft()
        _ = draft.seed(name: "Greek Salad", ingredients: [ingredient("Tomato", grams: 100)])
        draft.name = "Village Salad"

        let outcome = draft.seed(name: "Greek Salad", ingredients: [ingredient("Feta", grams: 50)])

        #expect(outcome == .alreadySeeded)
        #expect(draft.name == "Village Salad")
        #expect(draft.sortedIngredients.map(\.name) == ["Tomato"])
    }

    @Test("A form that already holds ingredients is not treated as a fresh start")
    func populatedFormIsNotAFreshStart() {
        var draft = RecipeDraft()
        draft.upsert(ingredient("Tomato", grams: 100))

        #expect(draft.seed(name: nil, ingredients: []) == .alreadySeeded)
    }

    @MainActor
    @Test("Seeding from a stored recipe reads its ingredients back as drafts")
    func seedingFromStoredRecipe() {
        let recipe = makeTestFoodItem(name: "Greek Salad", isRecipe: true)
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Feta",
                portionGrams: 50,
                caloriesPer100g: 264,
                proteinPer100g: 14,
                carbsPer100g: 4,
                fatPer100g: 21,
                sortOrder: 1
            ),
            RecipeIngredient(
                name: "Tomato",
                portionGrams: 200,
                caloriesPer100g: 18,
                proteinPer100g: 0.9,
                carbsPer100g: 3.9,
                fatPer100g: 0.2,
                sortOrder: 0
            )
        ]

        var draft = RecipeDraft()
        let outcome = draft.seed(from: recipe)

        #expect(outcome == .populated)
        #expect(draft.name == "Greek Salad")
        #expect(draft.sortedIngredients.map(\.name) == ["Tomato", "Feta"])
        #expect(draft.totalGrams == 250)
        #expect(draft.canSave)
    }

    @MainActor
    @Test("Seeding without a recipe starts empty")
    func seedingWithoutARecipeStartsEmpty() {
        var draft = RecipeDraft()

        #expect(draft.seed(from: nil) == .startedEmpty)
    }
}
