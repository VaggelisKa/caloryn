import Foundation

extension Double {
    /// Truncates toward zero without trapping.
    ///
    /// `Int(self)` is a trap, not a conversion: NaN, an infinity, or anything
    /// past `Int.max` terminates the process. These formatters render values
    /// derived from user-entered nutrition data, so a bad number has to come
    /// out as text, not as a crash.
    private var truncatedSafely: Int {
        guard isFinite else { return 0 }
        if self >= Double(Int.max) { return .max }
        if self <= Double(Int.min) { return .min }
        return Int(self)
    }

    var kcalFormatted: String {
        "\(truncatedSafely) kcal"
    }

    var macroFormatted: String {
        let s = String(format: "%.1f", self)
        if s.hasSuffix(".0") {
            return "\(rounded().truncatedSafely)g"
        }
        return s + "g"
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
