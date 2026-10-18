import Foundation
import SwiftUI
import Testing
@testable import Caloryn

private let usLocale = Locale(identifier: "en_US")
private let danishLocale = Locale(identifier: "da_DK")

// MARK: - Goal kinds

@Suite("Nutrient goal kind copy")
struct NutrientGoalKindCopyTests {

    @Test(
        "Each goal kind has a name, a short label and a spoken phrase",
        arguments: [
            (NutrientGoalKind.minimum, "minimum", "Minimum", "min", "at least"),
            (.target, "target", "Target", "goal", "target"),
            (.maximum, "maximum", "Maximum", "max", "at most"),
        ]
    )
    func copy(kind: NutrientGoalKind, raw: String, name: String, short: String, spoken: String) {
        #expect(kind.id == raw)
        #expect(kind.rawValue == raw)
        #expect(kind.displayName == name)
        #expect(kind.shortLabel == short)
        #expect(kind.accessibilityPhrase == spoken)
    }

    @Test("Kinds are offered minimum, target, maximum")
    func order() {
        #expect(NutrientGoalKind.allCases == [.minimum, .target, .maximum])
    }
}

// MARK: - Units

@Suite("Tracked nutrient unit conversions")
struct TrackedNutrientUnitCoverageTests {

    @Test("The input field is labelled with the unit the user types in")
    func inputUnitLabels() {
        #expect(TrackedNutrientUnit.grams.inputUnitLabel == "g")
        #expect(TrackedNutrientUnit.milligramsFromGrams.inputUnitLabel == "mg")
    }

    @Test(
        "Grams round half away from zero to the tenth, and a value that rounds to nothing is a plain zero",
        arguments: [
            (12.25, "12.3 g"),    // 122.5 tenths → 123
            (12.75, "12.8 g"),    // 127.5 tenths → 128
            (0.25, "0.3 g"),      // 2.5 tenths → 3
            (12.0, "12 g"),
            (-0.04, "0 g"),       // −0.4 tenths → −0, never "-0 g"
            (1_234.56, "1,234.6 g"),
        ]
    )
    func gramsFormatting(value: Double, expected: String) {
        #expect(TrackedNutrientUnit.grams.formatted(value, locale: usLocale) == expected)
    }

    @Test("Grams use the reader's decimal separator")
    func gramsFormattingInADecimalCommaLocale() {
        #expect(TrackedNutrientUnit.grams.formatted(66.7, locale: danishLocale) == "66,7 g")
    }

    @Test(
        "Stored grams of sodium and cholesterol show as whole milligrams, grouped for the reader",
        arguments: [
            (2.3, "2,300 mg"),        // 2.3 g × 1000
            (0.0125, "13 mg"),        // 12.5 mg rounds half up
            (0.0124, "12 mg"),
            (0.0004, "0 mg"),
            (0.0, "0 mg"),
        ]
    )
    func milligramsFormatting(grams: Double, expected: String) {
        #expect(TrackedNutrientUnit.milligramsFromGrams.formatted(grams, locale: usLocale) == expected)
    }

    @Test(
        "Spoken amounts round to the tenth and take the singular only for exactly one",
        arguments: [
            (TrackedNutrientUnit.grams, 0.96, "1 gram"),           // 9.6 tenths → 10 → 1.0
            (.grams, 2.25, "2.3 grams"),                           // 22.5 tenths → 23
            (.grams, 0.0, "0 grams"),
            (.grams, 1.04, "1 gram"),                              // 10.4 tenths → 10
            (.milligramsFromGrams, 2.3, "2300 milligrams"),        // no grouping when spoken
            (.milligramsFromGrams, 0.0004, "0 milligrams"),        // 0.4 mg → 0
            (.milligramsFromGrams, 0.0009, "1 milligram"),         // 0.9 mg → 1
        ]
    )
    func spokenFormatting(unit: TrackedNutrientUnit, value: Double, expected: String) {
        #expect(unit.spokenFormatted(value) == expected)
    }

