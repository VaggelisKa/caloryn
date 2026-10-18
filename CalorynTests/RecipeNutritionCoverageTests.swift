import Foundation
import Testing
@testable import Caloryn

/// Recipe maths from the ingredient grams up: each ingredient's share of its
/// per-100g values, the recipe's derived per-100g nutrition, what a logged
/// portion of the recipe carries, and what the library row says about it.
/// Every expectation below is worked out by hand from the inputs.
@MainActor
@Suite("Recipe nutrition coverage")
struct RecipeNutritionCoverageTests {

    // MARK: - Ingredient optional nutrients

    /// Distinct per-100g values (1...25) so a getter wired to the wrong field
    /// reads the wrong number rather than an equal one.
    private static let optionalPer100g: [Double] = (1...25).map(Double.init)

    @Test("Every optional nutrient of a saved ingredient is its per-100g value scaled to the ingredient's grams")
    func savedIngredientScalesEveryOptionalNutrient() {
        let v = Self.optionalPer100g
        let ingredient = RecipeIngredient(
            name: "Everything",
            portionGrams: 50,
            caloriesPer100g: 200,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 8,
            fiberPer100g: 4,
            sugarsPer100g: v[0],
            addedSugarsPer100g: v[1],
            sucrosePer100g: v[2],
            glucosePer100g: v[3],
            fructosePer100g: v[4],
            lactosePer100g: v[5],
            maltosePer100g: v[6],
            maltodextrinsPer100g: v[7],
            starchPer100g: v[8],
            polyolsPer100g: v[9],
            saturatedFatPer100g: v[10],
            transFatPer100g: v[11],
            monounsaturatedFatPer100g: v[12],
            polyunsaturatedFatPer100g: v[13],
            omega3FatPer100g: v[14],
            omega6FatPer100g: v[15],
            omega9FatPer100g: v[16],
            saltPer100g: v[17],
            sodiumPer100g: v[18],
            cholesterolPer100g: v[19],
            solubleFiberPer100g: v[20],
            insolubleFiberPer100g: v[21],
            caseinPer100g: v[22],
            serumProteinsPer100g: v[23],
            alcoholPer100g: v[24],
            sortOrder: 0
        )

        let actual: [Double?] = [
            ingredient.sugarsG, ingredient.addedSugarsG, ingredient.sucroseG,
            ingredient.glucoseG, ingredient.fructoseG, ingredient.lactoseG,
            ingredient.maltoseG, ingredient.maltodextrinsG, ingredient.starchG,
            ingredient.polyolsG, ingredient.saturatedFatG, ingredient.transFatG,
            ingredient.monounsaturatedFatG, ingredient.polyunsaturatedFatG,
            ingredient.omega3FatG, ingredient.omega6FatG, ingredient.omega9FatG,
            ingredient.saltG, ingredient.sodiumG, ingredient.cholesterolG,
            ingredient.solubleFiberG, ingredient.insolubleFiberG, ingredient.caseinG,
            ingredient.serumProteinsG, ingredient.alcoholG,
        ]

        // 50 g is half of 100 g, so each figure is exactly half its per-100g value.
        #expect(actual == v.map { Optional($0 / 2) })
        #expect(ingredient.calories == 100)
        #expect(ingredient.proteinG == 5)
        #expect(ingredient.carbsG == 10)
        #expect(ingredient.fatG == 4)
        #expect(ingredient.fiberG == 2)
    }

