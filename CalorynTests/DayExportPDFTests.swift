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
        for expected in [report.title, "Protein", "Breakfast", "Breakfast food 1", "Snacks", "Total", "Target"] {
            XCTAssertTrue(text.contains(expected), "missing \(expected)")
        }
        XCTAssertTrue(text.contains(report.total.calories))
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

    func testExportWritesAPDFNamedAfterTheDay() throws {
        let url = try XCTUnwrap(DayExportPDF.exportURL(for: makeReport(foodsPerMeal: 1), locale: locale))

        XCTAssertEqual(url.lastPathComponent, "Caloryn 2026-10-22.pdf")
        XCTAssertNotNil(PDFDocument(url: url))
    }

    func testPaperSizeFollowsTheRegionsMeasurementSystem() {
        XCTAssertEqual(DayExportPDF.pageSize(for: Locale(identifier: "en_US")), DayExportPDF.usLetter)
        XCTAssertEqual(DayExportPDF.pageSize(for: Locale(identifier: "el_GR")), DayExportPDF.a4)
    }

    private func makeReport(foodsPerMeal: Int) -> DayExportReport {
        let entries = DayExportReport.mealOrder.flatMap { mealType in
            (1...foodsPerMeal).map { index in
                DayExportReport.Entry(
                    mealType: mealType,
                    foodName: "\(DayExportReport.title(for: mealType)) food \(index)",
                    portionGrams: 120,
                    macros: DayExportReport.Macros(calories: 210, proteinG: 12, carbsG: 25, fatG: 7),
                    createdAt: day.addingTimeInterval(TimeInterval(index * 60))
                )
            }
        }
        return DayExportReport(
            day: day,
            entries: entries,
            targets: DayExportReport.Targets(calories: 2_000, proteinG: 120, carbsG: 250, fatG: 70),
            locale: locale
        )
    }
}
