import XCTest
@testable import Caloryn

@MainActor
final class DayExportReportTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let day = makeTestDate(year: 2026, month: 10, day: 22, hour: 0)

    func testMealsFollowTheDayOrderAndSkipMealsWithNothingLogged() {
        let report = makeReport([
            entry(.snack, "Apple", minute: 1),
            entry(.dinner, "Pasta", minute: 2),
            entry(.breakfast, "Oats", minute: 3)
        ])

        XCTAssertEqual(report.meals.map(\.subtotal.label), ["Breakfast", "Dinner", "Snacks"])
    }

    func testSnacksFromEverySnackSlotShareOneSectionInLoggingOrder() {
        let report = makeReport([
            entry(.snack, "Late almonds", minute: 30),
            entry(.snack, "Early apple", minute: 5)
        ])

        XCTAssertEqual(report.meals.count, 1)
        XCTAssertEqual(report.meals[0].foods.map(\.label), ["Early apple", "Late almonds"])
    }

    func testEachFoodRowShowsItsAmountAndMacros() {
        let report = makeReport([
            entry(.breakfast, "Oats", grams: 80.4, calories: 300.4, protein: 10.44, carbs: 54, fat: 5.66)
        ])

        XCTAssertEqual(
            report.meals[0].foods,
            [
                DayExportReport.Row(
                    label: "Oats",
                    amount: "80 g",
                    calories: "300",
                    protein: "10.4 g",
                    carbs: "54 g",
                    fat: "5.7 g"
                )
            ]
        )
    }

    func testMealSubtotalAndDayTotalAddUpTheirFoods() {
        let report = makeReport([
            entry(.lunch, "Rice", calories: 260, protein: 5, carbs: 56, fat: 0.6),
            entry(.lunch, "Chicken", calories: 165.6, protein: 31, carbs: 0, fat: 3.6),
            entry(.dinner, "Salad", calories: 80, protein: 2, carbs: 10, fat: 4)
        ])

        XCTAssertEqual(
            report.meals[0].subtotal,
            DayExportReport.Row(label: "Lunch", amount: "", calories: "426", protein: "36 g", carbs: "56 g", fat: "4.2 g")
        )
        XCTAssertEqual(
            report.total,
            DayExportReport.Row(label: "Total", amount: "", calories: "506", protein: "38 g", carbs: "66 g", fat: "8.2 g")
        )
    }

    func testTargetRowMarksNutrientsWithoutATarget() {
        let report = makeReport(
            [entry(.breakfast, "Oats")],
            targets: DayExportReport.Targets(calories: 2_100, proteinG: 120)
        )

        XCTAssertEqual(
            report.target,
            DayExportReport.Row(label: "Target", amount: "", calories: "2100", protein: "120 g", carbs: "–", fat: "–")
        )
    }

    func testNoTargetRowWithoutAnyTarget() {
        let report = makeReport([entry(.breakfast, "Oats")], targets: DayExportReport.Targets())

        XCTAssertNil(report.target)
    }

    func testAnEmptyDayHasNoMealsAndZeroTotals() {
        let report = makeReport([])

        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(report.total.calories, "0")
        XCTAssertEqual(report.total.protein, "0 g")
    }

    func testNonFiniteNutritionPrintsAsZero() {
        let report = makeReport([
            entry(.breakfast, "Corrupt", grams: .nan, calories: .infinity, protein: .nan, carbs: 1, fat: 1)
        ])

        XCTAssertEqual(report.meals[0].foods[0].amount, "0 g")
        XCTAssertEqual(report.meals[0].foods[0].calories, "0")
        XCTAssertEqual(report.meals[0].foods[0].protein, "0 g")
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
        calories: Double = 100,
        protein: Double = 1,
        carbs: Double = 1,
        fat: Double = 1
    ) -> DayExportReport.Entry {
        DayExportReport.Entry(
            mealType: mealType,
            foodName: name,
            portionGrams: grams,
            macros: DayExportReport.Macros(calories: calories, proteinG: protein, carbsG: carbs, fatG: fat),
            createdAt: day.addingTimeInterval(TimeInterval(minute * 60))
        )
    }
}
