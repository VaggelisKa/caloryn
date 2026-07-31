import Foundation

/// How a portion is being expressed, and the quantity behind it.
///
/// The portion picker offers up to three ways of saying the same thing —
/// grams, countable servings ("2 slices"), or a fraction of a recipe — and the
/// grams are the single truth all three agree on. Switching modes, typing a
/// weight or moving a wheel has to reconcile the others without the number
/// drifting, which is the whole reason this lives outside the view.
struct PortionSelection: Equatable {
    /// The traits of a food that affect how a portion can be expressed.
    /// Deliberately not a `FoodItem`: these five facts are all that matter, and
    /// naming them keeps the rules honest about what they depend on.
    struct Shape: Equatable {
        var isRecipe: Bool
        /// Grams in one countable serving, when the food has one.
        var servingGramsPerUnit: Double?
        var defaultServingGrams: Double?

        init(
            isRecipe: Bool = false,
            servingGramsPerUnit: Double? = nil,
            defaultServingGrams: Double? = nil
        ) {
            self.isRecipe = isRecipe
            self.servingGramsPerUnit = servingGramsPerUnit
            self.defaultServingGrams = defaultServingGrams
        }

        init(foodItem: FoodItem) {
            isRecipe = foodItem.isRecipe
            servingGramsPerUnit = foodItem.servingInfo?.gramsPerUnit
            defaultServingGrams = foodItem.defaultServingG
        }

        var hasCountableServing: Bool { servingGramsPerUnit != nil }
    }

    enum Mode: Hashable {
        case grams
        case serving
        case recipeServing
    }

    struct RecipeServingOption: Identifiable, Hashable {
        let id: String
        let label: String
        let multiplier: Double

        static let one = RecipeServingOption(id: "1", label: "1", multiplier: 1)
    }

    static let recipeServingOptions: [RecipeServingOption] = [
        RecipeServingOption(id: "quarter", label: "1/4", multiplier: 0.25),
        RecipeServingOption(id: "half", label: "1/2", multiplier: 0.5),
        .one,
        RecipeServingOption(id: "2", label: "2", multiplier: 2),
        RecipeServingOption(id: "3", label: "3", multiplier: 3),
        RecipeServingOption(id: "4", label: "4", multiplier: 4)
    ]

    /// Grams are typed, not spun, so the only bounds left are the ones that
    /// keep a mistyped number from becoming a nonsense log: a portion is at
    /// least a gram and at most 10kg, past any real recipe.
    static let minimumGrams = 1
    static let maximumGrams = 10_000

    /// The shortcuts offered beside the field. Three, because they share the
    /// row with the unit wheel and a fourth would not fit.
    static let quickGramOptionCount = 3
    /// What the shortcuts offer a food that knows nothing about its own
    /// serving — round numbers, since there is nothing better to scale.
    static let fallbackQuickGramOptions = [50, 100, 200]

    /// Countable servings are capped so the wheel stays usable, and floored at
    /// two so a picker with a single choice is never shown.
    static let minimumServingCountLimit = 2
    static let maximumServingCountLimit = 10
    static let servingCountGramCeiling: Double = 500

    /// Changed through `update(shape:)` rather than assigned, because a new
    /// shape can invalidate the current mode.
    private(set) var shape: Shape
    private(set) var portionGrams: Double
    var mode: Mode
    /// What the grams field currently shows. Free text while the user is mid-
    /// edit — `commitGramsInput()` is what turns it back into a portion.
    var gramsInput: String
    var servingCount: Int
    var recipeServingID: String

    /// Builds the opening state for a food.
    ///
    /// A brand-new log starts in whichever expressive mode the food supports.
    /// Re-opening a saved entry only does so when the saved grams still line up
    /// with a whole serving — otherwise the entry is shown in grams, so that
    /// editing "137 g" does not silently round it to "1 slice".
    init(shape: Shape, initialGrams: Double, isExistingEntry: Bool) {
        self.shape = shape
        portionGrams = initialGrams
        gramsInput = Self.formattedGrams(initialGrams)
        servingCount = 1
        recipeServingID = RecipeServingOption.one.id
        mode = .grams

        if shape.isRecipe {
            let total = shape.recipeTotalGrams
            recipeServingID = Self.nearestRecipeServingOptionID(
                for: initialGrams,
                recipeTotalGrams: total
            )
            let matchesServing = Self.recipeServingOption(id: recipeServingID)
                .map { Self.isApproximatelyEqual(total * $0.multiplier, initialGrams) } == true
            mode = (!isExistingEntry || matchesServing) ? .recipeServing : .grams
        } else if let gramsPerUnit = shape.servingGramsPerUnit {
            servingCount = Self.normalizedServingCount(for: initialGrams, shape: shape)
            let matchesServing = Self.isApproximatelyEqual(
                Double(servingCount) * gramsPerUnit,
                initialGrams
            )
            mode = (!isExistingEntry || matchesServing) ? .serving : .grams
        }
    }

