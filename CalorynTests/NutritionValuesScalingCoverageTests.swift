import Foundation
import Testing
@testable import Caloryn

/// Every field set to a different whole number, 1 to 30 in declaration order, so a value
/// copied into the wrong field shows up as the wrong number. `scale` multiplies them all.
private func distinctNutrition(scale: Double = 1) -> NutritionValues {
    NutritionValues(
        calories: 1 * scale,
        proteinG: 2 * scale,
        carbsG: 3 * scale,
        fatG: 4 * scale,
        fiberG: 5 * scale,
        sugarsG: 6 * scale,
        addedSugarsG: 7 * scale,
        sucroseG: 8 * scale,
        glucoseG: 9 * scale,
        fructoseG: 10 * scale,
        lactoseG: 11 * scale,
        maltoseG: 12 * scale,
        maltodextrinsG: 13 * scale,
        starchG: 14 * scale,
        polyolsG: 15 * scale,
        saturatedFatG: 16 * scale,
        transFatG: 17 * scale,
        monounsaturatedFatG: 18 * scale,
        polyunsaturatedFatG: 19 * scale,
        omega3FatG: 20 * scale,
        omega6FatG: 21 * scale,
        omega9FatG: 22 * scale,
        saltG: 23 * scale,
        sodiumG: 24 * scale,
        cholesterolG: 25 * scale,
        solubleFiberG: 26 * scale,
        insolubleFiberG: 27 * scale,
        caseinG: 28 * scale,
        serumProteinsG: 29 * scale,
        alcoholG: 30 * scale
    )
}

@MainActor
private func distinctFood(defaultServingG: Double? = nil) -> FoodItem {
    let food = makeTestFoodItem(defaultServingG: defaultServingG)
    food.nutritionPer100g = distinctNutrition()
    return food
}

@Suite("Nutrition values scaling")
struct NutritionValuesScalingCoverageTests {

    // MARK: - Reading one nutrient

    @Test(
        "Each tracked nutrient reads its own field",
        arguments: [
            (TrackedNutrient.protein, 2.0),
            (.carbs, 3.0),
            (.fat, 4.0),
            (.fiber, 5.0),
            (.sugars, 6.0),
            (.addedSugars, 7.0),
            (.saturatedFat, 16.0),
            (.sodium, 24.0),
            (.cholesterol, 25.0),
            (.alcohol, 30.0),
        ]
    )
    func valueForNutrient(nutrient: TrackedNutrient, expected: Double) {
        #expect(distinctNutrition().value(for: nutrient) == expected)
    }

    @Test("An unreported optional nutrient reads as zero", arguments: TrackedNutrient.allCases)
    func unreportedReadsAsZero(nutrient: TrackedNutrient) {
        #expect(NutritionValues(calories: 250).value(for: nutrient) == 0)
    }

    // MARK: - Scaling

    @Test("Scaling multiplies every field by the same factor")
    func scalingReachesEveryField() {
        // Each i × 2.5 is exact in binary, so the comparison can be exact.
        #expect(distinctNutrition().scaled(by: 2.5) == distinctNutrition(scale: 2.5))
    }

    @Test("Scaling by zero zeroes reported nutrients but leaves unreported ones unreported")
    func scalingByZero() {
        let scaled = NutritionValues(calories: 200, proteinG: 10, sugarsG: 4, sodiumG: nil).scaled(by: 0)

        #expect(scaled.calories == 0)
        #expect(scaled.proteinG == 0)
        #expect(scaled.sugarsG == 0)
        #expect(scaled.sodiumG == nil)
    }

    @Test("A negative factor is applied as given")
    func scalingByANegativeFactor() {
        let scaled = NutritionValues(calories: 200, fatG: 6, alcoholG: 2).scaled(by: -0.5)

        #expect(scaled.calories == -100)
        #expect(scaled.fatG == -3)
        #expect(scaled.alcoholG == -1)
    }

    // MARK: - Adding

    @Test("Adding sums every field")
    func additionReachesEveryField() {
        // i + 100 i = 101 i
        #expect(distinctNutrition() + distinctNutrition(scale: 100) == distinctNutrition(scale: 101))
    }

    @Test("A nutrient reported on one side only is kept; one reported on neither stays unreported")
    func additionOfPartlyReportedValues() {
        let sum = NutritionValues(calories: 120, sugarsG: 4.5, sodiumG: nil)
            + NutritionValues(calories: 80, sugarsG: nil, sodiumG: 0.25)

        #expect(sum.calories == 200)
        #expect(sum.sugarsG == 4.5)
        #expect(sum.sodiumG == 0.25)
        #expect(sum.cholesterolG == nil)
    }

    @Test("Zero is the identity for adding")
    func zeroIsTheIdentity() {
        #expect(distinctNutrition() + .zero == distinctNutrition())
        #expect(NutritionValues.zero + .zero == .zero)
    }

    // MARK: - Per 100 g

    @Test("A 30 g serving's values become per-100 g values")
    func per100gFromAServing() {
        let per100g = NutritionValues.per100g(
            fromServing: NutritionValues(calories: 120, proteinG: 6, sugarsG: 4.5),
            servingGrams: 30
        )

        // × 100 / 30
        #expect(abs(per100g.calories - 400) < 1e-9)
        #expect(abs(per100g.proteinG - 20) < 1e-9)
        #expect(abs((per100g.sugarsG ?? -1) - 15) < 1e-9)
        #expect(per100g.sodiumG == nil)
    }

