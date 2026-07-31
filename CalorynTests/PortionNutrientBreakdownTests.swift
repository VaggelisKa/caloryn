import Testing
@testable import Caloryn

/// Covers the flat nutrient list the portion picker previews: which rows
/// appear, their order, their labels and their units — and that the flat
/// table stays in agreement with `NutrientDetailGroup`, whose grouped cards
/// describe the same domain for the Nutrition Details sheet.
@Suite("Portion nutrient breakdown")
struct PortionNutrientBreakdownTests {

    // MARK: - Core rows

    @Test("The four core macros are always shown, even when nothing else is recorded")
    func coreRowsAlwaysPresent() {
        let items = PortionNutrientBreakdown(nutrition: NutritionValues(calories: 100)).items

        #expect(items.map(\.id) == ["protein", "carbs", "fat", "fiber"])
    }

    @Test("A core macro of zero is a real zero and stays visible")
    func coreZeroIsShown() {
        let nutrition = NutritionValues(calories: 884, proteinG: 0, carbsG: 0, fatG: 100, fiberG: 0)
        let items = PortionNutrientBreakdown(nutrition: nutrition).items

        #expect(items.first { $0.id == "protein" }?.formattedValue == "0g")
        #expect(items.first { $0.id == "fat" }?.formattedValue == "100g")
    }

    // MARK: - Optional rows

    @Test("An optional nutrient nothing was recorded for is omitted rather than shown as zero")
    func absentOptionalRowsAreDropped() {
        let nutrition = NutritionValues(calories: 63, sugarsG: 3.7, sodiumG: 0.05)
        let items = PortionNutrientBreakdown(nutrition: nutrition).items

        #expect(items.map(\.id) == ["protein", "carbs", "fat", "fiber", "sugars", "sodium"])
    }

    @Test("A recorded zero is still shown")
    func recordedZeroIsShown() {
        let nutrition = NutritionValues(calories: 100, starchG: 0)
        let items = PortionNutrientBreakdown(nutrition: nutrition).items

        #expect(items.contains { $0.id == "starch" && $0.value == 0 })
    }

    // MARK: - Order and labels

    /// The full table, pinned: rows keep the declared order regardless of which
    /// happen to be recorded, so the preview never reshuffles between foods.
    @Test("Rows keep a fixed order and their exact labels")
    func fullTableOrderAndLabels() {
        let items = PortionNutrientBreakdown(nutrition: Self.everyNutrientRecorded).items

        let expected: [(id: String, label: String)] = [
            ("protein", "Protein"),
            ("carbs", "Carbs"),
            ("fat", "Fat"),
            ("fiber", "Fiber"),
            ("sugars", "Sugars"),
            ("added-sugars", "Added sugars"),
            ("sucrose", "Sucrose"),
            ("glucose", "Glucose"),
            ("fructose", "Fructose"),
            ("lactose", "Lactose"),
            ("maltose", "Maltose"),
            ("maltodextrins", "Maltodextrins"),
            ("starch", "Starch"),
            ("polyols", "Polyols"),
            ("saturated-fat", "Saturated fat"),
            ("trans-fat", "Trans fat"),
            ("monounsaturated-fat", "Monounsaturated"),
            ("polyunsaturated-fat", "Polyunsaturated"),
            ("omega-3-fat", "Omega-3 fat"),
            ("omega-6-fat", "Omega-6 fat"),
            ("omega-9-fat", "Omega-9 fat"),
            ("salt", "Salt"),
            ("sodium", "Sodium"),
            ("cholesterol", "Cholesterol"),
            ("soluble-fiber", "Soluble fiber"),
            ("insoluble-fiber", "Insoluble fiber"),
            ("casein", "Casein"),
            ("serum-proteins", "Serum proteins"),
            ("alcohol", "Alcohol")
        ]

        #expect(items.map(\.id) == expected.map { $0.id })
        #expect(items.map(\.label) == expected.map { $0.label })
    }

