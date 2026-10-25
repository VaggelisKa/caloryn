import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("Pasted food confirmation")
struct PastedFoodConfirmationTests {
    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    private static func confirmation(
        name: String = "Greek yogurt",
        kcal: Double = 150,
        grams: Double? = 170,
        proteinG: Double? = 15,
        carbsG: Double? = 6,
        fatG: Double? = 4,
        locale: Locale = english
    ) -> PastedFoodConfirmation {
        PastedFoodConfirmation(
            draft: LogLinkDraft(
                name: name,
                kcal: kcal,
                grams: grams,
                proteinG: proteinG,
                carbsG: carbsG,
                fatG: fatG,
                meal: nil
            ),
            locale: locale
        )
    }

    private static func withGrams(_ input: String, from confirmation: PastedFoodConfirmation) -> PastedFoodConfirmation {
        var edited = confirmation
        edited.gramsInput = input
        return edited
    }

    private static func withName(_ input: String, from confirmation: PastedFoodConfirmation) -> PastedFoodConfirmation {
        var edited = confirmation
        edited.nameInput = input
        return edited
    }

    @Test("A pasted link opens with every value it carries and can be added as it is")
    func pastedLinkOpens() throws {
        let result = PastedFoodConfirmation.opening(
            pasted: ["Here you go:\n```\ncaloryn://log?v=1&name=Greek%20yogurt&kcal=150&grams=170&protein=15&carbs=6&fat=4\n```"],
            locale: Self.english
        )
        let confirmation = try result.get()

        #expect(confirmation.name == "Greek yogurt")
        #expect(confirmation.caloriesText(locale: Self.english) == "150 kcal")
        #expect(confirmation.amountText(of: .protein, locale: Self.english) == "15 g")
        #expect(confirmation.amountText(of: .carbs, locale: Self.english) == "6 g")
        #expect(confirmation.amountText(of: .fat, locale: Self.english) == "4 g")
        #expect(confirmation.gramsInput == "170")
        #expect(confirmation.canAdd)
        #expect(confirmation.portionGrams == 170)
        #expect(confirmation.portionBlockedReason(locale: Self.english) == nil)
    }

    @Test("A paste the parser rejects is reported with the parser's reason")
    func rejectedPaste() {
        let result = PastedFoodConfirmation.opening(pasted: ["Greek yogurt, 150 kcal"])

        #expect(result == .failure(.noLink))
        #expect(LogLinkRejection.noLink.errorDescription?.isEmpty == false)
    }

    @Test("Nothing on the pasteboard is a paste without a link")
    func emptyPaste() {
        #expect(PastedFoodConfirmation.opening(pasted: []) == .failure(.noLink))
    }

    @Test("Several pasted texts are read together, so two links are still two foods")
    func severalPastedTexts() {
        let result = PastedFoodConfirmation.opening(pasted: [
            "caloryn://log?v=1&name=Apple&kcal=52",
            "caloryn://log?v=1&name=Pear&kcal=57",
        ])

        #expect(result == .failure(.multipleLinks))
    }

    @Test("A macro the link leaves out reads as not provided, and a real zero stays zero")
    func missingMacros() {
        let confirmation = Self.confirmation(proteinG: 0, carbsG: nil, fatG: nil)

        #expect(confirmation.amountText(of: .protein, locale: Self.english) == "0 g")
        #expect(confirmation.amountText(of: .carbs, locale: Self.english) == "Not provided")
        #expect(confirmation.amountText(of: .fat, locale: Self.english) == "Not provided")
    }

    @Test("Values show every decimal the link carries, so the screen shows what is saved")
    func decimalValues() {
        let confirmation = Self.confirmation(kcal: 20_000, grams: 350.25, proteinG: 38.5, carbsG: 12.25, fatG: 0.05)

        #expect(confirmation.caloriesText(locale: Self.english) == "20,000 kcal")
        #expect(confirmation.amountText(of: .protein, locale: Self.english) == "38.5 g")
        #expect(confirmation.amountText(of: .carbs, locale: Self.english) == "12.25 g")
        #expect(confirmation.amountText(of: .fat, locale: Self.english) == "0.05 g")
        #expect(Self.confirmation(kcal: 150.25).caloriesText(locale: Self.english) == "150.25 kcal")
    }

    @Test(
        "The grams field opens with the link's grams in a form the field reads back unchanged",
        arguments: [
            (170.0, english, "170"),
            (170.25, english, "170.25"),
            (0.5, english, "0.5"),
            (100_000, english, "100000"),
            (170.25, german, "170,25"),
            (12_500, german, "12500"),
        ] as [(Double, Locale, String)]
    )
    func gramsPrefill(grams: Double, locale: Locale, expected: String) {
        let confirmation = Self.confirmation(grams: grams, proteinG: nil, carbsG: nil, fatG: nil, locale: locale)

        #expect(confirmation.gramsInput == expected)
        #expect(confirmation.portionGrams == grams)
    }