    @Test(
        "The goal input shows a whole number without a point and anything else to one decimal",
        arguments: [
            (TrackedNutrientUnit.grams, 12.0, "12"),
            (.grams, 12.25, "12.3"),        // 122.5 tenths → 123
            (.grams, 12.04, "12"),          // 120.4 tenths → 120, a whole number again
            (.grams, -2.25, "-2.3"),        // half rounds away from zero on the negative side too
            (.grams, 0.0, "0"),
            (.milligramsFromGrams, 2.3, "2300"),
            (.milligramsFromGrams, 0.0123, "12.3"),
        ]
    )
    func goalInputFormatting(unit: TrackedNutrientUnit, stored: Double, expected: String) {
        #expect(unit.inputFormatted(stored) == expected)
    }

    @Test("What the user types converts back to stored grams")
    func storedValueFromInput() {
        #expect(TrackedNutrientUnit.grams.storedValue(fromInput: 66.7) == 66.7)
        #expect(TrackedNutrientUnit.milligramsFromGrams.storedValue(fromInput: 2_300) == 2.3)
        #expect(TrackedNutrientUnit.milligramsFromGrams.storedValue(fromInput: 0) == 0)
        // Typed, stored and shown again, a milligram goal reads back as typed.
        let stored = TrackedNutrientUnit.milligramsFromGrams.storedValue(fromInput: 300)
        #expect(TrackedNutrientUnit.milligramsFromGrams.inputFormatted(stored) == "300")
    }
}

// MARK: - The nutrient table

@Suite("Tracked nutrient table")
struct TrackedNutrientTableTests {

    @Test(
        "Each nutrient's names, symbol, unit and default goal",
        arguments: [
            (TrackedNutrient.protein, "Protein", "Protein", "dumbbell.fill", TrackedNutrientUnit.grams, NutrientGoalKind.minimum),
            (.carbs, "Carbs", "Carbs", "fork.knife", .grams, .target),
            (.fat, "Fat", "Fat", "drop.fill", .grams, .target),
            (.fiber, "Fiber", "Fiber", "carrot.fill", .grams, .minimum),
            (.sugars, "Sugars", "Sugars", "cube.fill", .grams, .maximum),
            (.addedSugars, "Added Sugars", "Added Sugar", "cube.transparent.fill", .grams, .maximum),
            (.saturatedFat, "Saturated Fat", "Sat Fat", "exclamationmark.triangle.fill", .grams, .maximum),
            (.sodium, "Sodium", "Sodium", "s.circle.fill", .milligramsFromGrams, .maximum),
            (.cholesterol, "Cholesterol", "Cholesterol", "heart.fill", .milligramsFromGrams, .maximum),
            (.alcohol, "Alcohol", "Alcohol", "wineglass.fill", .grams, .maximum),
        ]
    )
    func table(
        nutrient: TrackedNutrient,
        name: String,
        compact: String,
        symbol: String,
        unit: TrackedNutrientUnit,
        goal: NutrientGoalKind
    ) {
        #expect(nutrient.displayName == name)
        #expect(nutrient.compactName == compact)
        #expect(nutrient.systemImage == symbol)
        #expect(nutrient.unit == unit)
        #expect(nutrient.defaultGoalKind == goal)
        #expect(nutrient.id == nutrient.rawValue)
    }