    @Test("Every optional nutrient of an ingredient being edited is its per-100g value scaled to its grams")
    func draftIngredientScalesEveryOptionalNutrient() {
        let v = Self.optionalPer100g
        let draft = RecipeIngredientDraft(
            name: "Everything",
            brand: nil,
            portionGrams: 250,
            caloriesPer100g: 200,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 8,
            fiberPer100g: 4,
            sugarsPer100g: v[0],
            addedSugarsPer100g: v[1],
            sucrosePer100g: v[2],
            glucosePer100g: v[3],
            fructosePer100g: v[4],
            lactosePer100g: v[5],
            maltosePer100g: v[6],
            maltodextrinsPer100g: v[7],
            starchPer100g: v[8],
            polyolsPer100g: v[9],
            saturatedFatPer100g: v[10],
            transFatPer100g: v[11],
            monounsaturatedFatPer100g: v[12],
            polyunsaturatedFatPer100g: v[13],
            omega3FatPer100g: v[14],
            omega6FatPer100g: v[15],
            omega9FatPer100g: v[16],
            saltPer100g: v[17],
            sodiumPer100g: v[18],
            cholesterolPer100g: v[19],
            solubleFiberPer100g: v[20],
            insolubleFiberPer100g: v[21],
            caseinPer100g: v[22],
            serumProteinsPer100g: v[23],
            alcoholPer100g: v[24],
            sortOrder: 0
        )

        let actual: [Double?] = [
            draft.sugarsG, draft.addedSugarsG, draft.sucroseG,
            draft.glucoseG, draft.fructoseG, draft.lactoseG,
            draft.maltoseG, draft.maltodextrinsG, draft.starchG,
            draft.polyolsG, draft.saturatedFatG, draft.transFatG,
            draft.monounsaturatedFatG, draft.polyunsaturatedFatG,
            draft.omega3FatG, draft.omega6FatG, draft.omega9FatG,
            draft.saltG, draft.sodiumG, draft.cholesterolG,
            draft.solubleFiberG, draft.insolubleFiberG, draft.caseinG,
            draft.serumProteinsG, draft.alcoholG,
        ]

        // 250 g is two and a half 100 g portions.
        #expect(actual == v.map { Optional($0 * 2.5) })
        #expect(draft.calories == 500)
        #expect(draft.proteinG == 25)
        #expect(draft.carbsG == 50)
        #expect(draft.fatG == 20)
        #expect(draft.fiberG == 10)
    }

    @Test("A draft ingredient with no optional nutrients reports none of them rather than zero")
    func draftWithoutOptionalNutrientsReportsNil() {
        let draft = RecipeIngredientDraft(
            name: "Water",
            brand: nil,
            portionGrams: 300,
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            sortOrder: 0
        )

        #expect(draft.sugarsG == nil)
        #expect(draft.sodiumG == nil)
        #expect(draft.alcoholG == nil)
        #expect(draft.calories == 0)
    }

    @Test("Reclassifying an ingredient's produce kind is kept, and an unknown stored kind reads as unclassified")
    func ingredientProduceKindRoundTrips() {
        let ingredient = RecipeIngredient(
            name: "Apple",
            portionGrams: 120,
            caloriesPer100g: 52,
            proteinPer100g: 0.3,
            carbsPer100g: 14,
            fatPer100g: 0.2,
            sortOrder: 0
        )
        #expect(ingredient.produceKind == .unclassified)

        ingredient.produceKind = .fruit
        #expect(ingredient.produceKind == .fruit)
        #expect(ingredient.produceKindRaw == "fruit")

        ingredient.produceKindRaw = "mineral"
        #expect(ingredient.produceKind == .unclassified)
    }

    // MARK: - Recipe per 100 g from ingredient grams

