import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import Caloryn

@MainActor
final class DayExportTableTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let day = makeTestDate(year: 2026, month: 10, day: 22, hour: 0)

    func testTabSeparatedTextIsTheTitleThenOneRowPerFoodTaggedWithItsMeal() {
        let report = makeReport([
            entry(.breakfast, "Oats", grams: 80, NutritionValues(calories: 300, proteinG: 10, carbsG: 54, fatG: 5.5, fiberG: 8)),
            entry(.dinner, "Salmon", grams: 150, NutritionValues(calories: 310, proteinG: 30, fatG: 20, saltG: 0.2))
        ])

        XCTAssertEqual(
            DayExportTable.tabSeparated(report),
            [
                "Thursday, October 22, 2026",
                "Meal\tFood\tAmount (g)\tCalories (kcal)\tProtein (g)\tCarbs (g)\tFiber (g)\tFat (g)\tSalt (g)",
                "Breakfast\tOats\t80\t300\t10\t54\t8\t5.5\t–",
                "Breakfast\tSubtotal\t80\t300\t10\t54\t8\t5.5\t–",
                "Dinner\tSalmon\t150\t310\t30\t0\t0\t20\t0.2",
                "Dinner\tSubtotal\t150\t310\t30\t0\t0\t20\t0.2",
                "\tTotal\t230\t610\t40\t54\t8\t25.5\t0.2",
                "\tTarget\t–\t2000\t120\t–\t–\t–\t–",
                ""
            ].joined(separator: "\n")
        )
    }

    func testAFoodNameCannotBreakARowOrRunAsASpreadsheetFormula() {
        let report = makeReport([
            entry(.lunch, "Soup\twith\nbread", grams: 300, NutritionValues(calories: 200)),
            entry(.lunch, "=HYPERLINK(\"x\")", grams: 10, NutritionValues(calories: 1))
        ])

        let lines = DayExportTable.tabSeparated(report).split(separator: "\n")

        XCTAssertTrue(lines.contains { $0.hasPrefix("Lunch\tSoup with bread\t300\t") })
        XCTAssertTrue(lines.contains { $0.hasPrefix("Lunch\t'=HYPERLINK(\"x\")\t10\t") })
        XCTAssertEqual(Set(lines.dropFirst().map { $0.split(separator: "\t", omittingEmptySubsequences: false).count }).count, 1)
    }

    func testHTMLIsATableWithTheSameRowsAndEscapedNames() {
        let report = makeReport([entry(.snack, "Fish & <Chips>", grams: 200, NutritionValues(calories: 500))])

        let html = DayExportTable.html(report)

        XCTAssertTrue(html.contains("<b>Thursday, October 22, 2026</b>"))
        XCTAssertTrue(html.contains("<th>Calories (kcal)</th>"))
        XCTAssertTrue(html.contains("<td>Snacks</td><td>Fish &amp; &lt;Chips&gt;</td><td>200</td><td>500</td>"))
        XCTAssertTrue(html.contains("<td><b>Total</b></td>"))
        XCTAssertFalse(html.contains("<Chips>"))
    }

    func testCopyPutsTheTableOnThePasteboardAsTextAndAsHTML() throws {
        let pasteboard = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        let report = makeReport([entry(.breakfast, "Oats", grams: 80, NutritionValues(calories: 300))])

        DayExportTable.copy(report, to: pasteboard)

        XCTAssertEqual(pasteboard.string, DayExportTable.tabSeparated(report))
        let html = try XCTUnwrap(pasteboard.data(forPasteboardType: UTType.html.identifier))
        XCTAssertEqual(String(data: html, encoding: .utf8), DayExportTable.html(report))
    }

    private func makeReport(_ entries: [DayExportReport.Entry]) -> DayExportReport {
        DayExportReport(
            day: day,
            entries: entries,
            targets: DayExportReport.Targets(calories: 2_000, nutrients: [.protein: 120]),
            locale: locale
        )
    }

    private func entry(
        _ mealType: MealType,
        _ name: String,
        grams: Double,
        _ nutrition: NutritionValues
    ) -> DayExportReport.Entry {
        DayExportReport.Entry(mealType: mealType, foodName: name, portionGrams: grams, nutrition: nutrition, createdAt: day)
    }
}
