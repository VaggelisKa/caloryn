import Foundation

extension String {
    /// The number this text means when it was typed on a decimal keypad, or nil
    /// when it is not one.
    ///
    /// The keypad's contract is plain decimal: an optional sign, ASCII digits,
    /// and at most one separator, which may be "." or "," so the field behaves
    /// the same whichever the keyboard produces. Bare `Double(_:)` accepts far
    /// more than that — `"1e3"`, `"0x1p4"`, `"inf"` and `"nan"` all parse — and
    /// a non-finite value that reaches a formatter or an `Int(_:)` conversion
    /// terminates the process. So the shape is checked before converting, and
    /// an overflowing run of digits, which `Double(_:)` quietly turns into an
    /// infinity, is rejected too.
    var decimalInputValue: Double? {
        let trimmed = trimmingCharacters(in: .whitespaces)

        var body = Substring(trimmed)
        if let sign = body.first, sign == "+" || sign == "-" {
            body = body.dropFirst()
        }

        var digitCount = 0
        var separatorCount = 0
        for character in body {
            if character.isASCII, character.isNumber {
                digitCount += 1
            } else if character == "." || character == "," {
                separatorCount += 1
            } else {
                return nil
            }
        }
        guard digitCount > 0, separatorCount <= 1 else { return nil }

        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")),
              value.isFinite else { return nil }
        return value
    }
}
