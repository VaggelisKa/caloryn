import Foundation
import Testing
@testable import Caloryn

/// Per-portion nutrition, produce classification, serving units and recipe
/// provenance on `FoodItem`.
///
/// Every expected value is computed by hand: a portion is `per100g × grams / 100`,
/// so a 150 g portion of an integer per-100 g value is exactly that value × 1.5.
@MainActor
struct FoodItemNutritionCoverageTests {

    private static func fullyDetailedFood() -> FoodItem {
        FoodItem(
            name: "Fully Detailed",
            caloriesPer100g: 400,
            proteinPer100g: 20,
            carbsPer100g: 50,
            fatPer100g: 10,
            fiberPer100g: 8,
            sugarsPer100g: 12,
            addedSugarsPer100g: 6,
            sucrosePer100g: 4,
            glucosePer100g: 3,
            fructosePer100g: 2,
            lactosePer100g: 1,
            maltosePer100g: 5,
            maltodextrinsPer100g: 7,
            starchPer100g: 30,
            polyolsPer100g: 9,
            saturatedFatPer100g: 11,
            transFatPer100g: 13,
            monounsaturatedFatPer100g: 14,
            polyunsaturatedFatPer100g: 15,
            omega3FatPer100g: 16,
            omega6FatPer100g: 17,
            omega9FatPer100g: 18,
            saltPer100g: 19,
            sodiumPer100g: 21,
            cholesterolPer100g: 22,
            solubleFiberPer100g: 23,
            insolubleFiberPer100g: 24,
            caseinPer100g: 25,
            serumProteinsPer100g: 26,
            alcoholPer100g: 27
        )
    }

    // MARK: - Per-portion nutrition

    @Test("Every nutrient scales linearly with the portion")
    func everyNutrientScales() {
        let food = Self.fullyDetailedFood()
        let grams = 150.0

        #expect(food.calories(forGrams: grams) == 600)
        #expect(food.protein(forGrams: grams) == 30)
        #expect(food.carbs(forGrams: grams) == 75)
        #expect(food.fat(forGrams: grams) == 15)
        #expect(food.fiber(forGrams: grams) == 12)
        #expect(food.sugars(forGrams: grams) == 18)
        #expect(food.addedSugars(forGrams: grams) == 9)
        #expect(food.sucrose(forGrams: grams) == 6)
        #expect(food.glucose(forGrams: grams) == 4.5)
        #expect(food.fructose(forGrams: grams) == 3)
        #expect(food.lactose(forGrams: grams) == 1.5)
        #expect(food.maltose(forGrams: grams) == 7.5)
        #expect(food.maltodextrins(forGrams: grams) == 10.5)
        #expect(food.starch(forGrams: grams) == 45)
        #expect(food.polyols(forGrams: grams) == 13.5)
        #expect(food.saturatedFat(forGrams: grams) == 16.5)
        #expect(food.transFat(forGrams: grams) == 19.5)
        #expect(food.monounsaturatedFat(forGrams: grams) == 21)
        #expect(food.polyunsaturatedFat(forGrams: grams) == 22.5)
        #expect(food.omega3Fat(forGrams: grams) == 24)
        #expect(food.omega6Fat(forGrams: grams) == 25.5)
        #expect(food.omega9Fat(forGrams: grams) == 27)
        #expect(food.salt(forGrams: grams) == 28.5)
        #expect(food.sodium(forGrams: grams) == 31.5)
        #expect(food.cholesterol(forGrams: grams) == 33)
        #expect(food.solubleFiber(forGrams: grams) == 34.5)
        #expect(food.insolubleFiber(forGrams: grams) == 36)
        #expect(food.casein(forGrams: grams) == 37.5)
        #expect(food.serumProteins(forGrams: grams) == 39)
        #expect(food.alcohol(forGrams: grams) == 40.5)
    }

    @Test("A 100 g portion is the per-100 g value and an empty portion is zero")
    func identityAndZeroPortions() {
        let food = Self.fullyDetailedFood()

        #expect(food.calories(forGrams: 100) == 400)
        #expect(food.omega3Fat(forGrams: 100) == 16)
        #expect(food.calories(forGrams: 0) == 0)
        #expect(food.protein(forGrams: 0) == 0)
        #expect(food.alcohol(forGrams: 0) == 0)
    }

