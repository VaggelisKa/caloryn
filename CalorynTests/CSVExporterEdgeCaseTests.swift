import Testing
import Foundation
@testable import Caloryn

/// Edge-case coverage for `Caloryn/Services/CSVExporter.swift`.
///
/// `CSVExporterTests.swift` already covers the happy path (sorting, meal
/// naming, basic comma escaping, file export). This file focuses on the
/// bug classes most likely to bite a multilingual, European user base:
/// commas, quotes, newlines, emoji, and accented characters in food names;
/// empty/large logs; and numeric-formatting edge cases in the exported
/// columns.
@MainActor
struct CSVExporterEdgeCaseTests {

    private static let header = "Date,Meal,Food,Portion (g),Calories,Protein (g),Carbs (g),Fat (g),Fiber (g)"

    /// Splits a generated CSV blob into its non-empty physical lines.
    private func physicalLines(of csv: String) -> [String] {
        csv.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    /// Naive column count for a single CSV line (this exporter never quotes
    /// fields, so a plain comma split is the correct oracle for its output).
    private func columnCount(of line: String) -> Int {
        line.split(separator: ",", omittingEmptySubsequences: false).count
    }

    // MARK: - Empty / single / large logs

    @Test("An empty log produces only the header row, with no trailing data lines")
    func emptyLogProducesOnlyHeaderRow() {
        let csv = CSVExporter.generateCSV(from: [])
        #expect(csv == Self.header + "\n")
        #expect(physicalLines(of: csv) == [Self.header])
    }

    @Test("A single entry produces exactly one header line and one data line")
    func singleEntryProducesHeaderPlusOneDataLine() {
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 6, day: 15),
            foodItem: makeTestFoodItem(name: "Oats"),
            portionGrams: 100
        )

        let csv = CSVExporter.generateCSV(from: [entry])
        let lines = physicalLines(of: csv)