    @Test("Skipping unrecorded rows never reorders the rest")
    func sparseRecordingKeepsDeclaredOrder() {
        let nutrition = NutritionValues(
            calories: 210,
            sugarsG: 2,
            saturatedFatG: 0.4,
            alcoholG: 1
        )
        let items = PortionNutrientBreakdown(nutrition: nutrition).items

        #expect(items.map(\.id) == ["protein", "carbs", "fat", "fiber", "sugars", "saturated-fat", "alcohol"])
    }

    // MARK: - Units

    @Test("Sodium and cholesterol are stored in grams but displayed in milligrams")
    func sodiumAndCholesterolDisplayInMilligrams() {
        let nutrition = NutritionValues(calories: 63, sodiumG: 0.05, cholesterolG: 0.0104)
        let items = PortionNutrientBreakdown(nutrition: nutrition).items

        #expect(items.first { $0.id == "sodium" }?.formattedValue == "50mg")
        #expect(items.first { $0.id == "cholesterol" }?.formattedValue == "10mg")
    }

    @Test("Every other row is formatted as grams")
    func everyOtherRowIsGrams() {
        let items = PortionNutrientBreakdown(nutrition: Self.everyNutrientRecorded).items
        let milligramRows = items.filter { $0.unit == .milligramsFromGrams }

        #expect(milligramRows.map(\.id) == ["sodium", "cholesterol"])
        #expect(items.first { $0.id == "sugars" }?.formattedValue == "1.5g")
    }

    // MARK: - Parity with the grouped breakdown

    /// The flat table and `NutrientDetailGroup` describe the same domain, and
    /// used to do so in two hand-maintained copies. Every line a grouped card
    /// can show must exist in the flat table with the same unit — and the same
    /// label, with one deliberate exception: the grouped Salt card titles
    /// itself "Salt" and calls its line "Salt equivalent", while the flat list
    /// has no card title to lean on and says "Salt". If either side changes,
    /// this fails and the divergence gets a decision instead of going unnoticed.
    @Test("Every grouped detail line exists in the flat table with a matching label and unit")
    func parityWithNutrientDetailGroup() {
        let flatItems = PortionNutrientBreakdown(nutrition: Self.everyNutrientRecorded).items
        let flatByID = Dictionary(uniqueKeysWithValues: flatItems.map { ($0.id, $0) })

        let groupedItems = NutrientDetailGroup.allCases.flatMap { group in
            group.items(in: Self.everyNutrientRecorded)
        }
        #expect(!groupedItems.isEmpty)

        for grouped in groupedItems {
            guard let flat = flatByID[grouped.id] else {
                Issue.record("Grouped line \(grouped.id) is missing from the portion picker's flat table")
                continue
            }
            #expect(flat.unit == grouped.unit, "Unit for \(grouped.id) differs between the two tables")

            if grouped.id == "salt" {
                #expect(grouped.label == "Salt equivalent")
                #expect(flat.label == "Salt")
            } else {
                #expect(flat.label == grouped.label, "Label for \(grouped.id) differs between the two tables")
            }
        }
    }

    // MARK: - Fixtures

    /// A value with every nutrient recorded, so the fixed tables surface all
    /// of their lines.
    private static let everyNutrientRecorded = NutritionValues(
        calories: 500,
        proteinG: 1.5,
        carbsG: 1.5,
        fatG: 1.5,
        fiberG: 1.5,
        sugarsG: 1.5,
        addedSugarsG: 1.5,
        sucroseG: 1.5,
        glucoseG: 1.5,
        fructoseG: 1.5,
        lactoseG: 1.5,
        maltoseG: 1.5,
        maltodextrinsG: 1.5,
        starchG: 1.5,
        polyolsG: 1.5,
        saturatedFatG: 1.5,
        transFatG: 1.5,
        monounsaturatedFatG: 1.5,
        polyunsaturatedFatG: 1.5,
        omega3FatG: 1.5,
        omega6FatG: 1.5,
        omega9FatG: 1.5,
        saltG: 1.5,
        sodiumG: 1.5,
        cholesterolG: 1.5,
        solubleFiberG: 1.5,
        insolubleFiberG: 1.5,
        caseinG: 1.5,
        serumProteinsG: 1.5,
        alcoholG: 1.5
    )
}