    @Test("A nutrient the food never recorded stays unknown at every portion")
    func missingNutrientsStayMissing() {
        let food = makeTestFoodItem(caloriesPer100g: 52)

        for grams in [0.0, 1, 100, 250] {
            #expect(food.sugars(forGrams: grams) == nil)
            #expect(food.addedSugars(forGrams: grams) == nil)
            #expect(food.sucrose(forGrams: grams) == nil)
            #expect(food.glucose(forGrams: grams) == nil)
            #expect(food.fructose(forGrams: grams) == nil)
            #expect(food.lactose(forGrams: grams) == nil)
            #expect(food.maltose(forGrams: grams) == nil)
            #expect(food.maltodextrins(forGrams: grams) == nil)
            #expect(food.starch(forGrams: grams) == nil)
            #expect(food.polyols(forGrams: grams) == nil)
            #expect(food.saturatedFat(forGrams: grams) == nil)
            #expect(food.transFat(forGrams: grams) == nil)
            #expect(food.monounsaturatedFat(forGrams: grams) == nil)
            #expect(food.polyunsaturatedFat(forGrams: grams) == nil)
            #expect(food.omega3Fat(forGrams: grams) == nil)
            #expect(food.omega6Fat(forGrams: grams) == nil)
            #expect(food.omega9Fat(forGrams: grams) == nil)
            #expect(food.salt(forGrams: grams) == nil)
            #expect(food.sodium(forGrams: grams) == nil)
            #expect(food.cholesterol(forGrams: grams) == nil)
            #expect(food.solubleFiber(forGrams: grams) == nil)
            #expect(food.insolubleFiber(forGrams: grams) == nil)
            #expect(food.casein(forGrams: grams) == nil)
            #expect(food.serumProteins(forGrams: grams) == nil)
            #expect(food.alcohol(forGrams: grams) == nil)
        }
    }

    @Test("A recorded zero scales to zero rather than unknown")
    func recordedZeroIsZero() {
        let food = makeTestFoodItem(sugarsPer100g: 0, alcoholPer100g: 0)

        #expect(food.sugars(forGrams: 330) == 0)
        #expect(food.alcohol(forGrams: 330) == 0)
    }

    // MARK: - Produce classification

    @Test("Produce kinds name themselves and say whether they count toward variety")
    func produceKindLabels() {
        #expect(ProduceKind.unclassified.displayName == "Not counted")
        #expect(ProduceKind.fruit.displayName == "Fruit")
        #expect(ProduceKind.vegetable.displayName == "Veg")
        #expect(ProduceKind.unclassified.fullDisplayName == "Not counted")
        #expect(ProduceKind.fruit.fullDisplayName == "Fruit")
        #expect(ProduceKind.vegetable.fullDisplayName == "Vegetable")
        #expect(ProduceKind.allCases.map(\.id) == ["unclassified", "fruit", "vegetable"])
        #expect(ProduceKind.manualCases == [.unclassified, .fruit, .vegetable])
        #expect(ProduceKind.allCases.filter(\.countsTowardVariety) == [.fruit, .vegetable])
    }

    @Test(
        "Category tags classify produce only when they point one way",
        arguments: [
            (["en:carrots"], ProduceKind.vegetable),
            (["  EN:Tomatoes "], .vegetable),
            (["en:plant-based-foods", "en:fresh-vegetables"], .vegetable),
            (["en:strawberries"], .fruit),
            (["en:apples", "en:carrots"], .unclassified),
            (["en:apples", "en:jams"], .unclassified),
            (["en:vegetables", "en:ready-meals"], .unclassified),
            (["en:snacks"], .unclassified),
            ([""], .unclassified),
            ([], .unclassified),
        ] as [([String], ProduceKind)]
    )
    func produceInference(tags: [String], expected: ProduceKind) {
        #expect(ProduceKind.inferred(fromCategoryTags: tags) == expected)
        #expect(makeTestFoodItem(categoryTags: tags).produceKind == expected)
    }

    @Test("Replacing a food's category tags normalizes them and keeps its produce kind")
    func categoryTagSetter() {
        let food = makeTestFoodItem(categoryTags: ["en:carrots"])
        #expect(food.produceKind == .vegetable)

        food.categoryTags = [" EN:Soups", "", "en:Vegetables "]

        #expect(food.categoryTags == ["en:soups", "en:vegetables"])
        #expect(food.categoryTagsRaw == "en:soups,en:vegetables")
        #expect(food.produceKind == .vegetable)

        food.categoryTags = ["  "]

        #expect(food.categoryTags.isEmpty)
        #expect(food.categoryTagsRaw == nil)
    }

    @Test("An unreadable stored produce kind reads as not counted")
    func unreadableProduceKind() {
        let food = makeTestFoodItem(produceKind: .fruit)
        food.produceKindRaw = "legume"

        #expect(food.produceKind == .unclassified)
    }

    // MARK: - Serving units

    struct ServingCase: Sendable, CustomTestStringConvertible {
        let description: String
        let grams: Double
        let unit: String
        let plural: String
        let gramsPerUnit: Double

        var testDescription: String { description }
    }

