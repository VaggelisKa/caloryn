import Testing
import Foundation
@testable import Caloryn

/// Edge-case coverage for `Caloryn/Extensions/Double+Formatting.swift`.
///
/// `FormattingAndDateHelperTests.swift` already covers the happy path for
/// `kcalFormatted`, `macroFormatted`, and `wholeFormatted`. This file focuses
/// on rounding boundaries, sign handling, extreme magnitudes, and
/// non-finite values.
///
/// Locale note: `String(format:)` without an explicit `Locale` argument
/// always renders using the POSIX ('.') decimal separator, regardless of
/// `Locale.current` -- verified by direct experiment (macOS host locale
/// `en_GR`, which is *not* `en_US`, still produced "12.5" not "12,5").
/// Since none of `kcalFormatted`/`macroFormatted`/`wholeFormatted` pass a
/// `Locale` to `String(format:)`, their output is locale-independent. The
/// tests below assert fixed, non-localized output for that reason -- this
/// is a genuine behavioral characterization, not an oversight.
struct FormattingEdgeCaseTests {

    // MARK: - macroFormatted rounding boundaries

    @Test(
        "macroFormatted renders values whose .1f representation ends in .0 as a bare integer with no decimal",
        arguments: [
            (0.0, "0g"),
            (12.0, "12g"),
            (11.96, "12g"),
            (11.999999, "12g"),
            (0.04, "0g"),
        ]
    )
    func macroFormattedCollapsesWholeValuesToIntegerGrams(value: Double, expected: String) {
        #expect(value.macroFormatted == expected)
    }

    @Test(
        "macroFormatted keeps one decimal place for non-whole values, including floating-point .5-boundary quirks",
        arguments: [
            (12.25, "12.2g"),   // binary double for 12.25 rounds down under %.1f
            (12.35, "12.3g"),   // binary double for 12.35 rounds down under %.1f
            (0.05, "0.1g"),
            (11.95, "11.9g"),
            (1_000_000.25, "1000000.2g"),
        ]
    )
    func macroFormattedRoundsToOneDecimalPlace(value: Double, expected: String) {
        #expect(value.macroFormatted == expected)
    }

    @Test(
        "macroFormatted treats negative zero and small negative fractions below the rounding threshold as 0g",
        arguments: [
            (-0.0, "0g"),
            (0.001, "0g"),
        ]
    )
    func macroFormattedTreatsNegligibleValuesAsZero(value: Double, expected: String) {
        #expect(value.macroFormatted == expected)
    }

    @Test("macroFormatted preserves the negative sign for negative non-whole values")
    func macroFormattedPreservesNegativeSign() {
        #expect((-5.4).macroFormatted == "-5.4g")
        #expect((-5.6).macroFormatted == "-5.6g")
    }

    @Test("macroFormatted on a very large value renders full digits with no thousands grouping separator")
    func macroFormattedOnLargeValueHasNoGroupingSeparator() {
        #expect(999_999.95.macroFormatted == "999999.9g")
        #expect(!999_999.95.macroFormatted.contains(","))
    }

    @Test("macroFormatted does not crash on NaN or infinite input and renders Foundation's textual token")
    func macroFormattedHandlesNonFiniteValuesWithoutCrashing() {
        #expect(Double.nan.macroFormatted == "nang")
        #expect(Double.infinity.macroFormatted == "infg")
        #expect((-Double.infinity).macroFormatted == "-infg")
    }

    // MARK: - kcalFormatted truncation (not rounding)

    @Test(
        "kcalFormatted truncates toward zero rather than rounding",
        arguments: [
            (123.9, "123 kcal"),
            (-123.9, "-123 kcal"),
            (0.0, "0 kcal"),
            (-0.4, "0 kcal"),
            (-0.6, "0 kcal"),
        ]
    )
    func kcalFormattedTruncatesTowardZero(value: Double, expected: String) {
        #expect(value.kcalFormatted == expected)
    }

    @Test("kcalFormatted on a very large value renders full digits with no thousands grouping separator")
    func kcalFormattedOnLargeValueHasNoGroupingSeparator() {
        #expect(1_000_000.9.kcalFormatted == "1000000 kcal")
    }

    @Test("Int.kcalFormatted renders the integer as-is, including negative and zero values")
    func intKcalFormattedRendersExactInteger() {
        #expect(0.kcalFormatted == "0 kcal")
        #expect((-42).kcalFormatted == "-42 kcal")
        #expect(2_500_000.kcalFormatted == "2500000 kcal")
    }

    // MARK: - Non-finite and out-of-range input must not trap

    /// These could not be characterized before the fix: `Int(_:)` traps on a
    /// non-finite or out-of-range Double, and a trap takes down the whole
    /// `xcodebuild test` process rather than failing one test. So these assert
    /// the new behaviour directly -- that a bad number renders as text.
    @Test(
        "kcalFormatted renders non-finite input as zero rather than trapping",
        arguments: [
            (Double.nan, "0 kcal"),
            (Double.infinity, "0 kcal"),
            (-Double.infinity, "0 kcal"),
        ]
    )
    func kcalFormattedHandlesNonFiniteValues(value: Double, expected: String) {
        #expect(value.kcalFormatted == expected)
    }

    @Test(
        "wholeFormatted renders non-finite input as zero rather than trapping",
        arguments: [
            (Double.nan, "0"),
            (Double.infinity, "0"),
            (-Double.infinity, "0"),
        ]
    )
    func wholeFormattedHandlesNonFiniteValues(value: Double, expected: String) {
        #expect(value.wholeFormatted == expected)
    }

    @Test("Finite values beyond Int's range clamp to its bounds instead of trapping")
    func outOfRangeFiniteValuesClampToIntBounds() {
        #expect(1e30.wholeFormatted == "\(Int.max)")
        #expect((-1e30).wholeFormatted == "\(Int.min)")
        #expect(1e30.kcalFormatted == "\(Int.max) kcal")
        // macroFormatted's whole-number branch reaches the same conversion:
        // "%.1f" of 1e30 ends in ".0", so it too used to trap here.
        #expect(1e30.macroFormatted == "\(Int.max)g")
    }

    // MARK: - wholeFormatted truncation (not rounding)

    @Test(
        "wholeFormatted truncates toward zero rather than rounding",
        arguments: [
            (98.9, "98"),
            (-98.9, "-98"),
            (0.0, "0"),
            (-0.4, "0"),
            (-0.6, "0"),
        ]
    )
    func wholeFormattedTruncatesTowardZero(value: Double, expected: String) {
        #expect(value.wholeFormatted == expected)
    }
}