    @Test("The stored selection string spells every nutrient by its raw value, in order")
    func rawValuesAreThePersistedSpelling() {
        #expect(
            TrackedNutrient.rawSelection(from: TrackedNutrient.allCases)
                == "protein,carbs,fat,fiber,sugars,addedSugars,saturatedFat,sodium,cholesterol,alcohol"
        )
        #expect(TrackedNutrient.defaultSelectionRaw == "protein,carbs,fat")
    }

    @Test("Only the non-macro nutrients have an editable goal")
    func editableGoalNutrients() {
        #expect(TrackedNutrient.editableGoalNutrients == [
            .fiber, .sugars, .addedSugars, .saturatedFat, .sodium, .cholesterol, .alcohol,
        ])
    }

    @Test("Sugars share the carb colour, fat-like nutrients the fat colour, sodium and alcohol their own")
    func colourGroups() {
        #expect(TrackedNutrient.protein.color == CalorynTheme.proteinColor)
        #expect(TrackedNutrient.carbs.color == CalorynTheme.carbColor)
        #expect(TrackedNutrient.sugars.color == CalorynTheme.carbColor)
        #expect(TrackedNutrient.fiber.color == CalorynTheme.fiberColor)
        for nutrient in [TrackedNutrient.fat, .addedSugars, .saturatedFat, .cholesterol] {
            #expect(nutrient.color == CalorynTheme.fatColor, "\(nutrient)")
        }
        #expect(TrackedNutrient.sodium.color == CalorynTheme.stone)
        #expect(TrackedNutrient.alcohol.color == CalorynTheme.textSecondary)
        #expect(TrackedNutrient.sodium.color != TrackedNutrient.alcohol.color)
    }

    // MARK: Selection

    @Test(
        "A stored selection drops what it cannot read and is padded to three from the defaults",
        arguments: [
            ("sodium,bogus,alcohol", [TrackedNutrient.sodium, .alcohol, .protein]),
            ("fiber,sodium,alcohol,sugars", [.fiber, .sodium, .alcohol, .sugars]),
            ("carbs", [.carbs, .protein, .fat]),
            ("Protein", [.protein, .carbs, .fat]),          // raw values are case-sensitive
            (",,,", [.protein, .carbs, .fat]),
            ("fat,protein,fat,carbs,protein", [.fat, .protein, .carbs]),
        ]
    )
    func storedSelection(raw: String, expected: [TrackedNutrient]) {
        #expect(TrackedNutrient.selected(from: raw) == expected)
    }

    @Test("Every nutrient survives a round trip through the stored selection")
    func selectionRoundTrip() {
        let all = TrackedNutrient.allCases
        #expect(TrackedNutrient.selected(from: TrackedNutrient.rawSelection(from: all)) == all)
    }

    @Test("Normalising removes repeats before padding to three")
    func normalisedSelection() {
        #expect(TrackedNutrient.normalizedSelection(from: [.fat, .fat, .fat]) == [.fat, .protein, .carbs])
        #expect(TrackedNutrient.normalizedSelection(from: [.sodium]) == [.sodium, .protein, .carbs])
        #expect(TrackedNutrient.normalizedSelection(from: []) == TrackedNutrient.defaultSelection)
    }

    // MARK: Day totals

    @MainActor
    @Test("Each optional nutrient totals across entries, a missing value counting as zero")
    func optionalNutrientsTotal() {
        let half = makeTestEntry(
            foodItem: makeTestFoodItem(
                addedSugarsPer100g: 8,
                saturatedFatPer100g: 6,
                cholesterolPer100g: 0.02,
                alcoholPer100g: 10
            ),
            portionGrams: 50
        )
        let unreported = makeTestEntry(foodItem: makeTestFoodItem(), portionGrams: 300)
        let entries = [half, unreported]

        // 50 g of each per-100 g value, plus nothing.
        #expect(abs(TrackedNutrient.addedSugars.value(in: entries) - 4) < 1e-9)
        #expect(abs(TrackedNutrient.saturatedFat.value(in: entries) - 3) < 1e-9)
        #expect(abs(TrackedNutrient.cholesterol.value(in: entries) - 0.01) < 1e-12)
        #expect(abs(TrackedNutrient.alcohol.value(in: entries) - 5) < 1e-9)
        #expect(TrackedNutrient.protein.value(in: []) == 0)
    }
}

// MARK: - A nutrient's line on Today

