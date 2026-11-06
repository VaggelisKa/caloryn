import Foundation

enum ChatbotLogInstructions {
    static let templateNutrients: [LogLinkNutrient] = [
        .protein, .carbs, .fat, .fiber, .sugars, .saturatedFat, .sodium
    ]

    static let extraNutrients: [LogLinkNutrient] = LogLinkNutrient.allCases.filter {
        !templateNutrients.contains($0)
    }

    static let linkTemplate = "caloryn://log?v=\(LogLinkDraft.currentVersion)&name=…&kcal=…&grams=…"
        + templateNutrients.map { "&\($0.rawValue)=…" }.joined()

    static let exampleLink =
        "caloryn://log?v=\(LogLinkDraft.currentVersion)&name=Greek%20yogurt%20with%20honey&kcal=212&grams=200"
        + "&protein=18.5&carbs=24&fat=4.2&fiber=0&sugars=22.5&saturated_fat=2.6&sodium_mg=72"

    private static let templateOrder = (["kcal", "grams"] + templateNutrients.map(\.rawValue))
        .joined(separator: ", ")

    private static let extraFieldList = extraNutrients.map(\.rawValue).joined(separator: ", ")

    static let text = """
        I log food in the Caloryn app. Whenever I tell you what I ate, reply with exactly one line \
        inside a code block, in this format:

        \(linkTemplate)

        For example:

        \(exampleLink)

        Rules:
        - Put name right after v=\(LogLinkDraft.currentVersion), then \(templateOrder).
        - In name, percent-encode every character that is not an English letter (A–Z, a–z) or a \
        digit (0–9). A space is %20, never +. Accented letters are encoded as UTF-8, so é is %C3%A9. \
        Keep the name under 100 characters.
        - Write numbers with a dot for decimals and at most two decimals, with no commas, units or spaces.
        - Every amount is a total for the whole portion, not per 100 g.
        - sodium_mg and cholesterol_mg are in milligrams. kcal is in kilocalories. Every other amount is in grams.
        - Always include grams. If I didn’t say how much, estimate the weight of the portion.
        - After those fields you may also add any of these, only when you know the value: \(extraFieldList).
        - If you don’t know a value, leave that field out. Never write 0 for a value you don’t know.
        - Don’t add any other fields.
        - One food per line, and only one line per reply.
        """
}
