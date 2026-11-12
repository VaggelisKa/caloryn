import Foundation

struct DayExportReport: Equatable {
    struct Entry {
        let mealType: MealType
        let foodName: String
        let portionGrams: Double
        let nutrition: NutritionValues
        let createdAt: Date
    }

    struct Targets: Equatable {
        var calories: Int?
        var nutrients: [TrackedNutrient: Double] = [:]

        var isEmpty: Bool {
            calories == nil && nutrients.isEmpty
        }
    }

    enum Unit: Equatable {
        case wholeGrams
        case grams
        case milligrams
        case kilocalories

        var symbol: String {
            switch self {
            case .wholeGrams, .grams:
                "g"
            case .milligrams:
                "mg"
            case .kilocalories:
                "kcal"
            }
        }
    }

    struct Column: Equatable, Identifiable {
        let id: String
        let title: String
        let compactTitle: String
        let unit: Unit

        var header: String { "\(title) (\(unit.symbol))" }
    }

    struct Row: Equatable {
        let label: String
        let cells: [String]
    }

    struct Meal: Equatable {
        let title: String
        let subtotal: Row
        let foods: [Row]
    }

    static let mealColumnTitle = "Meal"
    static let foodColumnTitle = "Food"
    static let mealOrder: [MealType] = DayFoodLogSelection.dayMeals
    static let missingValue = "–"

    static var allColumns: [Column] { measures.map(\.column) }

    static var optionalNutrients: [(column: Column, keyPath: KeyPath<NutritionValues, Double?>)] {
        measures.compactMap { measure in measure.keyPath.map { (measure.column, $0) } }
    }

    let title: String
    let fileName: String
    let columns: [Column]
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

        let measures = Self.measures.filter { measure in
            measure.isAlwaysShown
                || entries.contains { measure.value($0) != nil }
                || Self.targetValue(for: measure, in: targets) != nil
        }
        columns = measures.map(\.column)

        func row(_ label: String, _ group: [Entry]) -> Row {
            Row(
                label: label,
                cells: measures.map { measure in
                    let values = group.compactMap(measure.value)
                    guard !values.isEmpty || measure.isAlwaysShown else { return Self.missingValue }
                    return Self.format(values.reduce(0) { $0 + Self.finite($1) }, unit: measure.column.unit, locale: locale)
                }
            )
        }

        let entriesByMeal = Dictionary(grouping: entries, by: \.mealType)
        meals = Self.mealOrder.compactMap { mealType in
            guard let mealEntries = entriesByMeal[mealType], !mealEntries.isEmpty else { return nil }
            let ordered = mealEntries.sorted { $0.createdAt < $1.createdAt }
            let mealTitle = Self.title(for: mealType)
            return Meal(
                title: mealTitle,
                subtotal: row(mealTitle, ordered),
                foods: ordered.map { row($0.foodName, [$0]) }
            )
        }

