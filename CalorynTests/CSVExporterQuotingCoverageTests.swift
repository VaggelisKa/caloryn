import Foundation
import Testing
@testable import Caloryn

/// Quoting cases `CSVExporterEdgeCaseTests` leaves out: carriage returns, a field that is
/// nothing but a quote, separators at the edges of a name, and snack meal labels.
@MainActor
@Suite("CSV exporter quoting round trips")
struct CSVExporterQuotingCoverageTests {

    @Test(
        "Names that would break a row are quoted and parse back verbatim",
        arguments: [
            "Carriage\rReturn",
            "\"",
            "\"\"",
            ",",
            ",leading comma",
            "trailing comma,",
            "\"quoted\"",
            "a,\"b\",\nc",
        ]
    )
    func breakingNamesRoundTrip(name: String) throws {
        let csv = CSVExporter.generateCSV(from: [makeTestEntry(foodItem: makeTestFoodItem(name: name))])
        let records = parsedRecords(csv)

        #expect(records.count == 2)
        let fields = try #require(records.last)
        #expect(fields.count == 9)
        #expect(fields[2] == name)
        #expect(csv.contains("\"" + name.replacingOccurrences(of: "\"", with: "\"\"") + "\""))
    }

    /// "\r\n" is a single `Character` in Swift, so a per-character check for "\r" or "\n"
    /// alone never matches it.
    @Test("A CRLF inside a name is quoted and keeps the row whole")
    func crlfInNameIsQuoted() {
        let name = "Line\r\nBreak"
        let csv = CSVExporter.generateCSV(from: [makeTestEntry(foodItem: makeTestFoodItem(name: name))])

        #expect(csv.contains(",\"Line\r\nBreak\","))
        #expect(parsedRecords(csv).count == 2)
    }

    @Test("A plain name is written through byte for byte, without quotes")
    func plainNameIsNotQuoted() {
        let csv = CSVExporter.generateCSV(from: [makeTestEntry(foodItem: makeTestFoodItem(name: "Rolled Oats"))])
        #expect(csv.contains(",Rolled Oats,"))
        #expect(csv.contains("\"") == false)
    }

    @Test("A snack's column names which snack it was")
    func snackMealLabel() throws {
        let entries = [
            makeTestEntry(date: makeTestDate(year: 2026, month: 3, day: 1), mealType: .snack, foodItem: makeTestFoodItem(name: "Apple"), snackIndex: 1),
            makeTestEntry(date: makeTestDate(year: 2026, month: 3, day: 2), mealType: .snack, foodItem: makeTestFoodItem(name: "Nuts"), snackIndex: 3),
        ]
        let records = parsedRecords(CSVExporter.generateCSV(from: entries))

        #expect(records.count == 3)
        #expect(records.dropFirst().map { $0[1] } == ["Snack 1", "Snack 3"])
        #expect(records.dropFirst().map { $0[2] } == ["Apple", "Nuts"])
    }

    @Test("Every meal type's label is a bare field: none needs quoting", arguments: [MealType.breakfast, .lunch, .dinner])
    func mealLabelsAreBare(meal: MealType) {
        let csv = CSVExporter.generateCSV(from: [makeTestEntry(mealType: meal, foodItem: makeTestFoodItem(name: "Food"))])
        #expect(csv.contains(",\(meal.displayName),Food,"))
    }

    @Test("Numeric columns never carry a locale's decimal comma, which would shift every column")
    func numericColumnsUsePoint() throws {
        let food = makeTestFoodItem(name: "Skyr", caloriesPer100g: 63, proteinPer100g: 11, carbsPer100g: 4, fatPer100g: 0.2, fiberPer100g: 0)
        let csv = CSVExporter.generateCSV(from: [makeTestEntry(foodItem: food, portionGrams: 150)])
        let fields = try #require(parsedRecords(csv).last)

        #expect(Array(fields.dropFirst(3)) == ["150", "94", "16.5", "6.0", "0.3", "0.0"])
    }

    // MARK: - RFC 4180 reader

    private func parsedRecords(_ csv: String) -> [[String]] {
        var records: [[String]] = []
        var fields: [String] = []
        var field = ""
        var inQuotes = false
        let characters = Array(csv.unicodeScalars)
        var index = 0
        while index < characters.count {
            let scalar = characters[index]
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < characters.count, characters[index + 1] == "\"" {
                        field.unicodeScalars.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(scalar)
                }
            } else {
                switch scalar {
                case "\"": inQuotes = true
                case ",": fields.append(field); field = ""
                case "\n": fields.append(field); records.append(fields); fields = []; field = ""
                default: field.unicodeScalars.append(scalar)
                }
            }
            index += 1
        }
        if !field.isEmpty || !fields.isEmpty {
            fields.append(field)
            records.append(fields)
        }
        return records
    }
}
