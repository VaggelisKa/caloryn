import Foundation
import Testing
@testable import Caloryn

@MainActor
struct LogLinkDraftTests {
    private static let specExample =
        "caloryn://log?v=1&name=Greek%20yogurt&kcal=150&grams=170&protein=15&carbs=6&fat=4"

    private static let greekYogurt = LogLinkDraft(
        name: "Greek yogurt",
        kcal: 150,
        grams: 170,
        proteinG: 15,
        carbsG: 6,
        fatG: 4,
        meal: nil
    )

    private static let apple = LogLinkDraft(
        name: "Apple",
        kcal: 52,
        grams: nil,
        proteinG: nil,
        carbsG: nil,
        fatG: nil,
        meal: nil
    )

    private static func parse(query: String) -> Result<LogLinkDraft, LogLinkRejection> {
        LogLinkDraft.parse("caloryn://log?" + query)
    }

    private static func parsedName(_ encodedName: String) -> Result<String, LogLinkRejection> {
        parse(query: "v=1&name=\(encodedName)&kcal=52").map(\.name)
    }

    private static func parsedKcal(_ rawKcal: String) -> Result<Double, LogLinkRejection> {
        parse(query: "v=1&name=Apple&kcal=\(rawKcal)").map(\.kcal)
    }

    @Test("The example line from the spec parses to every value it carries")
    func specExampleParses() {
        #expect(LogLinkDraft.parse(Self.specExample) == .success(Self.greekYogurt))
    }

    @Test("A link with only the required fields leaves every optional value missing")
    func minimalLink() {
        #expect(Self.parse(query: "v=1&name=Apple&kcal=52") == .success(Self.apple))
    }

