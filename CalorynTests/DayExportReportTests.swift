import XCTest
@testable import Caloryn

@MainActor
final class DayExportReportTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let day = makeTestDate(year: 2026, month: 10, day: 22, hour: 0)

    func testMealsFollowTheTodayScreenOrderAndSkipMealsWithNothingLogged() {
        let report = makeReport([
            entry(.snack, "Apple", minute: 1),
            entry(.dinner, "Pasta", minute: 2),
            entry(.breakfast, "Oats", minute: 3)
        ])

        XCTAssertEqual(report.meals.map(\.title), ["Breakfast", "Snacks", "Dinner"])
        XCTAssertEqual(report.meals.map(\.subtotal.label), ["Breakfast", "Snacks", "Dinner"])
    }

    func testSnacksFromEverySnackSlotShareOneSectionInLoggingOrder() {
        let report = makeReport([
            entry(.snack, "Late almonds", minute: 30),
            entry(.snack, "Early apple", minute: 5)
        ])

        XCTAssertEqual(report.meals.count, 1)
        XCTAssertEqual(report.meals[0].foods.map(\.label), ["Early apple", "Late almonds"])
    }

    func testADayWithOnlyTheCoreNutrientsHasOnlyTheCoreColumns() {
        let report = makeReport([entry(.breakfast, "Oats")])

        XCTAssertEqual(report.columns.map(\.header), [
            "Amount (g)", "Calories (kcal)", "Protein (g)", "Carbs (g)", "Fiber (g)", "Fat (g)"
        ])
    }

    func testEachFoodRowShowsItsAmountAndNutrientsAsPlainNumbers() {
        let report = makeReport([
            entry(.breakfast, "Oats", grams: 80.4, nutrition: NutritionValues(
                calories: 300.4, proteinG: 10.44, carbsG: 54, fatG: 5.66, fiberG: 8.04
            ))
        ])

        XCTAssertEqual(
            report.meals[0].foods,
            [DayExportReport.Row(label: "Oats", cells: ["80", "300", "10.4", "54", "8", "5.7"])]
        )
    }

    func testEveryNutrientAnyFoodRecordsGetsAColumnInNutritionOrder() {
        let report = makeReport([
            entry(.lunch, "Yogurt", nutrition: NutritionValues(calories: 60, lactoseG: 4, saturatedFatG: 2, sodiumG: 0.05)),
            entry(.lunch, "Walnuts", nutrition: NutritionValues(calories: 200, sugarsG: 1, omega3FatG: 2.5, alcoholG: 0))
        ])

        XCTAssertEqual(report.columns.map(\.id), [
            "amount", "calories", "protein", "carbs", "sugars", "lactose", "fiber",
            "fat", "saturated-fat", "omega-3-fat", "sodium", "alcohol"
        ])
        XCTAssertEqual(report.columns.first { $0.id == "sodium" }?.header, "Sodium (mg)")
    }

    func testAFoodThatDoesNotRecordANutrientShowsItAsMissingNotZero() {
        let report = makeReport([
            entry(.lunch, "Yogurt", nutrition: NutritionValues(calories: 60, saturatedFatG: 2)),
            entry(.lunch, "Bread", nutrition: NutritionValues(calories: 250))
        ])

        XCTAssertEqual(report.cell(report.meals[0].foods[0], column: "saturated-fat"), "2")
        XCTAssertEqual(report.cell(report.meals[0].foods[1], column: "saturated-fat"), "–")
        XCTAssertEqual(report.cell(report.meals[0].subtotal, column: "saturated-fat"), "2")
        XCTAssertEqual(report.cell(report.total, column: "saturated-fat"), "2")
    }

    func testAMealWhereNoFoodRecordsANutrientShowsItsSubtotalAsMissing() {
        let report = makeReport([
            entry(.breakfast, "Oats", nutrition: NutritionValues(calories: 300)),
            entry(.dinner, "Cheese", nutrition: NutritionValues(calories: 100, saltG: 0.6))
        ])

        XCTAssertEqual(report.cell(report.meals[0].subtotal, column: "salt"), "–")
        XCTAssertEqual(report.cell(report.meals[1].subtotal, column: "salt"), "0.6")
    }

    func testMilligramNutrientsPrintInMilligramsAndTraceGramsKeepTwoDecimals() {
        let report = makeReport([
            entry(.breakfast, "Egg", nutrition: NutritionValues(
                calories: 70, omega3FatG: 0.04, sodiumG: 0.0704, cholesterolG: 0.186
            ))
        ])
        let egg = report.meals[0].foods[0]

        XCTAssertEqual(report.cell(egg, column: "sodium"), "70")
        XCTAssertEqual(report.cell(egg, column: "cholesterol"), "186")
        XCTAssertEqual(report.cell(egg, column: "omega-3-fat"), "0.04")
    }

    func testNumbersFollowTheLocaleWithoutThousandsSeparators() {
        let report = DayExportReport(
            day: day,
            entries: [entry(.dinner, "Feast", grams: 1_250, nutrition: NutritionValues(calories: 2_345, proteinG: 10.44))],
            targets: DayExportReport.Targets(calories: 2_100),
            locale: Locale(identifier: "el_GR")
        )

        XCTAssertEqual(report.cell(report.meals[0].foods[0], column: "amount"), "1250")
        XCTAssertEqual(report.cell(report.meals[0].foods[0], column: "calories"), "2345")
        XCTAssertEqual(report.cell(report.meals[0].foods[0], column: "protein"), "10,4")
        XCTAssertEqual(report.target.flatMap { report.cell($0, column: "calories") }, "2100")
    }

    func testMealSubtotalAndDayTotalAddUpTheirFoodsIncludingTheAmount() {
        let report = makeReport([
            entry(.lunch, "Rice", grams: 200, nutrition: NutritionValues(calories: 260, proteinG: 5, carbsG: 56, fatG: 0.6)),
            entry(.lunch, "Chicken", grams: 150, nutrition: NutritionValues(calories: 165.6, proteinG: 31, fatG: 3.6)),
            entry(.dinner, "Salad", grams: 120, nutrition: NutritionValues(calories: 80, proteinG: 2, carbsG: 10, fatG: 4))
        ])

        XCTAssertEqual(
            report.meals[0].subtotal,
            DayExportReport.Row(label: "Lunch", cells: ["350", "426", "36", "56", "0", "4.2"])
        )
        XCTAssertEqual(
            report.total,
            DayExportReport.Row(label: "Total", cells: ["470", "506", "38", "66", "0", "8.2"])
        )
    }

    func testTargetRowFillsEveryTrackedNutrientWithATargetAndMarksTheRest() {
        let report = makeReport(
            [entry(.breakfast, "Toast", nutrition: NutritionValues(calories: 90, sodiumG: 0.2))],
            targets: DayExportReport.Targets(
                calories: 2_100,
                nutrients: [.protein: 120, .sodium: 2.3, .fiber: 0]
            )
        )

        XCTAssertEqual(
            report.target,
            DayExportReport.Row(label: "Target", cells: ["–", "2100", "120", "–", "–", "–", "2300"])
        )
    }

    func testANutrientWithAGoalKeepsItsColumnWhenNoFoodRecordsIt() {
        let report = makeReport(
            [entry(.breakfast, "Oats")],
            targets: DayExportReport.Targets(calories: 2_000, nutrients: [.sodium: 2.3, .sugars: 0])
        )

        XCTAssertEqual(report.columns.map(\.id), ["amount", "calories", "protein", "carbs", "fiber", "fat", "sodium"])
        XCTAssertEqual(report.cell(report.meals[0].foods[0], column: "sodium"), "–")
        XCTAssertEqual(report.cell(report.total, column: "sodium"), "–")
        XCTAssertEqual(report.target.flatMap { report.cell($0, column: "sodium") }, "2300")
    }

    func testNoTargetRowWithoutAnyTarget() {
        let report = makeReport([entry(.breakfast, "Oats")], targets: DayExportReport.Targets())

        XCTAssertNil(report.target)
    }

    func testAnEmptyDayHasNoMealsAndZeroTotals() {
        let report = makeReport([])

        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(report.cell(report.total, column: "calories"), "0")
        XCTAssertEqual(report.cell(report.total, column: "protein"), "0")
    }

    func testNonFiniteNutritionPrintsAsZero() {
        let report = makeReport([
            entry(.breakfast, "Corrupt", grams: .nan, nutrition: NutritionValues(calories: .infinity, proteinG: .nan, sugarsG: .nan))
        ])
        let food = report.meals[0].foods[0]

        XCTAssertEqual(report.cell(food, column: "amount"), "0")
        XCTAssertEqual(report.cell(food, column: "calories"), "0")
        XCTAssertEqual(report.cell(food, column: "protein"), "0")
        XCTAssertEqual(report.cell(food, column: "sugars"), "0")
    }

    func testOneNonFiniteEntryDoesNotEraseTheOthersFromTheTotals() {
        let report = makeReport([
            entry(.lunch, "Rice", nutrition: NutritionValues(calories: 300, proteinG: 6, carbsG: 60, fatG: 1)),
            entry(.lunch, "Corrupt", nutrition: NutritionValues(calories: .infinity, proteinG: .nan, carbsG: 1, fatG: 1))
        ])

        XCTAssertEqual(report.cell(report.meals[0].subtotal, column: "calories"), "300")
        XCTAssertEqual(report.cell(report.meals[0].subtotal, column: "protein"), "6")
        XCTAssertEqual(report.cell(report.total, column: "calories"), "300")
        XCTAssertEqual(report.cell(report.total, column: "carbs"), "61")
    }

    func testTitleIncludesTheYearAndFileNameIsSortable() {
        let report = makeReport([entry(.breakfast, "Oats")])

        XCTAssertEqual(report.title, "Thursday, October 22, 2026")
        XCTAssertEqual(report.fileName, "Caloryn 2026-10-22")
    }

    private func makeReport(
        _ entries: [DayExportReport.Entry],
        targets: DayExportReport.Targets = DayExportReport.Targets(calories: 2_000)
    ) -> DayExportReport {
        DayExportReport(day: day, entries: entries, targets: targets, locale: locale)
    }

    private func entry(
        _ mealType: MealType,
        _ name: String,
        minute: Int = 0,
        grams: Double = 100,
        nutrition: NutritionValues = NutritionValues(calories: 100, proteinG: 1, carbsG: 1, fatG: 1)
    ) -> DayExportReport.Entry {
        DayExportReport.Entry(
            mealType: mealType,
            foodName: name,
            portionGrams: grams,
            nutrition: nutrition,
            createdAt: day.addingTimeInterval(TimeInterval(minute * 60))
        )
    }
}