    @Test("A link without grams cannot be added until the portion is typed")
    func linkWithoutGrams() {
        let confirmation = Self.confirmation(grams: nil)

        #expect(confirmation.gramsInput.isEmpty)
        #expect(confirmation.portionBlocker == .gramsMissing)
        #expect(!confirmation.canAdd)
        #expect(confirmation.portionGrams == nil)
        #expect(
            confirmation.portionBlockedReason(locale: Self.english)
                == "Enter the portion weight in grams to add this food."
        )

        let typed = Self.withGrams("200", from: confirmation)
        #expect(typed.canAdd)
        #expect(typed.portionGrams == 200)
    }

    @Test(
        "Typed grams use the app's decimal input, with either separator",
        arguments: [("150", 150.0), ("12.5", 12.5), ("12,5", 12.5), (" 80 ", 80.0), ("100000", 100_000)]
    )
    func typedGrams(input: String, expected: Double) {
        let confirmation = Self.withGrams(input, from: Self.confirmation(proteinG: nil, carbsG: nil, fatG: nil))

        #expect(confirmation.canAdd)
        #expect(confirmation.portionGrams == expected)
    }

    @Test("Blank grams count as missing", arguments: ["", " ", "   "])
    func blankGrams(input: String) {
        let confirmation = Self.withGrams(input, from: Self.confirmation())

        #expect(confirmation.portionBlocker == .gramsMissing)
    }

    @Test("Grams that are not a number block adding", arguments: ["abc", "1.2.3", "12 g", "1e3", "--4"])
    func gramsNotANumber(input: String) {
        let confirmation = Self.withGrams(input, from: Self.confirmation())

        #expect(confirmation.portionBlocker == .gramsNotANumber)
        #expect(!confirmation.canAdd)
        #expect(
            confirmation.portionBlockedReason(locale: Self.english)
                == "Enter the portion weight as a number, such as 150 or 12.5."
        )
    }

    @Test(
        "Grams outside the safe portion bounds block adding",
        arguments: ["0", "0.0", "-5", "100000.01", "250000"]
    )
    func gramsOutOfRange(input: String) {
        let confirmation = Self.withGrams(input, from: Self.confirmation(proteinG: nil, carbsG: nil, fatG: nil))

        #expect(confirmation.portionBlocker == .gramsOutOfRange)
        #expect(confirmation.portionGrams == nil)
        #expect(
            confirmation.portionBlockedReason(locale: Self.english)
                == "The portion must be more than 0 g and no more than 100,000 g."
        )
    }

    @Test("A portion lighter than a macro it contains blocks adding and names the heaviest macro")
    func portionLighterThanAMacro() {
        let confirmation = Self.withGrams(
            "20",
            from: Self.confirmation(grams: nil, proteinG: 22.5, carbsG: 30, fatG: 4)
        )

        #expect(confirmation.portionBlocker == .portionLighterThan(.carbs, grams: 30))
        #expect(!confirmation.canAdd)
        #expect(
            confirmation.portionBlockedReason(locale: Self.english)
                == "The portion can’t weigh less than its 30 g of carbs."
        )
    }

    @Test(
        "Each macro alone is checked against the portion",
        arguments: [
            (PastedFoodConfirmation.Macro.protein, 40.5, "The portion can’t weigh less than its 40.5 g of protein."),
            (.carbs, 41, "The portion can’t weigh less than its 41 g of carbs."),
            (.fat, 40.01, "The portion can’t weigh less than its 40.01 g of fat."),
        ] as [(PastedFoodConfirmation.Macro, Double, String)]
    )
    func eachMacroIsChecked(macro: PastedFoodConfirmation.Macro, grams: Double, reason: String) {
        let confirmation = Self.withGrams(
            "40",
            from: Self.confirmation(
                grams: nil,
                proteinG: macro == .protein ? grams : nil,
                carbsG: macro == .carbs ? grams : nil,
                fatG: macro == .fat ? grams : nil
            )
        )

        #expect(confirmation.portionBlocker == .portionLighterThan(macro, grams: grams))
        #expect(confirmation.portionBlockedReason(locale: Self.english) == reason)
    }

    @Test("A portion exactly as heavy as its heaviest macro can be added")
    func portionEqualToAMacro() {
        let confirmation = Self.withGrams(
            "30",
            from: Self.confirmation(grams: nil, proteinG: 0, carbsG: 30, fatG: 30)
        )

        #expect(confirmation.canAdd)
        #expect(confirmation.portionGrams == 30)
    }

    @Test("Changing the grams never rescales the calories or macros")
    func gramsDoNotRescale() {
        let original = Self.confirmation()
        let edited = Self.withGrams("340", from: original)

        #expect(edited.portionGrams == 340)
        #expect(edited.kcal == original.kcal)
        #expect(edited.caloriesText(locale: Self.english) == "150 kcal")
        for macro in PastedFoodConfirmation.Macro.allCases {
            #expect(edited.grams(of: macro) == original.grams(of: macro))
            #expect(edited.amountText(of: macro, locale: Self.english) == original.amountText(of: macro, locale: Self.english))
        }
    }

    @Test(
        "A logged food with the same trimmed name in any case and the same calories is a duplicate",
        arguments: [
            ("Greek yogurt", 150.0),
            ("greek YOGURT", 150),
            ("  Greek yogurt \n", 150),
            ("Greek yogurt", 150.4),
            ("Greek yogurt", 149.5),
        ] as [(String, Double)]
    )
    func duplicate(loggedName: String, loggedCalories: Double) {
        #expect(Self.confirmation().matchesLoggedFood(named: loggedName, calories: loggedCalories))
    }

    @Test(
        "A different name or a different calorie count is not a duplicate",
        arguments: [
            ("Greek yoghurt", 150.0),
            ("Greek yogurt 2%", 150),
            ("Greek  yogurt", 150),
            ("Greek yogurt", 151),
            ("Greek yogurt", 150.5),
            ("Greek yogurt", 0),
        ] as [(String, Double)]
    )
    func notADuplicate(loggedName: String, loggedCalories: Double) {
        #expect(!Self.confirmation().matchesLoggedFood(named: loggedName, calories: loggedCalories))
    }

    @Test("The duplicate prompt names the food and its calories")
    func alreadyLoggedMessage() {
        #expect(
            Self.confirmation().alreadyLoggedMessage(locale: Self.english)
                == "Greek yogurt with 150 kcal is already in your log for this day."
        )
    }

    @Test("The name field opens with the link's name, and an edited name is the one saved")
    func editedName() {
        let confirmation = Self.confirmation()
        #expect(confirmation.nameInput == "Greek yogurt")

        let renamed = Self.withName("Skyr with honey", from: confirmation)

        #expect(renamed.name == "Skyr with honey")
        #expect(renamed.canAdd)
        #expect(renamed.nameBlockedReason == nil)
    }

    @Test(
        "An edited name is cleaned like a pasted one: trimmed, invisible characters dropped, each run of spaces or line breaks read as one space",
        arguments: [
            ("  Skyr  ", "Skyr"),
            ("Skyr   with honey", "Skyr with honey"),
            ("Skyr\nwith\thoney", "Skyr with honey"),
            ("\n Skyr \n", "Skyr"),
            ("Sk\u{200B}yr", "Skyr"),
        ]
    )
    func editedNameWhitespace(input: String, expected: String) {
        #expect(Self.withName(input, from: Self.confirmation()).name == expected)
    }

    @Test("A blank name blocks adding and says why", arguments: ["", " ", "\n\t ", "\u{200B}", " \u{200B} \u{FEFF}"])
    func blankName(input: String) {
        let confirmation = Self.withName(input, from: Self.confirmation())

        #expect(confirmation.nameBlocker == .missing)
        #expect(!confirmation.canAdd)
        #expect(confirmation.portionGrams == nil)
        #expect(confirmation.nameBlockedReason == "Enter a name to add this food.")
    }

    @Test("A name may be as long as a link's name, and no longer")
    func nameLength() {
        let longest = Self.withName(String(repeating: "a", count: LogLinkDraft.maximumNameLength), from: Self.confirmation())
        let tooLong = Self.withName(String(repeating: "a", count: LogLinkDraft.maximumNameLength + 1), from: Self.confirmation())
        let paddedLongest = Self.withName("  " + longest.nameInput + "  ", from: Self.confirmation())

        #expect(longest.canAdd)
        #expect(paddedLongest.canAdd)
        #expect(tooLong.nameBlocker == .tooLong)
        #expect(!tooLong.canAdd)
        #expect(tooLong.nameBlockedReason == "The name can’t be longer than 100 characters.")
    }

    @Test("Combining marks count toward the name limit, as they do in a pasted link")
    func combiningMarksCountTowardTheLimit() {
        let stacked = Self.withName("a" + String(repeating: "\u{0301}", count: LogLinkDraft.maximumNameLength), from: Self.confirmation())
        let accented = Self.withName("Cre\u{0300}me bru\u{0302}le\u{0301}e", from: Self.confirmation())

        #expect(stacked.nameBlocker == .tooLong)
        #expect(accented.canAdd)
    }

    @Test("A blank name and a missing portion are each reported, so both can be fixed at once")
    func nameAndPortionBlockersAreIndependent() {
        let confirmation = Self.withName("", from: Self.confirmation(grams: nil))

        #expect(confirmation.nameBlocker == .missing)
        #expect(confirmation.portionBlocker == .gramsMissing)
        #expect(!confirmation.canAdd)
    }

    @Test("The duplicate check and its prompt use the edited name")
    func duplicateUsesEditedName() {
        let renamed = Self.withName("  Skyr ", from: Self.confirmation())

        #expect(renamed.matchesLoggedFood(named: "skyr", calories: 150))
        #expect(!renamed.matchesLoggedFood(named: "Greek yogurt", calories: 150))
        #expect(renamed.alreadyLoggedMessage(locale: Self.english) == "Skyr with 150 kcal is already in your log for this day.")
    }
}