    @Test("A link with every field carries all of them, in any order")
    func fullLink() {
        let expected = LogLinkDraft(
            name: "Chicken salad",
            kcal: 420.5,
            grams: 350.25,
            proteinG: 38,
            carbsG: 12.5,
            fatG: 24.75,
            meal: .lunch
        )

        #expect(
            Self.parse(query: "meal=lunch&fat=24.75&carbs=12.5&protein=38&grams=350.25&kcal=420.5&name=Chicken%20salad&v=1")
                == .success(expected)
        )
    }

    @Test("The link is found wherever a chatbot reply puts it", arguments: [
        "Sure! Here’s your entry:\n\n\(specExample)\n\nEnjoy your snack.",
        "Tap to log: \(specExample) — anything else?",
        "`\(specExample)`",
        "```\n\(specExample)\n```",
        "```text\n\(specExample)\n```",
        "[Log](\(specExample))",
        "[Log it](\(specExample)) or copy the line above.",
        "<\(specExample)>",
        "\"\(specExample)\"",
        "'\(specExample)'",
        "[\(specExample)]",
        "(\(specExample))",
        "\t\(specExample)\r\n",
        "Here:\u{00A0}\(specExample)\u{00A0}done",
        "\(specExample)\u{2028}next line",
    ])
    func linkIsFoundInSurroundingText(text: String) {
        #expect(LogLinkDraft.parse(text) == .success(Self.greekYogurt))
    }

    @Test("A full stop straight after the link stays part of it, so the last value is rejected")
    func trailingFullStopIsPartOfTheLink() {
        #expect(LogLinkDraft.parse("Tap to log: \(Self.specExample). Anything else?") == .failure(.invalidNumber(.fat)))
        #expect(LogLinkDraft.parse("Log caloryn://log?v=1&kcal=52&name=Apple.") == .success(
            LogLinkDraft(name: "Apple.", kcal: 52, grams: nil, proteinG: nil, carbsG: nil, fatG: nil, meal: nil)
        ))
    }

    @Test("The scheme and host match in any letter case", arguments: [
        "CALORYN://LOG?v=1&name=Apple&kcal=52",
        "Caloryn://Log?v=1&name=Apple&kcal=52",
        "cAlOrYn://lOg?v=1&name=Apple&kcal=52",
    ])
    func schemeAndHostIgnoreCase(text: String) {
        #expect(LogLinkDraft.parse(text) == .success(Self.apple))
    }

    @Test("Text without a log link is rejected as having no link", arguments: [
        "",
        "Greek yogurt, 150 kcal, 15 g protein",
        "caloryn://today",
        "caloryn://add-food?meal=lunch",
        "caloryn://log",
        "caloryn://log/?v=1&name=Apple&kcal=52",
        "caloryn:/log?v=1&name=Apple&kcal=52",
        "caloryn//log?v=1&name=Apple&kcal=52",
        "calorynn://log?v=1&name=Apple&kcal=52",
        "https://caloryn.app/log?v=1&name=Apple&kcal=52",
        "caloryn://logs?v=1&name=Apple&kcal=52",
        "caloryn ://log?v=1&name=Apple&kcal=52",
        "ｃａｌｏｒｙｎ://log?v=1&name=Apple&kcal=52",
    ])
    func textWithoutALinkIsRejected(text: String) {
        #expect(LogLinkDraft.parse(text) == .failure(.noLink))
    }

    @Test("More than one link is rejected so only one food is logged at a time", arguments: [
        "caloryn://log?v=1&name=Apple&kcal=52\ncaloryn://log?v=1&name=Pear&kcal=57",
        "caloryn://log?v=1&name=Apple&kcal=52 caloryn://log?v=1&name=Apple&kcal=52",
        "[caloryn://log?v=1&name=Apple&kcal=52](caloryn://log?v=1&name=Apple&kcal=52)",
        "caloryn://log?v=1&name=caloryn://log?&kcal=52",
        "CALORYN://LOG?v=1&name=Apple&kcal=52 and caloryn://log?",
    ])
    func multipleLinksAreRejected(text: String) {
        #expect(LogLinkDraft.parse(text) == .failure(.multipleLinks))
    }

    @Test("A link with a fragment is rejected", arguments: [
        "v=1&name=Apple&kcal=52#fragment",
        "v=1&name=Apple&kcal=52#",
        "v=1&name=Apple#&kcal=52",
        "#v=1&name=Apple&kcal=52",
    ])
    func fragmentIsRejected(query: String) {
        #expect(Self.parse(query: query) == .failure(.containsFragment))
    }

    @Test("An encoded hash is part of the name, not a fragment")
    func encodedHashIsAllowed() {
        #expect(Self.parsedName("No.%235%20bar") == .success("No.#5 bar"))
    }

    @Test("Text that is not a valid URL query is rejected as malformed", arguments: [
        "v=1&name=%ZZ&kcal=52",
        "v=1&name=50%&kcal=52",
        "v=1&name=%C3%28&kcal=52",
        "v=1&name=Cr\u{00E8}me&kcal=52",
        "v=1&name=a{b}&kcal=52",
        "v=1&name=a|b&kcal=52",
        "v=1&name=a\\b&kcal=52",
        "v=1&name=a[b&kcal=52",
        "v=1&&name=Apple&kcal=52",
        "v=1&name=Apple&kcal=52&",
        "v=1&=Apple&kcal=52",
    ])
    func malformedQueryIsRejected(query: String) {
        #expect(Self.parse(query: query) == .failure(.malformedLink))
    }

    @Test("A link without a version is rejected as missing it")
    func missingVersion() {
        #expect(Self.parse(query: "name=Apple&kcal=52") == .failure(.missingField(.version)))
        #expect(Self.parse(query: "V=1&name=Apple&kcal=52") == .failure(.missingField(.version)))
        #expect(Self.parse(query: "") == .failure(.missingField(.version)))
    }

    @Test("Any version other than exactly 1 asks for a newer Caloryn", arguments: [
        "v=2",
        "v=01",
        "v=1.0",
        "v=0",
        "v=",
        "v",
        "v=one",
        "v=%201",
        "v=1%20",
        "v=1+",
    ])
    func unsupportedVersionIsRejected(version: String) {
        #expect(Self.parse(query: "\(version)&name=Apple&kcal=52") == .failure(.unsupportedVersion))
    }

    @Test("A newer version is reported before the fields this version does not know")
    func newerVersionWinsOverUnknownFields() {
        #expect(Self.parse(query: "v=2&name=Apple&kcal=52&date=2026-10-24") == .failure(.unsupportedVersion))
        #expect(Self.parse(query: "date=2026-10-24&v=2") == .failure(.unsupportedVersion))
    }

    @Test("A field given twice is rejected", arguments: [
        ("v=1&v=1&name=Apple&kcal=52", LogLinkDraft.Field.version),
        ("v=1&v=2&name=Apple&kcal=52", .version),
        ("v=1&name=Apple&name=Pear&kcal=52", .name),
        ("v=1&name=Apple&kcal=52&kcal=52", .kcal),
        ("v=1&name=Apple&kcal=52&grams=100&grams=100", .grams),
        ("v=1&name=Apple&kcal=52&protein=1&protein=1", .protein),
        ("v=1&name=Apple&kcal=52&carbs=1&carbs=2", .carbs),
        ("v=1&name=Apple&kcal=52&fat=1&fat=", .fat),
        ("v=1&name=Apple&kcal=52&meal=lunch&meal=lunch", .meal),
    ])
    func duplicateFieldIsRejected(query: String, field: LogLinkDraft.Field) {
        #expect(Self.parse(query: query) == .failure(.duplicateField(field)))
    }

    @Test("A field outside the format is rejected by name", arguments: [
        ("v=1&name=Apple&kcal=52&date=2026-10-24", "date"),
        ("v=1&name=Apple&kcal=52&nutriscore=a", "nutriscore"),
        ("v=1&Name=Apple&kcal=52", "Name"),
        ("v=1&name=Apple&KCAL=52", "KCAL"),
        ("v=1&name=Apple&kcal=52&calories=52", "calories"),
        ("v=1&name=Apple&kcal=52&fiber=3", "fiber"),
        ("v=1&name=Apple&kcal=52&%20fat=1", " fat"),
        ("v=1&name=Apple&kcal=52&date=1&date=2", "date"),
    ])
    func unknownFieldIsRejected(query: String, field: String) {
        #expect(Self.parse(query: query) == .failure(.unknownField(field)))
    }

    @Test("A field name may be percent-encoded like any other query text")
    func encodedFieldNameIsDecoded() {
        #expect(Self.parse(query: "%76=1&n%61me=Apple&kcal=52") == .success(Self.apple))
    }

    @Test("A missing name or calorie value is rejected")
    func missingRequiredFields() {
        #expect(Self.parse(query: "v=1&kcal=52") == .failure(.missingField(.name)))
        #expect(Self.parse(query: "v=1&name=Apple") == .failure(.missingField(.kcal)))
        #expect(Self.parse(query: "v=1&grams=100&protein=1") == .failure(.missingField(.name)))
    }

    @Test("The name is cleaned of controls and invisible formatting before use", arguments: [
        ("Greek%20yogurt", "Greek yogurt"),
        ("Greek+yogurt", "Greek+yogurt"),
        ("%20%20Greek%20%20%20yogurt%20%20", "Greek yogurt"),
        ("Greek%0Ayogurt", "Greek yogurt"),
        ("Greek%0D%0Ayogurt", "Greek yogurt"),
        ("Greek%09yogurt", "Greek yogurt"),
        ("Greek%0A%0A%09%20yogurt", "Greek yogurt"),
        ("Greek%C2%A0yogurt", "Greek yogurt"),
        ("Greek%E2%80%A8yogurt", "Greek yogurt"),
        ("%E2%80%AEtrugoy%20keerG", "trugoy keerG"),
        ("Greek%E2%80%AE%20yogurt%E2%80%AC", "Greek yogurt"),
        ("Gre%E2%80%8Bek%20yogurt", "Greek yogurt"),
        ("Greek%20%E2%80%8B%20yogurt", "Greek yogurt"),
        ("%EF%BB%BFGreek%20yogurt", "Greek yogurt"),
        ("Gr%00eek%20yo%07gurt%7F", "Greek yogurt"),
        ("Cr%C3%A8me%20br%C3%BBl%C3%A9e", "Crème brûlée"),
        ("Ben%20%26%20Jerry%27s", "Ben & Jerry's"),
        ("Yogurt%20(Greek%2C%20plain%29", "Yogurt (Greek, plain)"),
        ("%F0%9F%8D%93%20Strawberries", "🍓 Strawberries"),
        ("a=b", "a=b"),
        ("50%25%20fat", "50% fat"),
    ])
    func nameIsCleaned(encoded: String, expected: String) {
        #expect(Self.parsedName(encoded) == .success(expected))
    }

    @Test("A name that is empty once cleaned is rejected", arguments: [
        "v=1&name=&kcal=52",
        "v=1&name&kcal=52",
        "v=1&name=%20%20%20&kcal=52",
        "v=1&name=%0A%09%0D&kcal=52",
        "v=1&name=%E2%80%8B%E2%80%AE%E2%80%8D&kcal=52",
        "v=1&name=%00%01%1F&kcal=52",
        "v=1&name=%C2%A0%E3%80%80&kcal=52",
    ])
    func emptyNameIsRejected(query: String) {
        #expect(Self.parse(query: query) == .failure(.emptyName))
    }

    @Test("A name of up to 100 characters after cleaning is kept whole")
    func hundredCharacterName() {
        let hundred = String(repeating: "a", count: 100)
        let padded = "%20%20" + String(repeating: "a", count: 50) + "%E2%80%8B" + String(repeating: "a", count: 50) + "%0A"

        #expect(Self.parsedName(hundred) == .success(hundred))
        #expect(Self.parsedName(padded) == .success(hundred))
        #expect(Self.parsedName("a") == .success("a"))
    }

    @Test("A name longer than 100 characters after cleaning is rejected, not truncated")
    func longNameIsRejected() {
        let hundredAndOne = String(repeating: "a", count: 101)
        let paddedHundredAndOne = "%20" + String(repeating: "a", count: 100) + "%20a"

        #expect(Self.parsedName(hundredAndOne) == .failure(.nameTooLong))
        #expect(Self.parsedName(paddedHundredAndOne) == .failure(.nameTooLong))
    }

    @Test("Combining marks count toward the name limit, so one letter cannot carry unbounded text")
    func combiningMarksCountTowardTheLimit() {
        let stacked = "a" + String(repeating: "%CC%81", count: 100)

        #expect(Self.parsedName(stacked) == .failure(.nameTooLong))
        #expect(Self.parsedName("e%CC%81") == .success("e\u{0301}"))
    }

    @Test("Plain decimal numbers are read exactly", arguments: [
        ("0", 0.0),
        ("52", 52),
        ("150.5", 150.5),
        ("150.25", 150.25),
        ("007", 7),
        ("000150", 150),
        ("0.01", 0.01),
        ("19999.99", 19_999.99),
        ("20000", 20_000),
        ("20000.0", 20_000),
        ("20000.00", 20_000),
    ])
    func plainNumberIsRead(raw: String, expected: Double) {
        #expect(Self.parsedKcal(raw) == .success(expected))
    }

    @Test("Anything but digits with up to two decimals is rejected as an invalid number", arguments: [
        "1,500",
        "1%2C500",
        "+5",
        "%2B5",
        "-5",
        "1e3",
        "1E3",
        "NaN",
        "nan",
        "inf",
        "Infinity",
        ".5",
        "5.",
        "5.123",
        "1.2.3",
        "1234567",
        "0001234567",
        "%20150",
        "150%20",
        "150%0A",
        "150%09",
        "150kcal",
        "150%20kcal",
        "",
        "0x10",
        "%D9%A1%D9%A5%D9%A0",
        "%EF%BC%91%EF%BC%95%EF%BC%90",
        "1%E2%80%8B50",
        "150.5%CC%81",
    ])
    func invalidNumberIsRejected(raw: String) {
        #expect(Self.parsedKcal(raw) == .failure(.invalidNumber(.kcal)))
    }

    @Test("A raw space ends the link, so a spaced calorie value never reaches the parser as a number")
    func rawSpaceEndsTheLink() {
        #expect(LogLinkDraft.parse("caloryn://log?v=1&name=Apple&kcal= 52") == .failure(.invalidNumber(.kcal)))
        #expect(LogLinkDraft.parse("caloryn://log?v=1&name=Green apple&kcal=52") == .failure(.missingField(.kcal)))
    }

    @Test("Every number field applies the same strict number format", arguments: [
        LogLinkDraft.Field.grams, .protein, .carbs, .fat,
    ])
    func everyNumberFieldIsStrict(field: LogLinkDraft.Field) {
        for raw in ["1,5", "-1", "+1", "1e2", "NaN", ".5", "5.", "1.234", "1234567", "5g", ""] {
            #expect(
                Self.parse(query: "v=1&name=Apple&kcal=52&\(field.rawValue)=\(raw)") == .failure(.invalidNumber(field)),
                "\(field.rawValue)=\(raw)"
            )
        }
    }

    @Test("Calories must lie between 0 and 20000", arguments: [
        ("0", 0.0 as Double?),
        ("20000", 20_000),
        ("20000.01", nil),
        ("20001", nil),
        ("999999.99", nil),
    ])
    func calorieRange(raw: String, accepted: Double?) {
        let result = Self.parsedKcal(raw)

        if let accepted {
            #expect(result == .success(accepted))
        } else {
            #expect(result == .failure(.outOfRange(.kcal)))
        }
    }

    @Test("Grams must be a safe portion: above 0 and at most 100000", arguments: [
        ("0.01", 0.01 as Double?),
        ("1", 1),
        ("100000", 100_000),
        ("100000.00", 100_000),
        ("0", nil),
        ("0.00", nil),
        ("100000.01", nil),
        ("999999.99", nil),
    ])
    func gramsRange(raw: String, accepted: Double?) {
        let result = Self.parse(query: "v=1&name=Apple&kcal=52&grams=\(raw)").map(\.grams)

        if let accepted {
            #expect(result == .success(accepted))
        } else {
            #expect(result == .failure(.outOfRange(.grams)))
        }
    }

    @Test("Each macro must lie between 0 and 5000 g", arguments: [
        LogLinkDraft.Field.protein, .carbs, .fat,
    ])
    func macroRange(field: LogLinkDraft.Field) {
        let link = "v=1&name=Apple&kcal=52&\(field.rawValue)="

        #expect(Self.parse(query: link + "0").map { Self.macro(field, of: $0) } == .success(0))
        #expect(Self.parse(query: link + "5000").map { Self.macro(field, of: $0) } == .success(5_000))
        #expect(Self.parse(query: link + "5000.01") == .failure(.outOfRange(field)))
        #expect(Self.parse(query: link + "999999") == .failure(.outOfRange(field)))
    }

    @Test("A macro may not weigh more than the portion it belongs to", arguments: [
        LogLinkDraft.Field.protein, .carbs, .fat,
    ])
    func macroCannotExceedGrams(field: LogLinkDraft.Field) {
        let link = "v=1&name=Apple&kcal=52&grams=10&\(field.rawValue)="

        #expect(Self.parse(query: link + "10").map { Self.macro(field, of: $0) } == .success(10))
        #expect(Self.parse(query: link + "10.01") == .failure(.exceedsPortion(field)))
        #expect(Self.parse(query: link + "4000") == .failure(.exceedsPortion(field)))
    }

    @Test("Without grams a macro is checked only against its own range")
    func macroWithoutGrams() {
        #expect(Self.parse(query: "v=1&name=Oil&kcal=884&fat=4000").map(\.fatG) == .success(4_000))
    }

    @Test("A macro given as 0 is a real 0, and an omitted macro stays unknown")
    func zeroMacroIsNotMissing() {
        let zeros = Self.parse(query: "v=1&name=Water&kcal=0&protein=0&carbs=0&fat=0")
        let omitted = Self.parse(query: "v=1&name=Water&kcal=0")

        #expect(zeros.map(\.proteinG) == .success(0))
        #expect(zeros.map(\.carbsG) == .success(0))
        #expect(zeros.map(\.fatG) == .success(0))
        #expect(omitted.map(\.proteinG) == .success(nil))
        #expect(omitted.map(\.carbsG) == .success(nil))
        #expect(omitted.map(\.fatG) == .success(nil))
    }

    @Test("Each meal name in lowercase is accepted", arguments: WidgetMeal.allCases)
    func mealIsAccepted(meal: WidgetMeal) {
        #expect(Self.parse(query: "v=1&name=Apple&kcal=52&meal=\(meal.rawValue)").map(\.meal) == .success(meal))
    }

    @Test("Any other meal text is rejected", arguments: [
        "Lunch",
        "LUNCH",
        "brunch",
        "",
        "%20lunch",
        "lunch%20",
        "supper",
        "snack1",
    ])
    func invalidMealIsRejected(raw: String) {
        #expect(Self.parse(query: "v=1&name=Apple&kcal=52&meal=\(raw)") == .failure(.invalidMeal))
    }

    @Test("A megabyte of pasted text without a link is rejected without crashing")
    func megabyteOfProse() {
        let prose = String(repeating: "Greek yogurt is a good snack. ", count: 35_000)

        #expect(prose.utf8.count > 1_000_000)
        #expect(LogLinkDraft.parse(prose) == .failure(.noLink))
    }

    @Test("A link inside a megabyte of prose is still found")
    func linkInsideAMegabyteOfProse() {
        let prose = String(repeating: "Greek yogurt is a good snack. ", count: 17_500)

        #expect(LogLinkDraft.parse(prose + Self.specExample + " " + prose) == .success(Self.greekYogurt))
    }

    @Test("A megabyte-long name or number is rejected without crashing")
    func megabyteLongValues() {
        let megabyte = String(repeating: "a", count: 1_000_000)
        let digits = String(repeating: "1", count: 1_000_000)

        #expect(Self.parsedName(megabyte) == .failure(.nameTooLong))
        #expect(Self.parsedKcal(digits) == .failure(.invalidNumber(.kcal)))
        #expect(LogLinkDraft.parse(String(repeating: "caloryn://log?", count: 75_000)) == .failure(.multipleLinks))
    }

    @Test("Arbitrary pastes never crash, and anything accepted stays inside every bound")
    func arbitraryPastesStayInBounds() {
        var generator = SplitMix64(seed: 0x10C_11A4)
        var acceptedCount = 0

        for _ in 0..<3_000 {
            let text = Self.arbitraryPaste(using: &generator)
            guard case .success(let draft) = LogLinkDraft.parse(text) else { continue }
            acceptedCount += 1

            #expect(!draft.name.isEmpty, "\(text)")
            #expect(draft.name.unicodeScalars.count <= 100, "\(text)")
            #expect(draft.name == draft.name.trimmingCharacters(in: .whitespaces), "\(text)")
            #expect(!draft.name.contains("  "), "\(text)")
            #expect(
                draft.name.unicodeScalars.allSatisfy { ![.control, .format].contains($0.properties.generalCategory) },
                "\(text)"
            )
            #expect((0...20_000).contains(draft.kcal), "\(text)")
            if let grams = draft.grams {
                #expect(grams > 0 && grams <= 100_000, "\(text)")
            }
            for macro in [draft.proteinG, draft.carbsG, draft.fatG].compactMap({ $0 }) {
                #expect((0...5_000).contains(macro), "\(text)")
                #expect(macro <= (draft.grams ?? .infinity), "\(text)")
            }
        }

        #expect(acceptedCount > 0)
    }

    @Test("Every rejection explains itself in words the user can act on", arguments: [
        (LogLinkRejection.noLink,
         "No Caloryn link found. Copy the chatbot’s reply with the line that starts with caloryn://log?, then paste again."),
        (.multipleLinks, "The text contains more than one Caloryn link. Paste one food at a time."),
        (.malformedLink, "The link is damaged or incomplete. Ask your chatbot to send it again in a code block."),
        (.containsFragment, "The link contains a “#”, which Caloryn doesn’t accept. Ask your chatbot for a new link."),
        (.unsupportedVersion, "This link was made for a newer version of Caloryn. Update Caloryn, then paste it again."),
        (.unknownField("date"),
         "The link has a field Caloryn doesn’t recognize. It may only contain v, name, kcal, grams, protein, carbs, fat and meal."),
        (.duplicateField(.kcal), "The link gives the calorie value more than once."),
        (.missingField(.version), "The link has no version number."),
        (.missingField(.name), "The link has no food name."),
        (.missingField(.kcal), "The link has no calorie value."),
        (.emptyName, "The food name is empty."),
        (.nameTooLong, "The food name is longer than 100 characters."),
        (.invalidNumber(.grams),
         "The portion weight isn’t a plain number. Use digits with up to two decimals, such as 150 or 12.5, without units, signs or commas."),
        (.outOfRange(.kcal), "The calorie value must be between 0 and 20,000."),
        (.outOfRange(.grams), "The portion weight must be more than 0 g and no more than 100,000 g."),
        (.outOfRange(.protein), "The protein amount must be between 0 and 5,000 g."),
        (.outOfRange(.carbs), "The carbs amount must be between 0 and 5,000 g."),
        (.outOfRange(.fat), "The fat amount must be between 0 and 5,000 g."),
        (.exceedsPortion(.fat), "The fat amount can’t be more than the portion weight."),
        (.invalidMeal, "The meal must be breakfast, lunch, snack or dinner, in lowercase."),
    ])
    func rejectionMessage(rejection: LogLinkRejection, message: String) {
        #expect(rejection.errorDescription == message)
        #expect(rejection.localizedDescription == message)
    }

    @Test("An unknown field’s message never repeats text from the paste")
    func unknownFieldMessageDoesNotEchoThePaste() throws {
        let rejection = try #require(Self.parse(query: "v=1&name=Apple&kcal=52&%E2%80%AEevil=1").failureValue)

        #expect(rejection == .unknownField("\u{202E}evil"))
        #expect(rejection.errorDescription?.contains("evil") == false)
    }

    private static func macro(_ field: LogLinkDraft.Field, of draft: LogLinkDraft) -> Double? {
        switch field {
        case .protein: draft.proteinG
        case .carbs: draft.carbsG
        case .fat: draft.fatG
        default: nil
        }
    }

    private static let arbitraryVersions = ["v=1", "v=1", "v=1", "v=2", ""]

    private static let arbitraryNames = [
        "name=Apple", "name=Greek%20yogurt", "name=%E2%80%AE%20x%0A%E2%80%8B", "name=%20", "",
        "name=" + String(repeating: "a", count: 101),
    ]

    private static let arbitraryCalories = ["kcal=52", "kcal=0", "kcal=20000", "kcal=20000.01", "kcal=1,5", ""]

    private static let arbitraryExtras = [
        "grams=100", "grams=10", "grams=0.01", "grams=0", "grams=100000.01",
        "protein=5", "protein=10.01", "protein=5000", "carbs=0", "carbs=150", "fat=4", "fat=",
        "meal=lunch", "meal=Lunch", "date=today", "%ZZ", "#x", "",
    ]

    private static let arbitraryWrappers = [
        ("", ""), ("`", "`"), ("[Log](", ")"), ("<", ">"), ("Here you go:\n", "\nEnjoy!"), ("\"", "\""),
    ]

    private static let arbitraryPrefixes = ["caloryn://log?", "caloryn://log?", "CALORYN://LOG?", "caloryn://log", ""]

    private static func arbitraryPaste(using generator: inout SplitMix64) -> String {
        let required = [arbitraryVersions, arbitraryNames, arbitraryCalories].map {
            $0.randomElement(using: &generator) ?? ""
        }
        let extras = (0..<Int.random(in: 0...4, using: &generator)).map { _ in
            arbitraryExtras.randomElement(using: &generator) ?? ""
        }
        var fields = required + extras
        fields.shuffle(using: &generator)

        let prefix = arbitraryPrefixes.randomElement(using: &generator) ?? ""
        let (opening, closing) = arbitraryWrappers.randomElement(using: &generator) ?? ("", "")
        return opening + prefix + fields.joined(separator: "&") + closing
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

private extension Result {
    var failureValue: Failure? {
        guard case .failure(let failure) = self else { return nil }
        return failure
    }
}