        #expect(lines.count == 2)
        #expect(lines[0] == Self.header)
        #expect(lines[1] == "2026-06-15,Breakfast,Oats,100,100,10.0,20.0,5.0,0.0")
    }

    @Test("A large log preserves one data line per entry, ascending-date sorted, with no dropped or merged rows")
    func largeLogPreservesLineCountAndSortOrder() {
        let base = makeTestDate(year: 2026, month: 1, day: 1)
        let calendar = Calendar.current
        // Build 500 entries in reverse-chronological insertion order so a
        // correct sort is actually exercised, not just a stable no-op.
        let entries = (0..<500).map { offset -> FoodLogEntry in
            let date = calendar.date(byAdding: .day, value: -offset, to: base) ?? base
            return makeTestEntry(
                date: date,
                foodItem: makeTestFoodItem(name: "Food \(offset)"),
                portionGrams: 100
            )
        }

        let csv = CSVExporter.generateCSV(from: entries)
        let lines = physicalLines(of: csv)

        #expect(lines.count == 501)
        let dataLines = lines.dropFirst()
        let dates = dataLines.map { String($0.prefix(10)) }
        #expect(dates == dates.sorted())
        #expect(dates.first == "2024-08-20") // base minus 499 days
        #expect(dates.last == "2026-01-01")
    }

    @Test("Entries created before the food-quality snapshot fields existed (legacy entries) still export correctly")
    func legacyEntryWithNilSnapshotFieldsExportsCorrectly() {
        let entry = makeLegacyTestEntry(
            date: makeTestDate(year: 2026, month: 2, day: 1),
            foodItem: makeTestFoodItem(
                name: "Legacy Food",
                caloriesPer100g: 200,
                proteinPer100g: 8,
                carbsPer100g: 30,
                fatPer100g: 6,
                fiberPer100g: 2
            ),
            portionGrams: 50
        )
        #expect(entry.produceKindSnapshotRaw == nil)

        let csv = CSVExporter.generateCSV(from: [entry])

        #expect(csv.contains("2026-02-01,Breakfast,Legacy Food,50,100,4.0,15.0,3.0,1.0"))
    }

    // MARK: - Special characters in food names

    @Test("A comma in the food name is replaced with a semicolon, keeping the row's column count intact")
    func commaInFoodNameIsReplacedWithSemicolonPreservingColumnCount() {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: "Rice, Beans, and Corn"))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        #expect(columnCount(of: dataLine) == 9)
        #expect(dataLine.contains("Rice; Beans; and Corn"))
        #expect(!dataLine.contains("Rice,"))
    }

    @Test("Double quotes in the food name pass through completely unescaped")
    func doubleQuotesPassThroughUnescaped() {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: "\"Half Baked\" Ice Cream"))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        // No quoting/escaping logic exists in CSVExporter, so the quote
        // characters are written through verbatim.
        #expect(dataLine.contains("\"Half Baked\" Ice Cream"))
        #expect(columnCount(of: dataLine) == 9)
    }

    @Test("An apostrophe (single quote) in the food name passes through unescaped and does not affect column count")
    func apostropheInFoodNamePassesThroughUnescaped() {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: "Ben & Jerry's"))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        #expect(dataLine.contains("Ben & Jerry's"))
        #expect(columnCount(of: dataLine) == 9)
    }

    @Test("A semicolon already present in the food name passes through unescaped since the delimiter is a comma")
    func semicolonInFoodNamePassesThroughUnescaped() {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: "Salt; Pepper Mix"))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        #expect(dataLine.contains("Salt; Pepper Mix"))
        #expect(columnCount(of: dataLine) == 9)
    }

    @Test("Emoji in the food name are preserved byte-for-byte and do not disturb column parsing")
    func emojiInFoodNamePreservedAndDoesNotDisturbColumns() {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: "🍕 Pizza Margherita 🇮🇹"))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        #expect(dataLine.contains("🍕 Pizza Margherita 🇮🇹"))
        #expect(columnCount(of: dataLine) == 9)
    }

    @Test(
        "Accented and non-ASCII food names (multilingual Open Food Facts data) round-trip unchanged",
        arguments: [
            "Café au Lait",
            "Crème brûlée",
            "Müsli mit Früchten",
            "Χωριάτικη Σαλάτα",
            "Æblekage",
        ]
    )
    func accentedAndNonASCIIFoodNamesRoundTripUnchanged(name: String) {
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: name))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        #expect(dataLine.contains(name))
        #expect(columnCount(of: dataLine) == 9)
    }

    @Test("A newline embedded in a food name is NOT escaped or quoted, so it splits one logical row into extra physical lines")
    func newlineInFoodNameBreaksLogicalRowIntoExtraPhysicalLines() {
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 4, day: 1),
            foodItem: makeTestFoodItem(name: "Multi\nLine Snack"),
            portionGrams: 100
        )

        let csv = CSVExporter.generateCSV(from: [entry])
        let lines = physicalLines(of: csv)

        // A well-formed CSV would still have exactly 2 physical lines
        // (header + 1 data row) with the newline quoted inside the field.
        // Because CSVExporter performs no quoting at all, the embedded
        // newline corrupts the row into two separate physical lines with
        // broken column counts -- a genuine parseability bug.
        #expect(lines.count == 3)
        #expect(lines[1] == "2026-04-01,Breakfast,Multi")
        #expect(lines[2] == "Line Snack,100,100,10.0,20.0,5.0,0.0")
        #expect(columnCount(of: lines[1]) != 9)
    }

    @Test("The spec example (comma, quotes, apostrophe together) is transformed, not fully preserved verbatim")
    func combinedSpecialCharacterExampleIsTransformedNotPreservedVerbatim() {
        let original = "Ben & Jerry's \"Half Baked\", 500ml"
        let entry = makeTestEntry(foodItem: makeTestFoodItem(name: original))
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]

        // The comma is destructively replaced with a semicolon (not quoted),
        // so the exported field is NOT byte-identical to the original name.
        #expect(dataLine.contains("Ben & Jerry's \"Half Baked\"; 500ml"))
        #expect(!dataLine.contains(original))
        #expect(columnCount(of: dataLine) == 9)
    }

    // MARK: - Numeric column formatting edge cases

    @Test("Portion and calorie columns round using printf-style .0f rounding, including the round-half-to-even quirk at .5")
    func portionAndCalorieColumnsUseZeroDecimalRounding() {
        let entry = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Half Point", caloriesPer100g: 2.5, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0),
            portionGrams: 100
        )
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]
        let fields = dataLine.split(separator: ",", omittingEmptySubsequences: false)

        // 2.5 calories at %.0f resolves to "2" (round-half-to-even), not "3".
        #expect(fields[4] == "2")
    }

    @Test("Macro columns can show a floating-point .1f rounding surprise: 12.25 renders as 12.2, not 12.3")
    func macroColumnsCanRoundDownAtExactHalfDecimalDueToBinaryFloatingPoint() {
        let entry = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Precise Protein", caloriesPer100g: 0, proteinPer100g: 12.25, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0),
            portionGrams: 100
        )
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]
        let fields = dataLine.split(separator: ",", omittingEmptySubsequences: false)

        #expect(fields[5] == "12.2")
    }

    @Test("Large calorie totals render as plain digits with no thousands-grouping separator that would corrupt the CSV")
    func largeCalorieTotalsHaveNoGroupingSeparator() {
        let entry = makeTestEntry(
            foodItem: makeTestFoodItem(name: "Huge Meal", caloriesPer100g: 9000, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 0, fiberPer100g: 0),
            portionGrams: 1000
        )
        let csv = CSVExporter.generateCSV(from: [entry])
        let dataLine = physicalLines(of: csv)[1]
        let fields = dataLine.split(separator: ",", omittingEmptySubsequences: false)

        #expect(fields[4] == "90000")
        #expect(columnCount(of: dataLine) == 9)
    }

    // MARK: - exportURL file round-trip

    @Test("exportURL writes a CSV file whose contents contain names with special characters intact")
    func exportURLWritesSpecialCharacterNamesToFile() throws {
        let entry = makeTestEntry(
            date: makeTestDate(year: 2026, month: 5, day: 20),
            foodItem: makeTestFoodItem(name: "Crème brûlée, Café"),
            portionGrams: 80
        )

        let url = try #require(CSVExporter.exportURL(from: [entry]))
        defer { try? FileManager.default.removeItem(at: url) }

        let fileContents = try String(contentsOf: url, encoding: .utf8)
        #expect(fileContents.contains("Crème brûlée; Café"))
    }

    @Test("exportURL for an empty log still writes a valid file containing only the header")
    func exportURLForEmptyLogWritesHeaderOnlyFile() throws {
        let url = try #require(CSVExporter.exportURL(from: []))
        defer { try? FileManager.default.removeItem(at: url) }

        let fileContents = try String(contentsOf: url, encoding: .utf8)
        #expect(fileContents == Self.header + "\n")
    }
}
