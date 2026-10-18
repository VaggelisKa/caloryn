import Foundation
import Testing
@testable import Caloryn

/// Decoding the product JSON both providers return, and the nutrition and
/// serving maths derived from it.
///
/// Open Food Facts is community data: fields go missing, arrive as `null`,
/// arrive as strings, or arrive only in kilojoules. Each case here pins what
/// the app currently makes of that shape, by hand-computed value.
@MainActor
struct OpenFoodFactsDecodingCoverageTests {

    private static func decode(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }

    private static func result(_ product: OpenFoodFactsProduct) -> FoodSearchResult {
        FoodSearchResult(
            product: product,
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: product.nutritionCompleteness,
                recoveredByFallback: false
            )
        )
    }

    // MARK: - Missing and null nutrients

    @Test("A null macro decodes as missing, not as zero")
    func nullMacrosAreMissing() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000001",
              "product_name": "Null Macros",
              "nutriments": {
                "energy-kcal_100g": 120,
                "proteins_100g": null,
                "carbohydrates_100g": 15,
                "fat_100g": null,
                "fiber_100g": null
              }
            }
            """
        )

        #expect(product.nutriments?.energyKcal100g == 120)
        #expect(product.nutriments?.proteins100g == nil)
        #expect(product.nutriments?.carbohydrates100g == 15)
        #expect(product.nutriments?.fat100g == nil)
        #expect(product.nutriments?.fiber100g == nil)
        #expect(product.hasMinimumUsableNutrition)
        #expect(product.nutritionCompleteness == .partial)
        #expect(product.missingCoreNutritionLabels == ["protein", "fat"])
    }

    @Test("Explicit zero macros are complete nutrition")
    func zeroMacrosAreComplete() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000002",
              "product_name": "Sparkling Water",
              "nutriments": {
                "energy-kcal_100g": 0,
                "proteins_100g": 0,
                "carbohydrates_100g": 0,
                "fat_100g": 0
              }
            }
            """
        )

        #expect(product.hasMinimumUsableNutrition)
        #expect(product.nutritionCompleteness == .complete)
        #expect(product.missingCoreNutritionLabels.isEmpty)
    }

    @Test("A null nutriments object leaves the product without usable nutrition")
    func nullNutrimentsObject() throws {
        let product = try Self.decode(
            #"{"code": "4000000000003", "product_name": "Bare", "nutriments": null}"#
        )

        #expect(product.nutriments == nil)
        #expect(product.hasMinimumUsableNutrition == false)
        #expect(product.nutritionCompleteness == .unknown)
        #expect(product.missingCoreNutritionLabels == ["protein", "carbohydrates", "fat"])
    }

    @Test(
        "A missing, null or blank product name makes the product unusable",
        arguments: [
            #""nutriments": {"energy-kcal_100g": 100}"#,
            #""product_name": null, "nutriments": {"energy-kcal_100g": 100}"#,
            #""product_name": "  \n ", "nutriments": {"energy-kcal_100g": 100}"#,
        ]
    )
    func unusableNames(fields: String) throws {
        let product = try Self.decode(#"{"code": "4000000000004", "# + fields + "}")

        #expect(product.hasMinimumUsableNutrition == false)
        #expect(product.nutritionCompleteness == .unknown)
    }

    // MARK: - Energy units

    @Test("A product with energy only in kilojoules is converted to kilocalories")
    func kilojouleOnlyEnergy() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000005",
              "product_name": "Kilojoule Biscuit",
              "nutriments": {
                "energy_100g": 1966,
                "energy-kj_100g": 1966,
                "proteins_100g": 6,
                "carbohydrates_100g": 70,
                "fat_100g": 20
              }
            }
            """
        )

        // 1966 kJ / 4.184 ≈ 469.9 kcal
        let kcal = try #require(product.nutriments?.energyKcal100g)
        #expect(abs(kcal - 469.885) < 0.001)
        #expect(product.hasMinimumUsableNutrition)
        #expect(product.nutritionCompleteness == .complete)
    }

    @Test("The kcal field is used verbatim when kilojoules are also present")
    func kcalWinsOverKilojoules() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000006",
              "product_name": "Dual Energy",
              "nutriments": {
                "energy_100g": 1000,
                "energy-kj_100g": 1000,
                "energy-kcal_100g": 239,
                "proteins_100g": 1,
                "carbohydrates_100g": 2,
                "fat_100g": 3
              }
            }
            """
        )

        #expect(product.nutriments?.energyKcal100g == 239)
        #expect(FoodSearchService().createFoodItem(from: Self.result(product)).caloriesPer100g == 239)
    }

    // MARK: - String-typed values

    @Test("A string-typed nutrient value is read as the number it spells")
    func stringTypedNutrient() throws {
        let product = try Self.decode(
            #"{"code": "4000000000007", "product_name": "Stringly", "nutriments": {"energy-kcal_100g": "52", "proteins_100g": " 1.5 ", "fat_100g": "trace"}}"#
        )

        #expect(product.nutriments?.energyKcal100g == 52)
        #expect(product.nutriments?.proteins100g == 1.5)
        #expect(product.nutriments?.fat100g == nil)
        #expect(product.hasMinimumUsableNutrition)
    }

    @Test("A string-typed nutrient that spells a non-finite number is missing", arguments: ["NaN", "nan", "inf", "-Infinity"])
    func nonFiniteStringNutrient(spelling: String) throws {
        let product = try Self.decode(
            #"{"code": "4000000000008", "product_name": "Stringly", "nutriments": {"energy-kcal_100g": "\#(spelling)", "energy-kj_100g": "\#(spelling)", "fiber_100g": "\#(spelling)"}}"#
        )

        #expect(product.nutriments?.energyKcal100g == nil)
        #expect(product.nutriments?.fiber100g == nil)
        #expect(product.hasMinimumUsableNutrition == false)
    }

    @Test(
        "Serving quantity accepts a number or a numeric string",
        arguments: [
            (#""serving_quantity": 30"#, 30),
            (#""serving_quantity": "50.5""#, 50.5),
            (#""serving_quantity": "50,5""#, nil),
            (#""serving_quantity": "abc""#, nil),
            (#""serving_quantity": """#, nil),
            (#""serving_quantity": true"#, nil),
            (#""serving_quantity": null"#, nil),
        ] as [(String, Double?)]
    )
    func servingQuantityShapes(field: String, expected: Double?) throws {
        let product = try Self.decode(
            #"{"code": "4000000000008", "product_name": "Serving", "#
                + field
                + #", "nutriments": {"energy-kcal_100g": 100}}"#
        )

        #expect(product.servingQuantityG == expected)
    }

    @Test(
        "Product quantity accepts a number or a numeric string",
        arguments: [
            (#""product_quantity": 125"#, 125),
            (#""product_quantity": "350""#, 350),
            (#""product_quantity": "large""#, nil),
            (#""product_quantity": null"#, nil),
        ] as [(String, Double?)]
    )
    func productQuantityShapes(field: String, expected: Double?) throws {
        let product = try Self.decode(
            #"{"code": "4000000000009", "product_name": "Pack", "#
                + field
                + #", "nutriments": {"energy-kcal_100g": 100}}"#
        )

        #expect(product.productQuantity == expected)
    }

    @Test(
        "Brands accept a string or an array, and anything else is dropped",
        arguments: [
            (#""brands": "Arla""#, "Arla"),
            (#""brands": ["Arla", "Lurpak"]"#, "Arla, Lurpak"),
            (#""brands": []"#, ""),
            (#""brands": 42"#, nil),
            (#""brands": null"#, nil),
        ] as [(String, String?)]
    )
    func brandShapes(field: String, expected: String?) throws {
        let product = try Self.decode(
            #"{"code": "4000000000010", "product_name": "Branded", "#
                + field
                + #", "nutriments": {"energy-kcal_100g": 100}}"#
        )

        #expect(product.brands == expected)
    }

    // MARK: - Salt and sodium

    @Test("Salt without sodium is kept as salt and sodium stays missing")
    func saltWithoutSodium() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000011",
              "product_name": "Salted Crackers",
              "nutriments": {
                "energy-kcal_100g": 450,
                "proteins_100g": 9,
                "carbohydrates_100g": 70,
                "fat_100g": 14,
                "salt_100g": 1.25
              }
            }
            """
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        // Salt is not converted into sodium (1.25 g salt would be 0.5 g sodium).
        #expect(food.saltPer100g == 1.25)
        #expect(food.sodiumPer100g == nil)
        #expect(food.salt(forGrams: 40) == 0.5)
        #expect(food.sodium(forGrams: 40) == nil)
        #expect(food.fieldOrigin(for: .salt) == .provider)
        #expect(food.fieldOrigin(for: .sodium) == .missing)
    }

    @Test("Salt and sodium are both copied verbatim when the provider sends both")
    func saltAndSodium() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000012",
              "product_name": "Stock Cube",
              "nutriments": {
                "energy-kcal_100g": 250,
                "salt_100g": 50,
                "sodium_100g": 20
              }
            }
            """
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        #expect(food.saltPer100g == 50)
        #expect(food.sodiumPer100g == 20)
        #expect(food.sodium(forGrams: 4) == 0.8)
    }

    // MARK: - Mapping every nutrient

    @Test("Every nutriment key lands on its own FoodItem field")
    func everyNutrimentKeyMaps() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000013",
              "product_name": "Everything Bar",
              "nutriments": {
                "energy-kcal_100g": 401,
                "proteins_100g": 1.1,
                "carbohydrates_100g": 2.2,
                "fat_100g": 3.3,
                "fiber_100g": 4.4,
                "sugars_100g": 5.5,
                "added-sugars_100g": 6.6,
                "sucrose_100g": 7.7,
                "glucose_100g": 8.8,
                "fructose_100g": 9.9,
                "lactose_100g": 10.1,
                "maltose_100g": 11.1,
                "maltodextrins_100g": 12.1,
                "starch_100g": 13.1,
                "polyols_100g": 14.1,
                "saturated-fat_100g": 15.1,
                "trans-fat_100g": 16.1,
                "monounsaturated-fat_100g": 17.1,
                "polyunsaturated-fat_100g": 18.1,
                "omega-3-fat_100g": 19.1,
                "omega-6-fat_100g": 20.1,
                "omega-9-fat_100g": 21.1,
                "salt_100g": 22.1,
                "sodium_100g": 23.1,
                "cholesterol_100g": 24.1,
                "soluble-fiber_100g": 25.1,
                "insoluble-fiber_100g": 26.1,
                "casein_100g": 27.1,
                "serum-proteins_100g": 28.1,
                "alcohol_100g": 29.1
              }
            }
            """
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        #expect(food.caloriesPer100g == 401)
        #expect(food.proteinPer100g == 1.1)
        #expect(food.carbsPer100g == 2.2)
        #expect(food.fatPer100g == 3.3)
        #expect(food.fiberPer100g == 4.4)
        #expect(food.sugarsPer100g == 5.5)
        #expect(food.addedSugarsPer100g == 6.6)
        #expect(food.sucrosePer100g == 7.7)
        #expect(food.glucosePer100g == 8.8)
        #expect(food.fructosePer100g == 9.9)
        #expect(food.lactosePer100g == 10.1)
        #expect(food.maltosePer100g == 11.1)
        #expect(food.maltodextrinsPer100g == 12.1)
        #expect(food.starchPer100g == 13.1)
        #expect(food.polyolsPer100g == 14.1)
        #expect(food.saturatedFatPer100g == 15.1)
        #expect(food.transFatPer100g == 16.1)
        #expect(food.monounsaturatedFatPer100g == 17.1)
        #expect(food.polyunsaturatedFatPer100g == 18.1)
        #expect(food.omega3FatPer100g == 19.1)
        #expect(food.omega6FatPer100g == 20.1)
        #expect(food.omega9FatPer100g == 21.1)
        #expect(food.saltPer100g == 22.1)
        #expect(food.sodiumPer100g == 23.1)
        #expect(food.cholesterolPer100g == 24.1)
        #expect(food.solubleFiberPer100g == 25.1)
        #expect(food.insolubleFiberPer100g == 26.1)
        #expect(food.caseinPer100g == 27.1)
        #expect(food.serumProteinsPer100g == 28.1)
        #expect(food.alcoholPer100g == 29.1)
        #expect(FoodField.allCases.filter { food.fieldOrigin(for: $0) == .missing } == [
            .brand, .defaultServing, .servingDescription, .nutriscore, .categoryTags, .produceKind,
        ])
    }

    @Test("A product with no name or nutrients saves as an unknown food of zeros")
    func emptyProductMaterializes() throws {
        let product = try Self.decode(#"{"code": " 4000000000014 "}"#)
        let provenance = FoodProvenance(
            provider: .calorynAPI,
            source: .calorynCatalog,
            completeness: .unknown,
            recoveredByFallback: false
        )

        let food = FoodSearchService().createFoodItem(
            from: FoodSearchResult(product: product, provenance: provenance)
        )

        #expect(food.name == "Unknown")
        #expect(food.brand == nil)
        #expect(food.barcode == "4000000000014")
        #expect(food.caloriesPer100g == 0)
        #expect(food.proteinPer100g == 0)
        #expect(food.carbsPer100g == 0)
        #expect(food.fatPer100g == 0)
        #expect(food.fiberPer100g == 0)
        #expect(food.sugarsPer100g == nil)
        #expect(food.defaultServingG == nil)
        #expect(food.servingDescription == nil)
        #expect(food.categoryTags.isEmpty)
        #expect(food.provenance == provenance)
        #expect(FoodField.allCases.allSatisfy { food.fieldOrigin(for: $0) == .missing })
    }

    @Test("A non-numeric product code is kept as the barcode but is not a catalog identity")
    func nonNumericCode() throws {
        let product = try Self.decode(
            #"{"code": "  fr-abc-9  ", "product_name": "Bakery Loaf", "nutriments": {"energy-kcal_100g": 250}}"#
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        #expect(food.barcode == "fr-abc-9")
        #expect(food.normalizedBarcode == nil)
        #expect(food.providerProductIdentityRaw == nil)
        #expect(food.isCatalogProduct == false)
    }

    @Test(
        "Only a Nutri-Score letter A to E is kept, lowercased",
        arguments: [
            (#""nutrition_grades": "B""#, "b"),
            (#""nutrition_grades": "e""#, "e"),
            (#""nutrition_grades": "unknown""#, nil),
            (#""nutrition_grades": "not-applicable""#, nil),
            (#""nutrition_grades": """#, nil),
            (#""nutrition_grades": null"#, nil),
        ] as [(String, String?)]
    )
    func nutriscore(field: String, expected: String?) throws {
        let product = try Self.decode(
            #"{"code": "4000000000015", "product_name": "Graded", "#
                + field
                + #", "nutriments": {"energy-kcal_100g": 100}}"#
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        #expect(food.nutriscoreGrade == expected)
        #expect(food.fieldOrigin(for: .nutriscore) == (expected == nil ? .missing : .provider))
    }

    // MARK: - Serving size and per-serving calories

    @Test("A fractional serving quantity keeps its grams but shows them truncated")
    func fractionalServingQuantity() throws {
        let product = try Self.decode(
            #"{"code": "4000000000016", "product_name": "Half Bar", "serving_quantity": "50.5", "nutriments": {"energy-kcal_100g": 200}}"#
        )

        #expect(product.formattedServingDescription == "50g")
        #expect(product.effectiveServingInfo.defaultServingG == 50.5)
        #expect(product.effectiveServingInfo.servingDescription == "50g")
        // 200 kcal/100 g × 50.5 g = 101 kcal
        #expect(product.caloriesPerServing == 101)
    }

    @Test("An empty serving size falls back to the serving grams")
    func emptyServingSize() throws {
        let product = try Self.decode(
            #"{"code": "4000000000017", "product_name": "Scoop", "serving_size": "", "serving_quantity": 30, "nutriments": {"energy-kcal_100g": 380}}"#
        )

        #expect(product.formattedServingDescription == "30g")
        // 380 kcal/100 g × 30 g = 114 kcal
        #expect(product.caloriesPerServing == 114)
    }

    @Test("A zero serving quantity defers to the pack size for the default serving")
    func zeroServingQuantity() throws {
        let product = try Self.decode(
            #"{"code": "4000000000018", "product_name": "Tub", "serving_quantity": 0, "product_quantity": 350, "nutriments": {"energy-kcal_100g": 60}}"#
        )

        #expect(product.formattedServingDescription == nil)
        #expect(product.effectiveServingInfo.defaultServingG == 350)
        #expect(product.effectiveServingInfo.servingDescription == "1 pack (350g)")
        // 60 kcal/100 g × 350 g = 210 kcal
        #expect(product.caloriesPerServing == 210)
    }

    @Test("A numeric pack size becomes a one-pack default serving")
    func numericProductQuantity() throws {
        let product = try Self.decode(
            #"{"code": "4000000000019", "product_name": "Pot", "product_quantity": 125, "nutriments": {"energy-kcal_100g": 80}}"#
        )

        #expect(product.effectiveServingInfo.defaultServingG == 125)
        #expect(product.effectiveServingInfo.servingDescription == "1 pack (125g)")
        // 80 kcal/100 g × 125 g = 100 kcal
        #expect(product.caloriesPerServing == 100)
    }

    @Test(
        "A gram amount is read out of the free-text quantity",
        arguments: [
            ("250g", 250, "1 pack (250g)"),
            ("12,5 g", 12.5, "1 pack (12g)"),
            ("4 x 125 g", 125, "1 pack (125g)"),
            ("Net wt 1.5 oz (42.5 g)", 42.5, "1 pack (42g)"),
            ("500 ml", nil, nil),
            ("1 kg", nil, nil),
            ("0 g", nil, nil),
            ("", nil, nil),
        ] as [(String, Double?, String?)]
    )
    func quantityText(quantity: String, grams: Double?, description: String?) throws {
        let product = try Self.decode(
            #"{"code": "4000000000020", "product_name": "Pack", "quantity": ""#
                + quantity
                + #"", "nutriments": {"energy-kcal_100g": 400}}"#
        )

        #expect(product.effectiveServingInfo.defaultServingG == grams)
        #expect(product.effectiveServingInfo.servingDescription == description)
        // 400 kcal/100 g, so a serving is 4 kcal per gram
        #expect(product.caloriesPerServing == grams.map { $0 * 4 })
    }

    @Test("Per-serving calories need both a serving weight and an energy value")
    func caloriesPerServingNeedsBoth() throws {
        let noEnergy = try Self.decode(
            #"{"code": "4000000000021", "product_name": "No Energy", "serving_quantity": 30, "nutriments": {"proteins_100g": 5}}"#
        )
        let noServing = try Self.decode(
            #"{"code": "4000000000022", "product_name": "No Serving", "nutriments": {"energy-kcal_100g": 300}}"#
        )

        #expect(noEnergy.caloriesPerServing == nil)
        #expect(noServing.caloriesPerServing == nil)
        #expect(noServing.effectiveServingInfo.defaultServingG == nil)
        #expect(noServing.effectiveServingInfo.servingDescription == nil)
    }

    @Test("Serving quantity outranks pack size, which outranks the quantity text")
    func servingPrecedence() throws {
        let product = try Self.decode(
            """
            {
              "code": "4000000000023",
              "product_name": "Layered",
              "serving_size": "2 biscuits (25 g)",
              "serving_quantity": 25,
              "product_quantity": 300,
              "quantity": "300 g",
              "nutriments": { "energy-kcal_100g": 480 }
            }
            """
        )

        let food = FoodSearchService().createFoodItem(from: Self.result(product))

        #expect(food.defaultServingG == 25)
        #expect(food.servingDescription == "2 biscuits (25 g)")
        // 480 kcal/100 g × 25 g = 120 kcal
        #expect(product.caloriesPerServing == 120)
        #expect(food.calories(forGrams: food.defaultServingG ?? 0) == 120)
    }

    // MARK: - Identity and richness

    @Test(
        "Richness counts each nutrient, a brand, a serving and a grade",
        arguments: [
            (#""nutriments": {"energy-kcal_100g": 100}"#, 10),
            (#""brands": "", "nutriments": {"energy-kcal_100g": 100}"#, 10),
            (#""brands": "Arla", "nutriments": {"energy-kcal_100g": 100}"#, 12),
            (#""quantity": "200 g", "nutriments": {"energy-kcal_100g": 100}"#, 12),
            (#""nutrition_grades": "z", "nutriments": {"energy-kcal_100g": 100}"#, 11),
            (
                #""brands": "Arla", "serving_quantity": 30, "nutrition_grades": "a", "nutriments": {"energy-kcal_100g": 100, "proteins_100g": 1, "carbohydrates_100g": 2, "fat_100g": 3, "fiber_100g": 4, "sugars_100g": 5, "saturated-fat_100g": 6, "sodium_100g": 7, "salt_100g": 8, "starch_100g": 9}"#,
                85
            ),
        ] as [(String, Int)]
    )
    func richness(fields: String, expected: Int) throws {
        let product = try Self.decode(#"{"code": "4000000000024", "product_name": "Rich", "# + fields + "}")

        #expect(product.richnessScore == expected)
    }

    @Test("Codes that differ only in spacing, punctuation or case are one product")
    func codeNormalization() throws {
        let sparse = try Self.decode(
            #"{"code": "0 5711953 150388", "product_name": "Sparse", "nutriments": {"energy-kcal_100g": 50}}"#
        )
        let rich = try Self.decode(
            #"{"code": "05711953-150388", "product_name": "Rich", "nutriments": {"energy-kcal_100g": 50, "proteins_100g": 3}}"#
        )
        let other = try Self.decode(
            #"{"code": "05711953150389", "product_name": "Other", "nutriments": {"energy-kcal_100g": 50}}"#
        )

        let reconciled = FoodSearchService.reconcile([sparse, other, rich].map(Self.result))

        #expect(sparse.reconciliationKey == "code:05711953150388")
        #expect(reconciled.map(\.product.productName) == ["Rich", "Other"])
    }

    @Test("Reconciling equally rich duplicates keeps the first one")
    func reconcileTieKeepsFirst() throws {
        let first = try Self.decode(
            #"{"code": "4000000000030", "product_name": "First", "nutriments": {"energy-kcal_100g": 50}}"#
        )
        let second = try Self.decode(
            #"{"code": "4000000000030", "product_name": "Second", "nutriments": {"energy-kcal_100g": 90}}"#
        )

        #expect(first.richnessScore == second.richnessScore)
        #expect(FoodSearchService.reconcile([first, second].map(Self.result)).map(\.product.productName) == ["First"])
    }

    @Test("Without a usable code, products match on folded name and brand")
    func nameAndBrandIdentity() throws {
        let accented = try Self.decode(
            #"{"code": "--", "product_name": "Café Crème", "brands": "Nestlé", "nutriments": {"energy-kcal_100g": 70}}"#
        )
        let plain = try Self.decode(
            #"{"product_name": "CAFE  creme!", "brands": "nestle", "nutriments": {"energy-kcal_100g": 70, "fat_100g": 3}}"#
        )
        let otherBrand = try Self.decode(
            #"{"product_name": "Cafe Creme", "brands": "Lavazza", "nutriments": {"energy-kcal_100g": 70}}"#
        )

        let reconciled = FoodSearchService.reconcile([accented, plain, otherBrand].map(Self.result))

        #expect(accented.reconciliationKey == "name:cafecreme|brand:nestle")
        #expect(plain.reconciliationKey == accented.reconciliationKey)
        #expect(reconciled.map(\.product.brands) == ["nestle", "Lavazza"])
    }

    @Test("Products with neither a code nor a name are never merged")
    func anonymousProductsStayDistinct() throws {
        let json = #"{"nutriments": {"energy-kcal_100g": 100}}"#
        let first = try Self.decode(json)
        let second = try Self.decode(json)

        #expect(first.id != second.id)
        #expect(first.reconciliationKey == "id:\(first.id)")
        #expect(FoodSearchService.reconcile([first, second].map(Self.result)).count == 2)
    }

    @Test("A coded product's id is its code")
    func codedID() throws {
        let product = try Self.decode(
            #"{"code": "4000000000025", "product_name": "Coded", "nutriments": {"energy-kcal_100g": 100}}"#
        )

        #expect(product.id == "4000000000025")
        #expect(Self.result(product).id == "4000000000025")
    }

    // MARK: - Response envelopes

    @Test("A barcode response without a product decodes with status zero")
    func barcodeNotFoundEnvelope() throws {
        let response = try JSONDecoder().decode(
            BarcodeLookupResponse.self,
            from: Data(#"{"code": "4000000000026", "status": 0, "status_verbose": "product not found"}"#.utf8)
        )

        #expect(response.status == 0)
        #expect(response.code == "4000000000026")
        #expect(response.product == nil)
    }

    @Test("A search response without hits does not decode")
    func searchEnvelopeRequiresHits() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SearchResponse.self, from: Data(#"{"count": 0}"#.utf8))
        }
    }
}