    @Test(
        "Count-based servings become a unit with singular and plural names",
        arguments: [
            ServingCase(description: "1 cup (240g)", grams: 240, unit: "cup", plural: "cups", gramsPerUnit: 240),
            ServingCase(description: "2 slices (60g)", grams: 60, unit: "slice", plural: "slices", gramsPerUnit: 30),
            ServingCase(description: "2 sandwiches (300g)", grams: 300, unit: "sandwich", plural: "sandwiches", gramsPerUnit: 150),
            ServingCase(description: "4 dishes (400g)", grams: 400, unit: "dish", plural: "dishes", gramsPerUnit: 100),
            ServingCase(description: "3 boxes (45g)", grams: 45, unit: "box", plural: "boxes", gramsPerUnit: 15),
            ServingCase(description: "2 glasses (500g)", grams: 500, unit: "glass", plural: "glasses", gramsPerUnit: 250),
            ServingCase(description: "2 berries (20g)", grams: 20, unit: "berry", plural: "berries", gramsPerUnit: 10),
            ServingCase(description: "1,5 cups (360g)", grams: 360, unit: "cup", plural: "cups", gramsPerUnit: 240),
            ServingCase(description: "2 large eggs (100g)", grams: 100, unit: "large egg", plural: "large eggs", gramsPerUnit: 50),
            ServingCase(description: "  3 Wafers  (45 g) ", grams: 45, unit: "wafer", plural: "wafers", gramsPerUnit: 15),
        ]
    )
    func servingUnits(_ serving: ServingCase) throws {
        let food = makeTestFoodItem(defaultServingG: serving.grams, servingDescription: serving.description)

        let info = try #require(food.servingInfo)
        #expect(info.unitName == serving.unit)
        #expect(info.pluralName == serving.plural)
        #expect(info.gramsPerUnit == serving.gramsPerUnit)
        #expect(info.label(for: 1) == "1 \(serving.unit)")
        #expect(info.label(for: 2) == "2 \(serving.plural)")
        #expect(info.label(for: 0) == "0 \(serving.plural)")
    }

