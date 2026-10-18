import Foundation
import Testing
@testable import Caloryn

/// The Nutrition Details sheet's sub-nutrient groups and how the sheet sorts them into
/// sections: each group's title and symbol, the breakdown sections it heads, salt joining the
/// plain amounts, and the over-a-maximum wording at the precision of milligram figures.
@MainActor
@Suite("Nutrition details coverage")
struct NutritionDetailsCoverageTests {
    private let us = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    // MARK: - Groups

    @Test(
        "given each sub-nutrient group, when titling it, then it has its own heading and symbol",
        arguments: [
            (NutrientDetailGroup.protein, "Protein Details", "dumbbell.fill"),
            (.carbs, "Carb Details", "fork.knife"),
            (.fat, "Fat Details", "drop.fill"),
            (.salt, "Salt", "s.circle.fill")
        ]
    )
    func groupTitleAndSymbol(group: NutrientDetailGroup, title: String, systemImage: String) {
        #expect(group.title == title)
        #expect(group.systemImage == systemImage)
    }

    @Test("given a populated group, when identifying and titling it, then it takes its group's id, heading and symbol")
    func populatedGroupForwardsItsGroup() throws {
        let groups = NutrientDetailGroup.populatedGroups(in: NutritionValues(calories: 300, transFatG: 0.4, omega9FatG: 2))

        let fat = try #require(groups.first)
        #expect(groups.count == 1)
        #expect(fat.id == "fat")
        #expect(fat.title == "Fat Details")
        #expect(fat.systemImage == "drop.fill")
        #expect(fat.items.map(\.label) == ["Trans fat", "Omega-9 fat"])
        #expect(fat.items.map(\.value) == [0.4, 2])
    }

    @Test("given every protein and fat line recorded, when listing them, then they keep their declared order")
    func everyProteinAndFatLineIsListedInOrder() {
        let nutrition = NutritionValues(
            calories: 500,
            transFatG: 1,
            monounsaturatedFatG: 2,
            polyunsaturatedFatG: 3,
            omega3FatG: 4,
            omega6FatG: 5,
            omega9FatG: 6,
            caseinG: 7,
            serumProteinsG: 8
        )

        #expect(NutrientDetailGroup.protein.items(in: nutrition).map(\.label) == ["Casein", "Serum proteins"])
        #expect(NutrientDetailGroup.fat.items(in: nutrition).map(\.label) == [
            "Trans fat", "Monounsaturated", "Polyunsaturated", "Omega-3 fat", "Omega-6 fat", "Omega-9 fat"
        ])
        #expect(NutrientDetailGroup.fat.items(in: nutrition).map(\.value) == [1, 2, 3, 4, 5, 6])
    }

    @Test("given a whole number of grams, when written for the reader's own locale, then it carries the unit after a space")
    func theDefaultLocaleSpellingCarriesTheUnit() {
        #expect(DetailNutrient(id: "starch", label: "Starch", value: 55).spacedFormattedValue == "55 g")
        #expect(DetailNutrient(id: "salt", label: "Salt", value: 0.02, unit: .milligramsFromGrams).spacedFormattedValue == "20 mg")
    }

    // MARK: - Sections

    @Test("given recorded sub-nutrients, when sorting the sheet, then protein, carb and fat each head a breakdown in group order")
    func subNutrientsHeadBreakdowns() {
        let details = NutrientDetailGroup.populatedGroups(in: NutritionValues(
            calories: 600,
            sucroseG: 2.5,
            starchG: 40,
            omega3FatG: 1.25,
            saltG: 1.2,
            caseinG: 8
        ))

        let sections = NutritionDetailsSections(metrics: [], details: details, locale: us)

        #expect(sections.breakdowns.map(\.id) == ["protein", "carbs", "fat"])
        #expect(sections.breakdowns.map(\.title) == ["Protein breakdown", "Carb breakdown", "Fat breakdown"])
        #expect(sections.breakdowns[0].rows == [.init(id: "casein", label: "Casein", valueText: "8 g")])
        #expect(sections.breakdowns[1].rows == [
            .init(id: "sucrose", label: "Sucrose", valueText: "2.5 g"),
            .init(id: "starch", label: "Starch", valueText: "40 g")
        ])
        #expect(sections.breakdowns[2].rows == [.init(id: "omega-3-fat", label: "Omega-3 fat", valueText: "1.3 g")])
    }

    @Test("given salt alongside plain amounts, when sorting the sheet, then salt joins the amounts after the nutrients rather than heading a section of one")
    func saltJoinsTheAmounts() {
        let fiber = TrackedNutrientMetric(nutrient: .fiber, value: 14, target: nil, goalKind: nil)
        let protein = TrackedNutrientMetric(nutrient: .protein, value: 46, target: 150, goalKind: .minimum)
        let details = NutrientDetailGroup.populatedGroups(in: NutritionValues(calories: 600, saltG: 1.25))

        let sections = NutritionDetailsSections(metrics: [fiber, protein], details: details, locale: danish)

        #expect(sections.breakdowns.isEmpty)
        #expect(sections.amounts.map(\.id) == ["fiber", "salt"])
        #expect(sections.amounts.map(\.label) == ["Fiber", "Salt"])
        #expect(sections.amounts.last?.valueText == "1,3 g")
        #expect(sections.targets.map(\.id) == [.protein])
    }

    @Test("given no metrics and no details, when sorting the sheet, then every section is empty")
    func nothingRecordedLeavesEverySectionEmpty() {
        let sections = NutritionDetailsSections(metrics: [], details: [], locale: us)

        #expect(sections.targets.isEmpty)
        #expect(sections.amounts.isEmpty)
        #expect(sections.breakdowns.isEmpty)
    }

    @Test(
        "given a milligram maximum passed by less than a milligram, when flagging it, then the overshoot too small to show gets no words",
        arguments: [
            (2.3004, nil),
            (2.3006, "1 mg over"),
            (2.8, "500 mg over")
        ] as [(Double, String?)]
    )
    func milligramOvershootsAtDisplayPrecision(value: Double, expected: String?) {
        let text = NutritionDetailsSections.overMaximumText(
            value: value,
            target: 2.3,
            goalKind: .maximum,
            unit: .milligramsFromGrams,
            locale: us
        )

        #expect(text == expected)
    }

    @Test(
        "given a goal that is not a maximum, when passed, then it is never called over",
        arguments: [NutrientGoalKind.minimum, .target]
    )
    func onlyAMaximumIsCalledOver(goalKind: NutrientGoalKind) {
        #expect(NutritionDetailsSections.overMaximumText(
            value: 300,
            target: 100,
            goalKind: goalKind,
            unit: .grams,
            locale: us
        ) == nil)
    }

    @Test(
        "given a negative produce count, when counting down to five, then it is treated as none rather than more than five to go",
        arguments: [(-2, "none yet", "5 more for variety"), (4, "4 kinds today", "1 more for variety")] as [(Int, String, String)]
    )
    func produceCountsAreFloored(count: Int, countText: String, remaining: String) {
        #expect(NutritionDetailsSections.produceCountText(count) == countText)
        #expect(NutritionDetailsSections.produceRemainingText(count) == remaining)
    }

    @Test("given nothing graded, when stating Nutri-Score coverage, then zero items read in the plural")
    func noGradedItemsReadPlural() {
        #expect(NutritionDetailsSections.nutriscoreGradedText(graded: 0, total: 0) == "0 of 0 items graded")
        #expect(NutritionDetailsSections.nutriscoreGradedText(graded: 0, total: 2) == "0 of 2 items graded")
    }
}