    /// Rice 200 g @130 kcal, chicken 150 g @165 kcal, oil 10 g @884 kcal and a
    /// 0 g garnish. Stored out of order to prove the snapshot re-sorts.
    private func makeStirFry() -> FoodItem {
        let recipe = makeTestFoodItem(
            name: "Stir fry",
            caloriesPer100g: 0,
            proteinPer100g: 0,
            carbsPer100g: 0,
            fatPer100g: 0,
            isRecipe: true
        )
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Rice", portionGrams: 200, caloriesPer100g: 130,
                proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3,
                sortOrder: 2
            ),
            RecipeIngredient(
                name: "Chicken", portionGrams: 150, caloriesPer100g: 165,
                proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6,
                sortOrder: 0
            ),
            RecipeIngredient(
                name: "Pepper", portionGrams: 0, caloriesPer100g: 20,
                proteinPer100g: 1, carbsPer100g: 4, fatPer100g: 0.2,
                sortOrder: 3, produceKind: .vegetable
            ),
            RecipeIngredient(
                name: "Oil", portionGrams: 10, caloriesPer100g: 884,
                proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100,
                sortOrder: 1
            ),
        ]
        recipe.updateRecipeNutritionFromIngredients()
        return recipe
    }

    @Test("A recipe's per-100g nutrition is its ingredient totals divided by its total grams")
    func recipePer100gFromIngredientGrams() {
        let recipe = makeStirFry()

        // 360 g in total. kcal: 260 + 247.5 + 0 + 88.4 = 595.9; protein: 5.4 + 46.5 = 51.9;
        // carbs: 56; fat: 0.6 + 5.4 + 10 = 16. Each divided by 3.6.
        #expect(recipe.defaultServingG == 360)
        #expect(abs(recipe.caloriesPer100g - 595.9 / 3.6) < 1e-9)
        #expect(abs(recipe.proteinPer100g - 51.9 / 3.6) < 1e-9)
        #expect(abs(recipe.carbsPer100g - 56 / 3.6) < 1e-9)
        #expect(abs(recipe.fatPer100g - 16 / 3.6) < 1e-9)
    }

    @Test("Logging half a recipe carries half its ingredient totals, and its weighed produce in saved order")
    func loggedRecipePortionCarriesHalfTheTotals() {
        let recipe = makeStirFry()

        let snapshot = FoodLogEntrySnapshot(foodItem: recipe, portionGrams: 180, mealType: .dinner)

        #expect(abs(snapshot.nutrition.calories - 595.9 / 2) < 1e-9)
        #expect(abs(snapshot.nutrition.proteinG - 51.9 / 2) < 1e-9)
        #expect(abs(snapshot.nutrition.carbsG - 28) < 1e-9)
        #expect(abs(snapshot.nutrition.fatG - 8) < 1e-9)
        // The 0 g pepper is dropped; the rest follow sort order, not storage order.
        #expect(snapshot.produceItemsSnapshot?.map(\.name) == ["Chicken", "Oil", "Rice"])
        #expect(snapshot.produceItemsSnapshot?.map(\.kind) == [.unclassified, .unclassified, .unclassified])
    }

    @Test("A logged recipe portion records each weighed ingredient's produce kind")
    func loggedRecipeRecordsProduceKinds() {
        let recipe = makeTestFoodItem(name: "Fruit salad", isRecipe: true)
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Kiwi", portionGrams: 80, caloriesPer100g: 61,
                proteinPer100g: 1.1, carbsPer100g: 15, fatPer100g: 0.5,
                sortOrder: 1, produceKind: .fruit
            ),
            RecipeIngredient(
                name: "Mint", portionGrams: 5, caloriesPer100g: 44,
                proteinPer100g: 3.3, carbsPer100g: 8, fatPer100g: 0.7,
                sortOrder: 0, produceKind: .vegetable
            ),
        ]
        recipe.updateRecipeNutritionFromIngredients()

        let snapshot = FoodLogEntrySnapshot(foodItem: recipe, portionGrams: 85)

        #expect(snapshot.produceItemsSnapshot?.map(\.name) == ["Mint", "Kiwi"])
        #expect(snapshot.produceItemsSnapshot?.map(\.kind) == [.vegetable, .fruit])
        // 85 g is the whole recipe: 48.8 + 2.2 kcal.
        #expect(abs(snapshot.nutrition.calories - 51) < 1e-9)
    }

    @Test("The recipe form totals the same ingredient grams the saved recipe is derived from")
    func recipeDraftTotalsMatchHandComputedSums() {
        var draft = RecipeDraft()
        draft.name = "Stir fry"
        draft.upsert(RecipeIngredientDraft(
            name: "Rice", brand: nil, portionGrams: 200, caloriesPer100g: 130,
            proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3, fiberPer100g: 0.4,
            sortOrder: 0
        ))
        draft.upsert(RecipeIngredientDraft(
            name: "Chicken", brand: nil, portionGrams: 150, caloriesPer100g: 165,
            proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6,
            sortOrder: 0
        ))
        draft.upsert(RecipeIngredientDraft(
            name: "Oil", brand: nil, portionGrams: 10, caloriesPer100g: 884,
            proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100,
            sortOrder: 0
        ))

        #expect(draft.totalGrams == 360)
        #expect(abs(draft.totalCalories - 595.9) < 1e-9)
        #expect(abs(draft.totalProtein - 51.9) < 1e-9)
        #expect(abs(draft.totalCarbs - 56) < 1e-9)
        #expect(abs(draft.totalFat - 16) < 1e-9)
        #expect(abs(draft.totalFiber - 0.8) < 1e-9)
        #expect(draft.canSave)
    }

    @Test("An empty recipe form's caption names no yield")
    func emptyRecipeCaptionHasNoYield() {
        #expect(RecipeDraft().totalCaloriesCaption == "calories")
    }

    // MARK: - Library rows built from stored foods

    @Test("A stored recipe's library row totals its whole yield from its per-100g values")
    func recipeLibraryRowFromStoredRecipe() {
        let recipe = makeStirFry()

        let summary = RecipeLibraryRowSummary(recipe: recipe)

        #expect(summary.name == "Stir fry")
        #expect(summary.ingredientCount == 4)
        #expect(summary.totalGrams == 360)
        // 595.9 kcal across the whole yield.
        #expect(abs(summary.calories - 595.9) < 1e-9)
        #expect(abs(summary.protein - 51.9) < 1e-9)
        #expect(abs(summary.carbs - 56) < 1e-9)
        #expect(abs(summary.fat - 16) < 1e-9)
        #expect(summary.caloriesText == "596")
        #expect(summary.detail == "4 ingredients, 360 g")
    }

    @Test("A stored recipe with no ingredient list and no serving reads as empty rather than as 0 g")
    func recipeLibraryRowFromEmptyStoredRecipe() {
        let recipe = makeTestFoodItem(name: "Draft", caloriesPer100g: 150, isRecipe: true)
        recipe.recipeIngredients = nil
        recipe.defaultServingG = nil

        let summary = RecipeLibraryRowSummary(recipe: recipe)

        #expect(summary.ingredientCount == 0)
        #expect(summary.calories == 0)
        #expect(summary.detail == "0 ingredients")
        #expect(summary.caloriesText == "0")
    }

    @Test("A stored food's library row prices its own serving")
    func libraryFoodRowFromStoredFoodWithServing() {
        let food = makeTestFoodItem(
            name: "Skyr",
            brand: "Arla",
            caloriesPer100g: 63,
            defaultServingG: 150,
            servingDescription: "1 pot",
            isCustom: true
        )

        let summary = LibraryFoodRowSummary(food: food)

        #expect(summary.name == "Skyr")
        // 63 kcal × 1.5 = 94.5, rounded to the nearest kcal.
        #expect(summary.caloriesText == "95")
        #expect(summary.caloriesCaption == "kcal")
        #expect(summary == LibraryFoodRowSummary(
            name: "Skyr",
            brand: "Arla",
            servingDescription: "1 pot",
            caloriesPer100g: 63,
            servingGrams: 150
        ))
    }


    @Test("A stored food with no serving is priced per 100 g")
    func libraryFoodRowFromStoredFoodWithoutServing() {
        let food = makeTestFoodItem(name: "Oats", caloriesPer100g: 389, isCustom: true)

        let summary = LibraryFoodRowSummary(food: food)

        #expect(summary.caloriesText == "389")
        #expect(summary.caloriesCaption == "kcal per 100 g")
        #expect(summary.detail == nil)
    }
}
