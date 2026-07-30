import Foundation

/// How a portion is being expressed, and the quantity behind it.
///
/// The portion picker offers up to three ways of saying the same thing —
/// grams, countable servings ("2 slices"), or a fraction of a recipe — and the
/// grams are the single truth all three agree on. Switching modes or moving a
/// wheel has to reconcile the others without the number drifting, which is the
/// whole reason this lives outside the view.
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

    /// The gram wheel moves in 5g steps and never offers less than 500g, so a
    /// large portion is always reachable.
    static let gramStepSize = 5
    static let minimumGramOption = 5
    static let minimumGramOptionLimit = 500
    /// The wheel is a materialized `Array`, one row per 5g step, so its ceiling
    /// is a row count as much as a weight: 10kg is 2,000 rows, past any real
    /// recipe and still instant to build. Without it a serving size straight
    /// off the food API sets the ceiling — 50kg is ten million rows, and a
    /// serving past `Int.max` clamps to `Int.max` and never finishes at all.
    static let maximumGramOptionLimit = 10_000

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
    var gramStep: Int
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
        gramStep = Self.normalizedGramStep(initialGrams, limit: Self.gramOptionLimit(for: shape))
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

    var gramOptions: [Int] {
        Array(stride(
            from: Self.minimumGramOption,
            through: Self.gramOptionLimit(for: shape),
            by: Self.gramStepSize
        ))
    }

    var maxServingCount: Int { Self.maxServingCount(for: shape) }

    var selectedRecipeServingOption: RecipeServingOption? {
        Self.recipeServingOption(id: recipeServingID)
    }

    // MARK: - Reconciliation

    /// The user moved the gram wheel.
    mutating func gramStepChanged() {
        guard mode == .grams else { return }
        portionGrams = Double(gramStep)
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
        gramStep = Self.normalizedGramStep(portionGrams, limit: Self.gramOptionLimit(for: shape))
    }

    /// The user switched how the portion is expressed. The grams move to the
    /// nearest value the new mode can represent, rather than staying at a
    /// figure its wheel cannot show.
    mutating func modeChanged() {
        switch mode {
        case .grams:
            let nearest = Self.normalizedGramStep(portionGrams, limit: Self.gramOptionLimit(for: shape))
            gramStep = nearest
            portionGrams = Double(nearest)
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
            gramStep = Self.normalizedGramStep(portionGrams, limit: Self.gramOptionLimit(for: shape))
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

    /// The largest value the gram wheel offers: always at least 500g, more when
    /// the food's own serving (or four of a recipe's) exceeds that, and never
    /// past `maximumGramOptionLimit` — the wheel is materialized row by row, so
    /// an unbounded serving size is an unbounded array.
    static func gramOptionLimit(for shape: Shape) -> Int {
        let defaultServing = shape.recipeTotalGrams
        let step = Double(gramStepSize)
        let largestMultiplier = shape.isRecipe
            ? (recipeServingOptions.map(\.multiplier).max() ?? 1)
            : 1
        let servingLimit = (ceil(defaultServing * largestMultiplier / step) * step).truncatedSafely

        return min(maximumGramOptionLimit, max(minimumGramOptionLimit, servingLimit))
    }

    static func normalizedGramStep(_ grams: Double, limit: Int) -> Int {
        max(
            minimumGramOption,
            min(limit, (round(grams / Double(gramStepSize)) * Double(gramStepSize)).truncatedSafely)
        )
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
