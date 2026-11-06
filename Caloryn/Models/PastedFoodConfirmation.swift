import Foundation

struct PastedFoodConfirmation: Equatable {
    enum NameBlocker: Equatable {
        case missing
        case tooLong
    }

    enum PortionBlocker: Equatable {
        case gramsMissing
        case gramsNotANumber
        case gramsOutOfRange
        case portionLighterThan(LogLinkNutrient, grams: Double)
    }

    static let notProvided = "Not provided"

    var nameInput: String
    let kcal: Double
    let nutrients: [LogLinkNutrient: Double]
    var gramsInput: String

    init(draft: LogLinkDraft, locale: Locale = .current) {
        nameInput = draft.name
        kcal = draft.kcal
        nutrients = draft.nutrients
        gramsInput = draft.grams.map { Self.editableGrams($0, locale: locale) } ?? ""
    }

    static func opening(
        pasted strings: [String],
        locale: Locale = .current
    ) -> Result<PastedFoodConfirmation, LogLinkRejection> {
        LogLinkDraft.parse(strings.joined(separator: "\n"))
            .map { PastedFoodConfirmation(draft: $0, locale: locale) }
    }

    func grams(of nutrient: LogLinkNutrient) -> Double? {
        nutrients[nutrient]
    }

    var shownNutrients: [LogLinkNutrient] {
        LogLinkNutrient.allCases.filter { $0.isCore || nutrients[$0] != nil }
    }

    var portionBlocker: PortionBlocker? {
        let typed = gramsInput.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return .gramsMissing }
        guard let grams = typed.decimalInputValue else { return .gramsNotANumber }
        guard FavoriteFoodLogging.isSafePortion(grams) else { return .gramsOutOfRange }
        if let heaviest = heaviestNutrient, heaviest.grams > grams {
            return .portionLighterThan(heaviest.nutrient, grams: heaviest.grams)
        }
        return nil
    }

    var name: String {
        LogLinkDraft.normalizedName(nameInput)
    }

    var nameBlocker: NameBlocker? {
        if name.isEmpty { return .missing }
        if name.unicodeScalars.count > LogLinkDraft.maximumNameLength { return .tooLong }
        return nil
    }

    var nameBlockedReason: String? {
        switch nameBlocker {
        case nil:
            nil
        case .missing:
            "Enter a name to add this food."
        case .tooLong:
            "The name can’t be longer than \(LogLinkDraft.maximumNameLength) characters."
        }
    }

    var canAdd: Bool { nameBlocker == nil && portionBlocker == nil }

    var portionGrams: Double? {
        guard canAdd else { return nil }
        return gramsInput.decimalInputValue
    }

    func portionBlockedReason(locale: Locale = .current) -> String? {
        switch portionBlocker {
        case nil:
            nil
        case .gramsMissing:
            "Enter the portion weight in grams to add this food."
        case .gramsNotANumber:
            "Enter the portion weight as a number, such as 150 or 12.5."
        case .gramsOutOfRange:
            "The portion must be more than 0 g and no more than 100,000 g."
        case .portionLighterThan(let nutrient, let grams):
            "The portion can’t weigh less than its \(Self.amount(grams, of: nutrient, locale: locale)) of \(nutrient.label.lowercased())."
        }
    }

    func caloriesText(locale: Locale = .current) -> String {
        "\(Self.displayed(kcal, locale: locale)) kcal"
    }

    func amountText(of nutrient: LogLinkNutrient, locale: Locale = .current) -> String {
        guard let grams = grams(of: nutrient) else { return Self.notProvided }
        return Self.amount(grams, of: nutrient, locale: locale)
    }

    func matchesLoggedFood(named loggedName: String, calories loggedCalories: Double) -> Bool {
        loggedCalories.rounded() == kcal.rounded()
            && loggedName.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(name, options: .caseInsensitive)
                == .orderedSame
    }

    func alreadyLoggedMessage(locale: Locale = .current) -> String {
        "\(name) with \(caloriesText(locale: locale)) is already in your log for this day."
    }

    private var heaviestNutrient: (nutrient: LogLinkNutrient, grams: Double)? {
        LogLinkNutrient.allCases
            .compactMap { nutrient in grams(of: nutrient).map { (nutrient: nutrient, grams: $0) } }
            .max { $0.grams < $1.grams }
    }

    private static func amount(_ grams: Double, of nutrient: LogLinkNutrient, locale: Locale) -> String {
        let shown = displayed(nutrient.linkValue(fromGrams: grams), locale: locale)
        switch nutrient.unit {
        case .grams: return "\(shown) g"
        case .milligrams: return "\(shown) mg"
        }
    }

    private static func displayed(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }

    private static func editableGrams(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)).locale(locale))
    }
}