    // MARK: - Options

    /// The shortcut amounts offered beside the field, scaled to whatever the
    /// food knows about itself: multiples of a countable serving, fractions of
    /// a recipe, and round numbers for a food with neither.
    var quickGramOptions: [Int] { Self.quickGramOptions(for: shape) }

    var maxServingCount: Int { Self.maxServingCount(for: shape) }

    var selectedRecipeServingOption: RecipeServingOption? {
        Self.recipeServingOption(id: recipeServingID)
    }

    // MARK: - Reconciliation

    /// The user typed a character.
    ///
    /// The calorie readout follows every keystroke, so a weight that already
    /// reads as a number takes effect immediately. Text that does not — an
    /// empty box on the way to a new number — leaves the portion where it was
    /// rather than blanking the preview to zero. The text is deliberately left
    /// alone here: reformatting mid-edit would fight the cursor.
    mutating func gramsInputChanged() {
        guard mode == .grams, let typed = Self.parsedGrams(gramsInput) else { return }
        setGrams(Double(typed))
    }

    /// The user finished typing in the grams field.
    ///
    /// Anything the field cannot mean — an empty box mid-edit, a stray minus,
    /// a pasted word — leaves the portion where it was rather than zeroing it,
    /// and the text snaps back to show what is actually logged.
    mutating func commitGramsInput() {
        guard mode == .grams else {
            gramsInput = Self.formattedGrams(portionGrams)
            return
        }
        if let typed = Self.parsedGrams(gramsInput) {
            setGrams(Double(typed))
        }
        gramsInput = Self.formattedGrams(portionGrams)
    }

    /// The user tapped one of the shortcut amounts.
    mutating func quickGramOptionChosen(_ grams: Int) {
        guard mode == .grams else { return }
        setGrams(Double(Self.clampedGrams(grams)))
        gramsInput = Self.formattedGrams(portionGrams)
    }

    private mutating func setGrams(_ grams: Double) {
        portionGrams = grams
        if shape.isRecipe {
            recipeServingID = Self.nearestRecipeServingOptionID(
                for: portionGrams,
                recipeTotalGrams: shape.recipeTotalGrams
            )
        }
    }

    /// The user changed how many servings.
    mutating func servingCountChanged() {
        guard mode == .serving, let gramsPerUnit = shape.servingGramsPerUnit else { return }
        portionGrams = Double(servingCount) * gramsPerUnit
    }

    /// The user picked a different fraction of the recipe.
    mutating func recipeServingChanged() {
        guard mode == .recipeServing, let option = selectedRecipeServingOption else { return }
        portionGrams = shape.recipeTotalGrams * option.multiplier
        gramsInput = Self.formattedGrams(portionGrams)
    }

    /// The user switched how the portion is expressed. A wheel can only stop on
    /// a row it offers, so switching *into* one still moves the grams to the
    /// nearest figure it can show. Grams no longer round at all — the field can
    /// hold whatever the other modes produce.
    mutating func modeChanged() {
        switch mode {
        case .grams:
            gramsInput = Self.formattedGrams(portionGrams)
        case .serving:
            guard let gramsPerUnit = shape.servingGramsPerUnit else { return }
            servingCount = max(1, min(maxServingCount, round(portionGrams / gramsPerUnit).truncatedSafely))
            portionGrams = Double(servingCount) * gramsPerUnit
        case .recipeServing:
            recipeServingID = Self.nearestRecipeServingOptionID(
                for: portionGrams,
                recipeTotalGrams: shape.recipeTotalGrams
            )
            if let option = selectedRecipeServingOption {
                portionGrams = shape.recipeTotalGrams * option.multiplier
            }
        }
    }

    // MARK: - The food changing underneath

    /// Whether a mode can express a portion of this food at all.
    func supports(_ mode: Mode) -> Bool {
        switch mode {
        case .grams: true
        case .serving: shape.hasCountableServing
        case .recipeServing: shape.isRecipe
        }
    }

