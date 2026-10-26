import Foundation

extension Double {
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

    var spacedMacroFormatted: String {
        spacedMacroFormatted(locale: .current)
    }

    func spacedMacroFormatted(locale: Locale) -> String {
        let tenths = (self * 10).rounded() / 10
        let value = tenths == 0 ? 0 : tenths
        return "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))) g"
    }

    private var macroNumber: String {
        let s = String(format: "%.1f", self)
        if s.hasSuffix(".0") {
            return "\(rounded().truncatedSafely)"
        }
        return s
    }

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
