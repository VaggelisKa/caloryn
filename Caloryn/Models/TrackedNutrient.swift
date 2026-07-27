import SwiftUI

enum NutrientGoalKind: String, CaseIterable, Identifiable {
    case minimum
    case target
    case maximum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimum:
            "Minimum"
        case .target:
            "Target"
        case .maximum:
            "Maximum"
        }
    }

    var shortLabel: String {
        switch self {
        case .minimum:
            "min"
        case .target:
            "goal"
        case .maximum:
            "max"
        }
    }

    var accessibilityPhrase: String {
        switch self {
        case .minimum:
            "at least"
        case .target:
            "target"
        case .maximum:
            "at most"
        }
    }
}

enum TrackedNutrientUnit {
    case grams
    case milligramsFromGrams

    var inputUnitLabel: String {
        switch self {
        case .grams:
            "g"
        case .milligramsFromGrams:
            "mg"
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .grams:
            value.macroFormatted
        case .milligramsFromGrams:
            "\((value * 1000).rounded().truncatedSafely)mg"
        }
    }

    func inputFormatted(_ storedValue: Double) -> String {
        switch self {
        case .grams:
            storedValue.goalInputFormatted
        case .milligramsFromGrams:
            (storedValue * 1000).goalInputFormatted
        }
    }

    func storedValue(fromInput input: Double) -> Double {
        switch self {
        case .grams:
            input
        case .milligramsFromGrams:
            input / 1000
        }
    }
}

enum TrackedNutrient: String, CaseIterable, Identifiable, Hashable {
    case protein
    case carbs
    case fat
    case fiber
    case sugars
    case addedSugars
    case saturatedFat
    case sodium
    case cholesterol
    case alcohol

    var id: String { rawValue }

    static let minimumSelectionCount = 3
    static let defaultSelection: [TrackedNutrient] = [.protein, .carbs, .fat]
    static let defaultSelectionRaw = rawSelection(from: defaultSelection)
    static let editableGoalNutrients: [TrackedNutrient] = [
        .fiber,
        .sugars,
        .addedSugars,
        .saturatedFat,
        .sodium,
        .cholesterol,
        .alcohol
    ]

    static func selected(from rawValue: String) -> [TrackedNutrient] {
        let nutrients = rawValue
            .split(separator: ",")
            .compactMap { TrackedNutrient(rawValue: String($0)) }
            .reduce(into: [TrackedNutrient]()) { selected, nutrient in
                guard !selected.contains(nutrient) else { return }
                selected.append(nutrient)
            }

        return normalizedSelection(from: nutrients)
    }

    static func rawSelection(from nutrients: [TrackedNutrient]) -> String {
        nutrients.map(\.rawValue).joined(separator: ",")
    }

    static func normalizedSelection(from nutrients: [TrackedNutrient]) -> [TrackedNutrient] {
        var selection = nutrients.reduce(into: [TrackedNutrient]()) { selected, nutrient in
            guard !selected.contains(nutrient) else { return }
            selected.append(nutrient)
        }

        if selection.isEmpty {
            selection = defaultSelection
        }

        for nutrient in defaultSelection where selection.count < minimumSelectionCount && !selection.contains(nutrient) {
            selection.append(nutrient)
        }

        for nutrient in allCases where selection.count < minimumSelectionCount && !selection.contains(nutrient) {
            selection.append(nutrient)
        }

        return selection
    }

    var displayName: String {
        switch self {
        case .protein:
            "Protein"
        case .carbs:
            "Carbs"
        case .fat:
            "Fat"
        case .fiber:
            "Fiber"
        case .sugars:
            "Sugars"
        case .addedSugars:
            "Added Sugars"
        case .saturatedFat:
            "Saturated Fat"
        case .sodium:
            "Sodium"
        case .cholesterol:
            "Cholesterol"
        case .alcohol:
            "Alcohol"
        }
    }

    var compactName: String {
        switch self {
        case .addedSugars:
            "Added Sugar"
        case .saturatedFat:
            "Sat Fat"
        default:
            displayName
        }
    }

    var systemImage: String {
        switch self {
        case .protein:
            "dumbbell.fill"
        case .carbs:
            "fork.knife"
        case .fat:
            "drop.fill"
        case .fiber:
            "carrot.fill"
        case .sugars:
            "cube.fill"
        case .addedSugars:
            "cube.transparent.fill"
        case .saturatedFat:
            "exclamationmark.triangle.fill"
        case .sodium:
            "s.circle.fill"
        case .cholesterol:
            "heart.fill"
        case .alcohol:
            "wineglass.fill"
        }
    }

    var color: Color {
        switch self {
        case .protein:
            CalorynTheme.proteinColor
        case .carbs, .sugars:
            CalorynTheme.carbColor
        case .fat, .addedSugars, .saturatedFat, .cholesterol:
            CalorynTheme.fatColor
        case .fiber:
            CalorynTheme.fiberColor
        case .sodium:
            CalorynTheme.stone
        case .alcohol:
            CalorynTheme.textSecondary
        }
    }

    var unit: TrackedNutrientUnit {
        switch self {
        case .sodium, .cholesterol:
            .milligramsFromGrams
        case .protein, .carbs, .fat, .fiber, .sugars, .addedSugars, .saturatedFat, .alcohol:
            .grams
        }
    }

    var defaultGoalKind: NutrientGoalKind {
        switch self {
        case .protein, .fiber:
            .minimum
        case .carbs, .fat:
            .target
        case .sugars, .addedSugars, .saturatedFat, .sodium, .cholesterol, .alcohol:
            .maximum
        }
    }

    func value(in entries: [FoodLogEntry]) -> Double {
        entries.reduce(0) { $0 + $1.nutrition.value(for: self) }
    }
}

struct TrackedNutrientMetric: Identifiable {
    let nutrient: TrackedNutrient
    let value: Double
    let target: Double?
    let goalKind: NutrientGoalKind?

    var id: String { nutrient.id }

    var formattedValue: String {
        nutrient.unit.formatted(value)
    }

    var formattedTarget: String? {
        guard let target, target > 0 else { return nil }
        guard let goalKind else { return nutrient.unit.formatted(target) }
        return "\(nutrient.unit.formatted(target)) \(goalKind.shortLabel)"
    }

    var targetSummary: String? {
        guard let target, target > 0 else { return nil }
        guard let goalKind else { return "of \(nutrient.unit.formatted(target))" }
        return "\(goalKind.accessibilityPhrase) \(nutrient.unit.formatted(target))"
    }

    var progress: Double {
        guard let target, target > 0 else { return 0 }
        return min(value / target, 1.0)
    }

    var accentColor: Color {
        if goalKind == .maximum, let target, value > target {
            return CalorynTheme.terracotta
        }
        return nutrient.color
    }

    var accessibilityLabel: String {
        if let targetSummary {
            return "\(nutrient.displayName): \(formattedValue), \(targetSummary)"
        }
        return "\(nutrient.displayName): \(formattedValue) today"
    }
}

private extension Double {
    var goalInputFormatted: String {
        let rounded = (self * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(rounded.truncatedSafely)"
        }
        return String(format: "%.1f", rounded)
    }
}