    @Test("A serving with no usable weight converts to nothing", arguments: [0.0, -50.0, .nan])
    func per100gFromAWeightlessServing(grams: Double) {
        #expect(NutritionValues.per100g(fromServing: distinctNutrition(), servingGrams: grams) == .zero)
    }

    @Test("Portions with no usable total weight, or no portions, convert to nothing")
    func per100gFromNoUsablePortions() {
        #expect(NutritionValues.per100g(fromPortions: [distinctNutrition()], totalGrams: 0) == .zero)
        #expect(NutritionValues.per100g(fromPortions: [distinctNutrition()], totalGrams: -10) == .zero)
        #expect(NutritionValues.per100g(fromPortions: [], totalGrams: 250) == .zero)
    }

    @Test("Portions are summed before being brought to 100 g")
    func per100gFromPortions() {
        // (i + 100 i) × 100 / 202 = 50 i
        let per100g = NutritionValues.per100g(
            fromPortions: [distinctNutrition(), distinctNutrition(scale: 100)],
            totalGrams: 202
        )

        #expect(abs(per100g.calories - 50) < 1e-9)
        #expect(abs((per100g.alcoholG ?? -1) - 1_500) < 1e-9)
    }

    // MARK: - A food, a log entry and an ingredient

    @MainActor
    @Test("A food's per-100 g values land in the matching stored field and read back unchanged")
    func foodStoresEveryField() {
        let food = distinctFood()

        #expect(food.nutritionPer100g == distinctNutrition())
        let stored: [(String, Double?)] = [
            ("calories", food.caloriesPer100g), ("protein", food.proteinPer100g),
            ("carbs", food.carbsPer100g), ("fat", food.fatPer100g), ("fiber", food.fiberPer100g),
            ("sugars", food.sugarsPer100g), ("addedSugars", food.addedSugarsPer100g),
            ("sucrose", food.sucrosePer100g), ("glucose", food.glucosePer100g),
            ("fructose", food.fructosePer100g), ("lactose", food.lactosePer100g),
            ("maltose", food.maltosePer100g), ("maltodextrins", food.maltodextrinsPer100g),
            ("starch", food.starchPer100g), ("polyols", food.polyolsPer100g),
            ("saturatedFat", food.saturatedFatPer100g), ("transFat", food.transFatPer100g),
            ("monounsaturatedFat", food.monounsaturatedFatPer100g),
            ("polyunsaturatedFat", food.polyunsaturatedFatPer100g),
            ("omega3", food.omega3FatPer100g), ("omega6", food.omega6FatPer100g),
            ("omega9", food.omega9FatPer100g), ("salt", food.saltPer100g),
            ("sodium", food.sodiumPer100g), ("cholesterol", food.cholesterolPer100g),
            ("solubleFiber", food.solubleFiberPer100g), ("insolubleFiber", food.insolubleFiberPer100g),
            ("casein", food.caseinPer100g), ("serumProteins", food.serumProteinsPer100g),
            ("alcohol", food.alcoholPer100g),
        ]
        for (index, field) in stored.enumerated() {
            #expect(field.1 == Double(index + 1), "\(field.0)")
        }
    }

    @MainActor
    @Test("A food's nutrition for a portion is its per-100 g values times grams over 100")
    func foodNutritionForAPortion() {
        let apple = makeTestFoodItem(
            caloriesPer100g: 52,
            proteinPer100g: 0.3,
            carbsPer100g: 14,
            fatPer100g: 0.2,
            fiberPer100g: 2.4,
            sugarsPer100g: 10.4
        )

        let portion = apple.nutrition(forGrams: 250)

        // × 2.5
        #expect(abs(portion.calories - 130) < 1e-9)
        #expect(abs(portion.proteinG - 0.75) < 1e-9)
        #expect(abs(portion.carbsG - 35) < 1e-9)
        #expect(abs(portion.fatG - 0.5) < 1e-9)
        #expect(abs(portion.fiberG - 6) < 1e-9)
        #expect(abs((portion.sugarsG ?? -1) - 26) < 1e-9)
        #expect(portion.sodiumG == nil)

        let none = apple.nutrition(forGrams: 0)
        #expect(none.calories == 0)
        #expect(none.sugarsG == 0)
        #expect(none.sodiumG == nil)
    }

    @MainActor
    @Test("A log entry records every field of its food, scaled to the portion")
    func logEntryRecordsEveryField() {
        let entry = makeTestEntry(foodItem: distinctFood(), portionGrams: 250)

        #expect(entry.nutrition == distinctNutrition(scale: 2.5))
    }

    @MainActor
    @Test("A recipe ingredient carries its food's per-100 g values and scales them to its grams")
    func recipeIngredientScalesEveryField() {
        let food = distinctFood()
        let ingredient = RecipeIngredient(from: food, portionGrams: 250, sortOrder: 0)

        #expect(ingredient.nutritionPer100g == distinctNutrition())
        #expect(ingredient.nutrition == distinctNutrition(scale: 2.5))
    }

    @MainActor
    @Test("A draft ingredient opens on its food's default serving, or 100 g without one")
    func draftIngredientScalesEveryField() {
        let withServing = RecipeIngredientDraft(from: distinctFood(defaultServingG: 50), sortOrder: 0)
        let withoutServing = RecipeIngredientDraft(from: distinctFood(), sortOrder: 1)

        #expect(withServing.nutritionPer100g == distinctNutrition())
        #expect(withServing.nutrition == distinctNutrition(scale: 0.5))
        #expect(withoutServing.nutrition == distinctNutrition())
    }
}
