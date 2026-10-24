import Foundation

enum ChatbotLogInstructions {
    static let linkTemplate = "caloryn://log?v=1&name=…&kcal=…&grams=…&protein=…&carbs=…&fat=…"

    static let exampleLink =
        "caloryn://log?v=1&name=Greek%20yogurt%20with%20honey&kcal=212&grams=200&protein=18.5&carbs=24&fat=4.2"

    static let text = """
        I log food in the Caloryn app. Whenever I tell you what I ate, reply with exactly one line \
        inside a code block, in this format:

        \(linkTemplate)

        For example:

        \(exampleLink)

        Rules:
        - Put name right after v=1, then kcal, grams, protein, carbs and fat.
        - In name, percent-encode every character that is not an English letter (A–Z, a–z) or a \
        digit (0–9). A space is %20, never +. Accented letters are encoded as UTF-8, so é is %C3%A9. \
        Keep the name under 100 characters.
        - Write numbers with a dot for decimals and at most two decimals, with no commas, units or spaces.
        - kcal, grams, protein, carbs and fat are totals for the whole portion, not per 100 g.
        - Always include grams. If I didn’t say how much, estimate the weight of the portion.
        - If you don’t know protein, carbs or fat, leave that field out. Never write 0 for a value \
        you don’t know.
        - Don’t add any other fields.
        - One food per line, and only one line per reply.
        """
}
