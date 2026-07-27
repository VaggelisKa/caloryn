import Foundation

enum CSVExporter {
    /// Quotes a field per RFC 4180, so the value survives the round trip.
    ///
    /// Only fields that would otherwise break the format are quoted, which
    /// keeps the common case — a plain food name — byte-identical to what
    /// this exporter has always produced.
    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func generateCSV(from entries: [FoodLogEntry]) -> String {
        var csv = "Date,Meal,Food,Portion (g),Calories,Protein (g),Carbs (g),Fat (g),Fiber (g)\n"

        let sorted = entries.sorted { $0.date < $1.date }

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

            csv += "\(date),\(meal),\(food),\(portion),\(cal),\(protein),\(carbs),\(fat),\(fiber)\n"
        }

        return csv
    }

    static func exportURL(from entries: [FoodLogEntry]) -> URL? {
        let csv = generateCSV(from: entries)
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Caloryn_Export.csv")

        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
