import Foundation

struct DayExportReport: Equatable {
    struct Macros: Equatable {
        var calories: Double = 0
        var proteinG: Double = 0
        var carbsG: Double = 0
        var fatG: Double = 0

        static func + (lhs: Macros, rhs: Macros) -> Macros {
            Macros(
                calories: DayExportReport.finite(lhs.calories) + DayExportReport.finite(rhs.calories),
                proteinG: DayExportReport.finite(lhs.proteinG) + DayExportReport.finite(rhs.proteinG),
                carbsG: DayExportReport.finite(lhs.carbsG) + DayExportReport.finite(rhs.carbsG),
                fatG: DayExportReport.finite(lhs.fatG) + DayExportReport.finite(rhs.fatG)
            )
        }
    }

    struct Entry {
        let mealType: MealType
        let foodName: String
        let portionGrams: Double
        let macros: Macros
        let createdAt: Date
    }

    struct Targets: Equatable {
        var calories: Int?
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?

        var isEmpty: Bool {
            calories == nil && proteinG == nil && carbsG == nil && fatG == nil
        }
    }

    struct Row: Equatable {
        let label: String
        let amount: String
        let calories: String
        let protein: String
        let carbs: String
        let fat: String

        var numericCells: [String] {
            [amount, calories, protein, carbs, fat]
        }
    }

    struct Meal: Equatable {
        let subtotal: Row
        let foods: [Row]
    }

    static let columnTitles = Row(
        label: "Food",
        amount: "Amount",
        calories: "kcal",
        protein: "Protein",
        carbs: "Carbs",
        fat: "Fat"
    )

    static let mealOrder: [MealType] = [.breakfast, .lunch, .dinner, .snack]
    static let missingValue = "–"

    let title: String
    let fileName: String
    let meals: [Meal]
    let total: Row
    let target: Row?

    var isEmpty: Bool { meals.isEmpty }

    init(
        day: Date,
        entries: [Entry],
        targets: Targets,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) {
        title = day.formatted(
            Date.FormatStyle(
                date: .complete,
                time: .omitted,
                locale: locale,
                calendar: calendar,
                timeZone: calendar.timeZone
            )
        )
        fileName = Self.fileName(for: day, in: calendar)

        let entriesByMeal = Dictionary(grouping: entries, by: \.mealType)
        meals = Self.mealOrder.compactMap { mealType in
            guard let mealEntries = entriesByMeal[mealType], !mealEntries.isEmpty else { return nil }
            let ordered = mealEntries.sorted { $0.createdAt < $1.createdAt }
            let subtotal = ordered.reduce(Macros()) { $0 + $1.macros }
            return Meal(
                subtotal: Self.row(label: Self.title(for: mealType), amount: "", macros: subtotal, locale: locale),
                foods: ordered.map { entry in
                    Self.row(
                        label: entry.foodName,
                        amount: Self.gramsText(entry.portionGrams),
                        macros: entry.macros,
                        locale: locale
                    )
                }
            )
        }

        total = Self.row(
            label: "Total",
            amount: "",
            macros: entries.reduce(Macros()) { $0 + $1.macros },
            locale: locale
        )
        target = targets.isEmpty ? nil : Row(
            label: "Target",
            amount: "",
            calories: targets.calories.map { "\($0)" } ?? Self.missingValue,
            protein: targets.proteinG.map { Self.gramsText($0, locale: locale) } ?? Self.missingValue,
            carbs: targets.carbsG.map { Self.gramsText($0, locale: locale) } ?? Self.missingValue,
            fat: targets.fatG.map { Self.gramsText($0, locale: locale) } ?? Self.missingValue
        )
    }

    static func title(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }

    private static func row(label: String, amount: String, macros: Macros, locale: Locale) -> Row {
        Row(
            label: label,
            amount: amount,
            calories: "\(finite(macros.calories).rounded().truncatedSafely)",
            protein: gramsText(macros.proteinG, locale: locale),
            carbs: gramsText(macros.carbsG, locale: locale),
            fat: gramsText(macros.fatG, locale: locale)
        )
    }

    private static func gramsText(_ grams: Double) -> String {
        "\(finite(grams).rounded().truncatedSafely) g"
    }

    private static func gramsText(_ grams: Double, locale: Locale) -> String {
        finite(grams).spacedMacroFormatted(locale: locale)
    }

    private static func finite(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static func fileName(for day: Date, in calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "Caloryn %04d-%02d-%02d",
            parts.year ?? 0,
            parts.month ?? 0,
            parts.day ?? 0
        )
    }
}
