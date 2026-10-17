import Foundation

extension Double {
    /// Truncates toward zero without trapping.
    ///
    /// `Int(self)` is a trap, not a conversion: NaN, an infinity, or anything
    /// past `Int.max` terminates the process. These formatters render values
    /// derived from user-entered nutrition data, so a bad number has to come
    /// out as text, not as a crash.
    var truncatedSafely: Int {
        guard isFinite else { return 0 }
        if self >= Double(Int.max) { return .max }
        if self <= Double(Int.min) { return .min }
        return Int(self)
    }

    var kcalFormatted: String {
        "\(truncatedSafely) kcal"
    }

    var macroFormatted: String {
        "\(macroNumber)g"
    }

    /// "3.6 g", "1.450 g": the app's house form for a weight, a space before the unit as the
    /// quick chips ("50 g") and serving copy ("1 pot 150 g") write it, and the number grouped
    /// and pointed for the reader's locale, as every kcal figure already is ("2.000 kcal").
    /// Every screen shows grams this way; widgets and the CSV export format their own.
    var spacedMacroFormatted: String {
        spacedMacroFormatted(locale: .current)
    }

    /// `spacedMacroFormatted` in a given locale. `locale` exists for tests.
    ///
    /// Rounded to a tenth before formatting, so the formatter never rounds again and a value
    /// that rounds to nothing reads "0 g" rather than "-0 g". One decimal, or none when it
    /// is zero: "12 g", "12.2 g".
    func spacedMacroFormatted(locale: Locale) -> String {
        let tenths = (self * 10).rounded() / 10
        let value = tenths == 0 ? 0 : tenths
        return "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) g"
    }

    /// One decimal, or none when it is zero: "12", "12.2".
    private var macroNumber: String {
        let s = String(format: "%.1f", self)
        if s.hasSuffix(".0") {
            return "\(rounded().truncatedSafely)"
        }
        return s
    }

    /// "72.5 kg": a body weight to the tenth, the weight slider's half kilogram included,
    /// pointed for the reader's locale as grams are, so "72,5 kg" sits beside "66,7 g" on a
    /// phone that writes decimals with a comma. `locale` exists for tests.
    func kilogramsFormatted(locale: Locale = .current) -> String {
        "\(formatted(.number.precision(.fractionLength(1)).locale(locale))) kg"
    }

    var wholeFormatted: String {
        "\(truncatedSafely)"
    }
}

extension Int {
    var kcalFormatted: String {
        "\(self) kcal"
    }
}