        total = row("Total", entries)
        target = targets.isEmpty ? nil : Row(
            label: "Target",
            cells: measures.map { measure in
                guard let value = Self.targetValue(for: measure, in: targets) else { return Self.missingValue }
                return Self.format(value, unit: measure.column.unit, locale: locale)
            }
        )
    }

    func cell(_ row: Row, column id: String) -> String? {
        columns.firstIndex { $0.id == id }.map { row.cells[$0] }
    }

    static func title(for mealType: MealType) -> String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }

    private struct Measure {
        let column: Column
        let isAlwaysShown: Bool
        let tracked: TrackedNutrient?
        let keyPath: KeyPath<NutritionValues, Double?>?
        let value: (Entry) -> Double?

        init(
            _ id: String,
            _ title: String,
            compact: String? = nil,
            unit: Unit = .grams,
            alwaysShown: Bool = false,
            tracked: TrackedNutrient? = nil,
            keyPath: KeyPath<NutritionValues, Double?>? = nil,
            value: @escaping (Entry) -> Double?
        ) {
            column = Column(id: id, title: title, compactTitle: compact ?? title, unit: unit)
            isAlwaysShown = alwaysShown
            self.tracked = tracked
            self.keyPath = keyPath
            self.value = value
        }

        init(
            _ id: String,
            _ title: String,
            compact: String? = nil,
            unit: Unit = .grams,
            tracked: TrackedNutrient? = nil,
            nutrient keyPath: KeyPath<NutritionValues, Double?>
        ) {
            self.init(id, title, compact: compact, unit: unit, tracked: tracked, keyPath: keyPath) {
                $0.nutrition[keyPath: keyPath]
            }
        }
    }

    private static let measures: [Measure] = [
        Measure("amount", "Amount", unit: .wholeGrams, alwaysShown: true) { $0.portionGrams },
        Measure("calories", "Calories", unit: .kilocalories, alwaysShown: true) { $0.nutrition.calories },
        Measure("protein", "Protein", alwaysShown: true, tracked: .protein) { $0.nutrition.proteinG },
        Measure("casein", "Casein", nutrient: \.caseinG),
        Measure("serum-proteins", "Serum proteins", compact: "Serum prot.", nutrient: \.serumProteinsG),
        Measure("carbs", "Carbs", alwaysShown: true, tracked: .carbs) { $0.nutrition.carbsG },
        Measure("sugars", "Sugars", tracked: .sugars, nutrient: \.sugarsG),
        Measure("added-sugars", "Added sugars", tracked: .addedSugars, nutrient: \.addedSugarsG),
        Measure("sucrose", "Sucrose", nutrient: \.sucroseG),
        Measure("glucose", "Glucose", nutrient: \.glucoseG),
        Measure("fructose", "Fructose", nutrient: \.fructoseG),
        Measure("lactose", "Lactose", nutrient: \.lactoseG),
        Measure("maltose", "Maltose", nutrient: \.maltoseG),
        Measure("maltodextrins", "Maltodextrins", nutrient: \.maltodextrinsG),
        Measure("starch", "Starch", nutrient: \.starchG),
        Measure("polyols", "Polyols", nutrient: \.polyolsG),
        Measure("fiber", "Fiber", alwaysShown: true, tracked: .fiber) { $0.nutrition.fiberG },
        Measure("soluble-fiber", "Soluble fiber", nutrient: \.solubleFiberG),
        Measure("insoluble-fiber", "Insoluble fiber", nutrient: \.insolubleFiberG),
        Measure("fat", "Fat", alwaysShown: true, tracked: .fat) { $0.nutrition.fatG },
        Measure("saturated-fat", "Saturated fat", compact: "Sat. fat", tracked: .saturatedFat, nutrient: \.saturatedFatG),
        Measure("trans-fat", "Trans fat", nutrient: \.transFatG),
        Measure("monounsaturated-fat", "Monounsaturated fat", compact: "Mono fat", nutrient: \.monounsaturatedFatG),
        Measure("polyunsaturated-fat", "Polyunsaturated fat", compact: "Poly fat", nutrient: \.polyunsaturatedFatG),
        Measure("omega-3-fat", "Omega-3 fat", compact: "Omega-3", nutrient: \.omega3FatG),
        Measure("omega-6-fat", "Omega-6 fat", compact: "Omega-6", nutrient: \.omega6FatG),
        Measure("omega-9-fat", "Omega-9 fat", compact: "Omega-9", nutrient: \.omega9FatG),
        Measure("cholesterol", "Cholesterol", unit: .milligrams, tracked: .cholesterol, nutrient: \.cholesterolG),
        Measure("salt", "Salt", nutrient: \.saltG),
        Measure("sodium", "Sodium", unit: .milligrams, tracked: .sodium, nutrient: \.sodiumG),
        Measure("alcohol", "Alcohol", tracked: .alcohol, nutrient: \.alcoholG)
    ]

    private static func targetValue(for measure: Measure, in targets: Targets) -> Double? {
        let value = measure.column.id == "calories"
            ? targets.calories.map(Double.init)
            : measure.tracked.flatMap { targets.nutrients[$0] }
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    private static func format(_ value: Double, unit: Unit, locale: Locale) -> String {
        let whole = IntegerFormatStyle<Int>.number.locale(locale).grouping(.never)
        switch unit {
        case .wholeGrams, .kilocalories:
            return value.rounded().truncatedSafely.formatted(whole)
        case .milligrams:
            return (value * 1000).rounded().truncatedSafely.formatted(whole)
        case .grams:
            let digits = abs(value) < 1 ? 2 : 1
            let scale = pow(10, Double(digits))
            let rounded = (value * scale).rounded() / scale
            return (rounded == 0 ? 0 : rounded).formatted(
                FloatingPointFormatStyle<Double>.number.locale(locale).grouping(.never).precision(.fractionLength(0...digits))
            )
        }
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
