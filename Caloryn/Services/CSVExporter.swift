import Foundation

enum CSVExporter {
    private static let formulaTriggers: Set<Unicode.Scalar> = ["=", "+", "-", "@", "\t", "\r"]

    static func neutralised(_ field: String) -> String {
        guard let first = field.unicodeScalars.first, formulaTriggers.contains(first) else { return field }
        return "'" + field
    }

    private static func escaped(_ field: String) -> String {
        let field = neutralised(field)
        // `isNewline`, not `== "\n" || == "\r"`: "\r\n" is one Character and equals neither.
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func generateCSV(from entries: [FoodLogEntry]) -> String {
        let recorded = DayExportReport.optionalNutrients.filter { nutrient in
            entries.contains { $0.nutrition[keyPath: nutrient.keyPath] != nil }
        }
        var csv = "Date,Meal,Food,Portion (g),Calories,Protein (g),Carbs (g),Fat (g),Fiber (g)"
            + recorded.map { "," + $0.column.header }.joined()
            + "\n"

        let sorted = entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            if lhs.mealType.sortOrder != rhs.mealType.sortOrder {
                return lhs.mealType.sortOrder < rhs.mealType.sortOrder
            }
            return lhs.createdAt < rhs.createdAt
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for entry in sorted {
            let date = formatter.string(from: entry.date)
            let meal = escaped(entry.mealType == .snack
                ? entry.mealType.displayName(snackIndex: entry.snackIndex)
                : entry.mealType.displayName)
            let food = escaped(entry.foodName)
            let portion = String(format: "%.0f", entry.portionGrams)
            let cal = String(format: "%.0f", entry.calories)
            let protein = String(format: "%.1f", entry.proteinG)
            let carbs = String(format: "%.1f", entry.carbsG)
            let fat = String(format: "%.1f", entry.fatG)
            let fiber = String(format: "%.1f", entry.fiberG)

            let extras = recorded.map { nutrient in
                "," + optionalValue(entry.nutrition[keyPath: nutrient.keyPath], unit: nutrient.column.unit)
            }.joined()

            csv += "\(date),\(meal),\(food),\(portion),\(cal),\(protein),\(carbs),\(fat),\(fiber)\(extras)\n"
        }

        return csv
    }

    private static func optionalValue(_ value: Double?, unit: DayExportReport.Unit) -> String {
        guard let value, value.isFinite else { return "" }
        switch unit {
        case .milligrams:
            return String(format: "%.0f", value * 1000)
        case .wholeGrams, .kilocalories:
            return String(format: "%.0f", value)
        case .grams:
            return String(format: abs(value) < 1 ? "%.2f" : "%.1f", value)
        }
    }

    static func exportURL(from entries: [FoodLogEntry], fileName: String = "Caloryn_Export") -> URL? {
        let csv = generateCSV(from: entries)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName).appendingPathExtension("csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