@Suite("Tracked nutrient metric")
struct TrackedNutrientMetricCoverageTests {

    private func metric(
        _ nutrient: TrackedNutrient = .protein,
        value: Double,
        target: Double?,
        kind: NutrientGoalKind?
    ) -> TrackedNutrientMetric {
        TrackedNutrientMetric(nutrient: nutrient, value: value, target: target, goalKind: kind)
    }

    @Test("A metric is identified by its nutrient")
    func identity() {
        #expect(metric(.saturatedFat, value: 1, target: nil, kind: nil).id == "saturatedFat")
    }

    @Test(
        "The target line names the goal kind, or just the amount when there is none",
        arguments: [
            (Optional<NutrientGoalKind>.none, "150 g"),
            (.minimum, "150 g min"),
            (.target, "150 g goal"),
            (.maximum, "150 g max"),
        ]
    )
    func formattedTargetWording(kind: NutrientGoalKind?, expected: String) {
        #expect(metric(value: 46, target: 150, kind: kind).formattedTarget(locale: usLocale) == expected)
    }

    @Test("No target, a zero target and a negative target all read as no target", arguments: [nil, 0.0, -5.0])
    func absentTargets(target: Double?) {
        let line = metric(value: 46, target: target, kind: .minimum)

        #expect(line.formattedTarget(locale: usLocale) == nil)
        #expect(line.targetSummary == nil)
        #expect(line.progress == 0)
        #expect(line.accessibilityLabel == "Protein: 46 g today")
    }

    @Test("The value follows the reader's locale")
    func formattedValueLocale() {
        #expect(metric(value: 66.7, target: nil, kind: nil).formattedValue(locale: danishLocale) == "66,7 g")
        #expect(metric(.cholesterol, value: 0.3, target: nil, kind: nil).formattedValue(locale: usLocale) == "300 mg")
    }

    @Test(
        "The spoken target summary uses the goal kind's phrase, or 'of' without one",
        arguments: [
            (Optional<NutrientGoalKind>.none, "of 150 g"),
            (.minimum, "at least 150 g"),
            (.target, "target 150 g"),
            (.maximum, "at most 150 g"),
        ]
    )
    func targetSummaryWording(kind: NutrientGoalKind?, expected: String) {
        let line = metric(value: 46, target: 150, kind: kind)

        #expect(line.targetSummary == expected)
        #expect(line.accessibilityLabel == "Protein: 46 g, \(expected)")
    }

    @Test(
        "Progress is the share of the target eaten, capped at a full ring",
        arguments: [
            (0.0, 0.0),
            (75.0, 0.5),        // 75 / 150
            (150.0, 1.0),
            (300.0, 1.0),       // 2.0 capped
        ]
    )
    func progressShare(value: Double, expected: Double) {
        #expect(metric(value: value, target: 150, kind: .minimum).progress == expected)
    }

    @Test("Only going past a maximum turns the accent terracotta")
    func accentColour() {
        let over = metric(.sugars, value: 51, target: 50, kind: .maximum)
        let atLimit = metric(.sugars, value: 50, target: 50, kind: .maximum)
        let pastMinimum = metric(.protein, value: 200, target: 150, kind: .minimum)
        let pastGoal = metric(.carbs, value: 300, target: 200, kind: .target)
        let noTarget = metric(.sodium, value: 5, target: nil, kind: .maximum)
        let noKind = metric(.sugars, value: 80, target: 50, kind: nil)

        #expect(over.accentColor == CalorynTheme.terracotta)
        #expect(atLimit.accentColor == TrackedNutrient.sugars.color)
        #expect(pastMinimum.accentColor == TrackedNutrient.protein.color)
        #expect(pastGoal.accentColor == TrackedNutrient.carbs.color)
        #expect(noTarget.accentColor == CalorynTheme.stone)
        #expect(noKind.accentColor == TrackedNutrient.sugars.color)
        #expect(over.accentColor != atLimit.accentColor)
    }
}
