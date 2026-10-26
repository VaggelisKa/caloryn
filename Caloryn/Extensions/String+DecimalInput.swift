import Foundation

extension String {
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