    /// Takes on a new shape after the food is edited inline.
    ///
    /// Editing a food can remove the thing the current mode is expressed in —
    /// saving an edit clears the serving description, so a food measured in
    /// slices stops having slices. Without this the picker would keep showing a
    /// count wheel for a food that can no longer be counted, with no control to
    /// switch back and a quantity nothing could move.
    ///
    /// The grams are deliberately left alone. They are what the user is
    /// actually logging, and editing a food's details must not quietly change
    /// how much of it was logged — so the wheels are re-derived from the grams,
    /// never the other way round.
    mutating func update(shape newShape: Shape) {
        shape = newShape

        if !supports(mode) {
            mode = .grams
        }

        switch mode {
        case .grams:
            gramsInput = Self.formattedGrams(portionGrams)
        case .serving:
            servingCount = Self.normalizedServingCount(for: portionGrams, shape: shape)
        case .recipeServing:
            recipeServingID = Self.nearestRecipeServingOptionID(
                for: portionGrams,
                recipeTotalGrams: shape.recipeTotalGrams
            )
        }
    }

    // MARK: - Rules

    static func recipeServingOption(id: String) -> RecipeServingOption? {
        recipeServingOptions.first { $0.id == id }
    }

    static func nearestRecipeServingOptionID(for grams: Double, recipeTotalGrams: Double) -> String {
        guard recipeTotalGrams > 0 else { return RecipeServingOption.one.id }
        let multiplier = grams / recipeTotalGrams
        return recipeServingOptions.min {
            abs($0.multiplier - multiplier) < abs($1.multiplier - multiplier)
        }?.id ?? RecipeServingOption.one.id
    }

    static func maxServingCount(for shape: Shape) -> Int {
        guard let gramsPerUnit = shape.servingGramsPerUnit else { return 1 }
        return max(
            minimumServingCountLimit,
            min(maximumServingCountLimit, (servingCountGramCeiling / gramsPerUnit).truncatedSafely)
        )
    }

    static func normalizedServingCount(for grams: Double, shape: Shape) -> Int {
        guard let gramsPerUnit = shape.servingGramsPerUnit else { return 1 }
        let count = round(grams / gramsPerUnit).truncatedSafely
        return max(1, min(maxServingCount(for: shape), count))
    }

    /// The shortcut amounts for a food.
    ///
    /// A food that counts in slices gets one, two and three slices; a recipe
    /// gets a quarter, a half and the whole thing; a food that knows neither
    /// gets round numbers. Duplicates and out-of-range values are dropped, so a
    /// serving so large that every multiple clamps to 10kg falls back to the
    /// round numbers rather than showing "10000" three times.
    static func quickGramOptions(for shape: Shape) -> [Int] {
        let raw: [Double] = if shape.isRecipe {
            [0.25, 0.5, 1].map { shape.recipeTotalGrams * $0 }
        } else if let gramsPerUnit = shape.servingGramsPerUnit {
            (1...quickGramOptionCount).map { Double($0) * gramsPerUnit }
        } else {
            []
        }

        let options = raw
            .filter { $0.isFinite && $0 >= Double(minimumGrams) && $0 <= Double(maximumGrams) }
            .map { $0.rounded().truncatedSafely }

        let deduplicated = NSOrderedSet(array: options).array as? [Int] ?? []
        return deduplicated.count == quickGramOptionCount ? deduplicated : fallbackQuickGramOptions
    }

    /// Whole grams only, within range. `nil` for anything the field cannot
    /// mean, which the caller reads as "leave the portion alone".
    static func parsedGrams(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isWholeNumber), let value = Int(trimmed) else {
            return nil
        }
        return clampedGrams(value)
    }

    static func clampedGrams(_ grams: Int) -> Int {
        max(minimumGrams, min(maximumGrams, grams))
    }

    /// How a portion reads in the field. Whole grams lose their decimal point,
    /// but a portion scaled in from elsewhere keeps its fraction rather than
    /// being silently rounded on display.
    static func formattedGrams(_ grams: Double) -> String {
        guard grams.isFinite else { return "\(minimumGrams)" }
        if grams.rounded() == grams {
            return "\(grams.truncatedSafely)"
        }
        return grams.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }

    static func isApproximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}

extension PortionSelection.Shape {
    /// A recipe's stated total, falling back to 100g so the fraction options
    /// still mean something for a recipe with no recorded yield.
    var recipeTotalGrams: Double {
        defaultServingGrams ?? 100
    }
}
