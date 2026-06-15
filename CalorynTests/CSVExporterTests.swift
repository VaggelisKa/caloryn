import XCTest
@testable import Caloryn

@MainActor
final class CSVExporterTests: XCTestCase {
    func testGenerateCSVSortsEntriesAndFormatsMealAndNutritionFields() {
        let later = makeTestEntry(
            date: makeTestDate(year: 2026, month: 1, day: 3),
            mealType: .dinner,
            foodItem: makeTestFoodItem(
                name: "Rice Bowl",
                caloriesPer100g: 130,
                proteinPer100g: 4,
                carbsPer100g: 28,
                fatPer100g: 1,
                fiberPer100g: 1.5
            ),
            portionGrams: 200
        )
        let earlier = makeTestEntry(
            date: makeTestDate(year: 2026, month: 1, day: 2),
            mealType: .snack,
            foodItem: makeTestFoodItem(
                name: "Greek Yogurt, Honey",
                caloriesPer100g: 100,
                proteinPer100g: 10,
                carbsPer100g: 8,
                fatPer100g: 3,
                fiberPer100g: 0
            ),
            portionGrams: 150,
            snackIndex: 2
        )

        let csv = CSVExporter.generateCSV(from: [later, earlier])

        XCTAssertEqual(
            csv,
            """
            Date,Meal,Food,Portion (g),Calories,Protein (g),Carbs (g),Fat (g),Fiber (g)
            2026-01-02,Snack 2,Greek Yogurt; Honey,150,150,15.0,12.0,4.5,0.0
            2026-01-03,Dinner,Rice Bowl,200,260,8.0,56.0,2.0,3.0

            """
        )
    }

    func testExportURLWritesGeneratedCSVToTemporaryFile() throws {
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 3, day: 4),
            foodItem: makeTestFoodItem(name: "Oats"),
            portionGrams: 100
        )

        let url = try XCTUnwrap(CSVExporter.exportURL(from: [entry]))
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.lastPathComponent, "Caloryn_Export.csv")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let csv = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(csv.contains("2026-03-04,Breakfast,Oats,100,100,10.0,20.0,5.0,0.0"))
    }
}