    @Test("Some unit words are singularised or pluralised wrongly")
    func servingUnitWordingQuirks() throws {
        let cookies = try #require(
            makeTestFoodItem(defaultServingG: 30, servingDescription: "2 cookies (30g)").servingInfo
        )
        let pies = try #require(
            makeTestFoodItem(defaultServingG: 300, servingDescription: "2 pies (300g)").servingInfo
        )
        let glass = try #require(
            makeTestFoodItem(defaultServingG: 200, servingDescription: "1 glass (200g)").servingInfo
        )
        let box = try #require(
            makeTestFoodItem(defaultServingG: 30, servingDescription: "1 box (30g)").servingInfo
        )

        // Current behaviour, suspected bug: every "-ies" plural becomes "-y" ("cookie", "pie" expected).
        #expect(cookies.label(for: 1) == "1 cooky")
        #expect(pies.label(for: 1) == "1 py")
        // Current behaviour, suspected bug: a singular unit gets a bare "s" ("glasses", "boxes" expected).
        #expect(glass.label(for: 2) == "2 glasss")
        #expect(box.label(for: 3) == "3 boxs")
    }

    @Test("Plural generic serving words are not filtered like their singulars")
    func pluralGenericServingWords() throws {
        let servings = try #require(
            makeTestFoodItem(defaultServingG: 100, servingDescription: "2 servings (100g)").servingInfo
        )

        #expect(makeTestFoodItem(defaultServingG: 100, servingDescription: "1 serving (100g)").servingInfo == nil)
        #expect(makeTestFoodItem(defaultServingG: 100, servingDescription: "1 portion").servingInfo == nil)
        // Current behaviour, suspected bug: "serving"/"portion" are excluded but "servings"/"portions" are not.
        #expect(servings.unitName == "serving")
        #expect(servings.gramsPerUnit == 50)
        #expect(
            makeTestFoodItem(defaultServingG: 300, servingDescription: "2 portions (300g)").servingInfo?.unitName
                == "portion"
        )
    }

    @Test(
        "Weights, volumes, missing counts and sub-gram units are not serving units",
        arguments: [
            ("100 grams", 100.0),
            ("2 oz", 56),
            ("1 l", 1_000),
            ("250 ml", 250),
            ("1 kg", 1_000),
            ("bar", 50),
            ("0 bars", 50),
            ("200 drops (100g)", 100),
            ("2 bars", 0),
            ("", 50),
        ] as [(String, Double)]
    )
    func notServingUnits(description: String, grams: Double) {
        #expect(makeTestFoodItem(defaultServingG: grams, servingDescription: description).servingInfo == nil)
    }

    @Test("A serving needs both a description and a weight")
    func servingNeedsDescriptionAndWeight() {
        #expect(makeTestFoodItem(defaultServingG: nil, servingDescription: "2 bars").servingInfo == nil)
        #expect(makeTestFoodItem(defaultServingG: 100, servingDescription: nil).servingInfo == nil)
    }

    // MARK: - Recipe provenance

    private static func ingredient(
        _ name: String,
        grams: Double,
        provenance: FoodProvenance,
        order: Int
    ) -> RecipeIngredient {
        RecipeIngredient(
            from: makeTestFoodItem(name: name, caloriesPer100g: 100, provenance: provenance),
            portionGrams: grams,
            sortOrder: order
        )
    }

    private static let calorynComplete = FoodProvenance(
        provider: .calorynAPI,
        source: .calorynCatalog,
        completeness: .complete,
        recoveredByFallback: false
    )

    @Test("A recipe of one provider's complete foods keeps that provider and source")
    func singleProviderRecipe() {
        let recipe = makeTestFoodItem(name: "Bowl", nutriscoreGrade: "a", isCustom: true)
        recipe.recipeIngredients = [
            Self.ingredient("Oats", grams: 60, provenance: Self.calorynComplete, order: 0),
            Self.ingredient("Milk", grams: 140, provenance: Self.calorynComplete, order: 1),
        ]

        recipe.updateRecipeNutritionFromIngredients()

        #expect(recipe.provenance == Self.calorynComplete)
        #expect(recipe.defaultServingG == 200)
        #expect(recipe.isRecipe)
        #expect(recipe.isCustom == false)
        #expect(recipe.nutriscoreGrade == nil)
        #expect(recipe.servingDescription == nil)
    }

    @Test("An ingredient of unknown completeness makes the recipe's completeness unknown")
    func unknownCompletenessIngredient() {
        let recipe = makeTestFoodItem(name: "Stew", isRecipe: true)
        recipe.recipeIngredients = [
            Self.ingredient("Beef", grams: 200, provenance: Self.calorynComplete, order: 0),
            Self.ingredient(
                "Stock",
                grams: 300,
                provenance: FoodProvenance(
                    provider: .calorynAPI,
                    source: .calorynCatalog,
                    completeness: .unknown,
                    recoveredByFallback: false
                ),
                order: 1
            ),
        ]

        recipe.updateRecipeNutritionFromIngredients()

        #expect(recipe.provenance.completeness == .unknown)
        #expect(recipe.provenance.provider == .calorynAPI)
        #expect(recipe.provenance.source == .calorynCatalog)
        #expect(recipe.provenance.warrantsNutritionNotice)
    }

    @Test("A partial ingredient outranks an unknown one")
    func partialOutranksUnknown() {
        let recipe = makeTestFoodItem(name: "Salad", isRecipe: true)
        recipe.recipeIngredients = [
            Self.ingredient("Leaves", grams: 50, provenance: .unknown, order: 0),
            Self.ingredient("Dressing", grams: 20, provenance: .manuallyEntered(completeness: .partial), order: 1),
        ]

        recipe.updateRecipeNutritionFromIngredients()

        #expect(recipe.provenance.completeness == .partial)
        #expect(recipe.provenance.source == .mixed)
    }

    @Test("A providerless ingredient drops the recipe's provider")
    func providerlessIngredient() {
        let recipe = makeTestFoodItem(name: "Toast", isRecipe: true)
        recipe.recipeIngredients = [
            Self.ingredient("Bread", grams: 80, provenance: Self.calorynComplete, order: 0),
            Self.ingredient("Homemade Jam", grams: 20, provenance: .userEntered, order: 1),
        ]

        recipe.updateRecipeNutritionFromIngredients()

        #expect(recipe.provenance.provider == nil)
        #expect(recipe.provenance.source == .mixed)
        #expect(recipe.provenance.completeness == .complete)
        #expect(recipe.provenance.recoveredByFallback == false)
    }

    @Test("Recipe calories are the weight-averaged ingredient calories")
    func recipeCaloriesWeightAveraged() {
        let recipe = makeTestFoodItem(name: "Porridge", isRecipe: true)
        recipe.recipeIngredients = [
            RecipeIngredient(
                name: "Oats",
                portionGrams: 50,
                caloriesPer100g: 380,
                proteinPer100g: 13,
                carbsPer100g: 60,
                fatPer100g: 7,
                sortOrder: 0
            ),
            RecipeIngredient(
                name: "Water",
                portionGrams: 150,
                caloriesPer100g: 0,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0,
                sortOrder: 1
            ),
        ]

        recipe.updateRecipeNutritionFromIngredients()

        // 50 g × 380 / 100 = 190 kcal across 200 g → 95 kcal per 100 g
        #expect(recipe.caloriesPer100g == 95)
        // 50 g × 13 / 100 = 6.5 g across 200 g → 3.25 g per 100 g
        #expect(recipe.proteinPer100g == 3.25)
        #expect(recipe.calories(forGrams: recipe.defaultServingG ?? 0) == 190)
    }
}
