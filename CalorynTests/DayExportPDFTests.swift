import PDFKit
import XCTest
@testable import Caloryn

@MainActor
final class DayExportPDFTests: XCTestCase {
    private let locale = Locale(identifier: "en_US")
    private let day = makeTestDate(year: 2026, month: 10, day: 22, hour: 0)

    func testTheDayPrintsAsOnePageTableOfMealsFoodsAndTotals() throws {
        let report = makeReport(foodsPerMeal: 2)

        let document = try XCTUnwrap(PDFDocument(data: DayExportPDF.data(for: report)))
        let text = try XCTUnwrap(document.string)

        XCTAssertEqual(document.pageCount, 1)
        for expected in [report.title, "Protein", "Fiber", "Breakfast", "Breakfast food 1", "Snacks", "Total", "Target"] {
            XCTAssertTrue(text.contains(expected), "missing \(expected)")
        }
        XCTAssertTrue(text.contains(try XCTUnwrap(report.cell(report.total, column: "calories"))))
    }

    func testALongDayContinuesOnAnotherPageWithTheColumnTitlesRepeated() throws {
        let report = makeReport(foodsPerMeal: 20)

        let document = try XCTUnwrap(PDFDocument(data: DayExportPDF.data(for: report)))

        XCTAssertGreaterThan(document.pageCount, 1)
        for index in 0..<document.pageCount {
            let pageText = try XCTUnwrap(document.page(at: index)?.string)
            XCTAssertTrue(pageText.contains("Protein"), "page \(index + 1) has no column titles")
        }
        let lastPage = try XCTUnwrap(document.page(at: document.pageCount - 1)?.string)
        XCTAssertTrue(lastPage.contains("Total"))
    }

    func testADayRecordingEveryNutrientPrintsEachOneWithTheFoodsRepeatedBesideThem() throws {
        let report = makeReport(foodsPerMeal: 1, nutrition: Self.everyNutrient)

        let document = try XCTUnwrap(PDFDocument(data: DayExportPDF.data(for: report)))
        let pages = try (0..<document.pageCount).map { try XCTUnwrap(document.page(at: $0)) }
        let text = pages.compactMap(\.string).joined(separator: "\n")

        XCTAssertEqual(report.columns.count, DayExportReport.allColumns.count)
        XCTAssertGreaterThan(pages.count, 1)
        for page in pages {
            let bounds = page.bounds(for: .mediaBox)
            XCTAssertGreaterThan(bounds.width, bounds.height, "a wide table belongs on a landscape page")
            XCTAssertTrue(page.string?.contains("Lunch food 1") == true, "every band names the foods")
        }
        for title in ["Casein", "Lactose", "Polyols", "Omega-9", "Sodium", "Alcohol"] {
            XCTAssertTrue(text.contains(title), "missing \(title)")
        }
    }

    func testFewColumnsStayOnAPortraitPageInOneBand() {
        let layout = DayExportPDF.layout(columnCount: 6, paper: DayExportPDF.a4)

        XCTAssertEqual(layout.pageSize, DayExportPDF.a4)
        XCTAssertEqual(layout.columnBands, [0..<6])
    }

    func testManyColumnsTurnTheSheetAndSplitIntoBalancedBands() {
        let layout = DayExportPDF.layout(columnCount: 31, paper: DayExportPDF.a4)
        let sizes = layout.columnBands.map(\.count)

        XCTAssertEqual(layout.pageSize, CGSize(width: DayExportPDF.a4.height, height: DayExportPDF.a4.width))
        XCTAssertEqual(layout.columnBands.first?.lowerBound, 0)
        XCTAssertEqual(layout.columnBands.last?.upperBound, 31)
        XCTAssertEqual(sizes.reduce(0, +), 31)
        XCTAssertLessThanOrEqual((sizes.max() ?? 0) - (sizes.min() ?? 0), 1)
    }

    func testAnOverlongFoodNameIsCutShortInsteadOfRunningOffThePage() throws {
        let longName = String(repeating: "Homemade granola with oats and honey ", count: 120)
        let report = DayExportReport(
            day: day,
            entries: [
                DayExportReport.Entry(
                    mealType: .breakfast,
                    foodName: longName,
                    portionGrams: 50,
                    nutrition: NutritionValues(calories: 220, proteinG: 5, carbsG: 30, fatG: 8),
                    createdAt: day
                )
            ],
            targets: DayExportReport.Targets(calories: 2_000),
            locale: locale
        )

        let document = try XCTUnwrap(PDFDocument(data: DayExportPDF.data(for: report)))
        let text = try XCTUnwrap(document.string)

        XCTAssertEqual(document.pageCount, 1)
        XCTAssertTrue(text.contains("Total"))
        XCTAssertLessThan(text.count, longName.count)
    }

    func testExportWritesAPDFNamedAfterTheDay() throws {
        let url = try XCTUnwrap(DayExportPDF.exportURL(for: makeReport(foodsPerMeal: 1), locale: locale))

        XCTAssertEqual(url.lastPathComponent, "Caloryn 2026-10-22.pdf")
        XCTAssertNotNil(PDFDocument(url: url))
    }

    func testPaperSizeFollowsTheRegionsMeasurementSystem() {
        XCTAssertEqual(DayExportPDF.pageSize(for: Locale(identifier: "en_US")), DayExportPDF.usLetter)
        XCTAssertEqual(DayExportPDF.pageSize(for: Locale(identifier: "el_GR")), DayExportPDF.a4)
    }

    private static let everyNutrient = NutritionValues(
        calories: 210, proteinG: 12, carbsG: 25, fatG: 7, fiberG: 3,
        sugarsG: 5, addedSugarsG: 1, sucroseG: 1, glucoseG: 1, fructoseG: 1, lactoseG: 1,
        maltoseG: 0.5, maltodextrinsG: 0.5, starchG: 10, polyolsG: 0.2,
        saturatedFatG: 2, transFatG: 0.1, monounsaturatedFatG: 3, polyunsaturatedFatG: 1.5,
        omega3FatG: 0.3, omega6FatG: 1, omega9FatG: 2,
        saltG: 0.5, sodiumG: 0.2, cholesterolG: 0.03,
        solubleFiberG: 1, insolubleFiberG: 2, caseinG: 3, serumProteinsG: 1, alcoholG: 0
    )

    private func makeReport(
        foodsPerMeal: Int,
        nutrition: NutritionValues = NutritionValues(calories: 210, proteinG: 12, carbsG: 25, fatG: 7)
    ) -> DayExportReport {
        let entries = DayExportReport.mealOrder.flatMap { mealType in
            (1...foodsPerMeal).map { index in
                DayExportReport.Entry(
                    mealType: mealType,
                    foodName: "\(DayExportReport.title(for: mealType)) food \(index)",
                    portionGrams: 120,
                    nutrition: nutrition,
                    createdAt: day.addingTimeInterval(TimeInterval(index * 60))
                )
            }
        }
        return DayExportReport(
            day: day,
            entries: entries,
            targets: DayExportReport.Targets(calories: 2_000, nutrients: [.protein: 120, .carbs: 250, .fat: 70]),
            locale: locale
        )
    }
}
