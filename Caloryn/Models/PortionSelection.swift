import Foundation

struct PortionSelection: Equatable {
    struct Shape: Equatable {
        var isRecipe: Bool
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

    static let minimumGrams = 1
    static let maximumGrams = 10_000

    static let quickGramOptionCount = 3
    static let fallbackQuickGramOptions = [50, 100, 200]

    static let minimumServingCountLimit = 2
    static let maximumServingCountLimit = 10
    static let servingCountGramCeiling: Double = 500

    private(set) var shape: Shape
    private(set) var portionGrams: Double
    var mode: Mode
    var gramsInput: String
    var servingCount: Int
    var recipeServingID: String

    init(shape: Shape, initialGrams: Double, preservesExactGrams: Bool) {
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
            mode = (!preservesExactGrams || matchesServing) ? .recipeServing : .grams
        } else if let gramsPerUnit = shape.servingGramsPerUnit {
            servingCount = Self.normalizedServingCount(for: initialGrams, shape: shape)
            let matchesServing = Self.isApproximatelyEqual(
                Double(servingCount) * gramsPerUnit,
                initialGrams
            )
            let wheelHoldsDefault = !preservesExactGrams
                && (initialGrams / gramsPerUnit).rounded() <= Double(Self.maxServingCount(for: shape))
            mode = (wheelHoldsDefault || matchesServing) ? .serving : .grams
        }
    }

    static func opening(
        shape: Shape,
        existingEntryGrams: Double? = nil,
        suggestedGrams: Double? = nil,
        defaultServingGrams: Double? = nil
    ) -> PortionSelection {
        let exactGrams = existingEntryGrams ?? suggestedGrams
        return PortionSelection(
            shape: shape,
            initialGrams: exactGrams ?? defaultServingGrams ?? fallbackOpeningGrams,
            preservesExactGrams: exactGrams != nil
        )
    }

    static let fallbackOpeningGrams: Double = 100

    var quickGramOptions: [Int] { Self.quickGramOptions(for: shape) }

    var maxServingCount: Int { Self.maxServingCount(for: shape) }

    var selectedRecipeServingOption: RecipeServingOption? {
        Self.recipeServingOption(id: recipeServingID)
    }

    mutating func gramsInputChanged() {
        guard mode == .grams, let typed = Self.parsedGrams(gramsInput) else { return }
        setGrams(Double(typed))
    }

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

    mutating func quickGramOptionChosen(_ grams: Int) {
        guard mode == .grams else { return }
        setGrams(Double(Self.clampedGrams(grams)))
        gramsInput = Self.formattedGrams(portionGrams)
    }

    mutating func gramsStepped(_ step: GramStep) {
        guard mode == .grams else { return }
        setGrams(Self.stepped(portionGrams, step))
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

    mutating func servingCountChanged() {
        guard mode == .serving, let gramsPerUnit = shape.servingGramsPerUnit else { return }
        portionGrams = Double(servingCount) * gramsPerUnit
    }

    mutating func recipeServingChanged() {
        guard mode == .recipeServing, let option = selectedRecipeServingOption else { return }
        portionGrams = shape.recipeTotalGrams * option.multiplier
        gramsInput = Self.formattedGrams(portionGrams)
    }

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

    func supports(_ mode: Mode) -> Bool {
        switch mode {
        case .grams: true
        case .serving: shape.hasCountableServing
        case .recipeServing: shape.isRecipe
        }
    }

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

    static func quickGramOptionLabel(_ grams: Int, serving: ServingInfo?) -> String {
        let weight = "\(grams) g"
        guard let serving, serving.gramsPerUnit.isFinite, serving.gramsPerUnit > 0 else {
            return weight
        }
        let count = (Double(grams) / serving.gramsPerUnit).rounded()
        guard count >= 1, count <= Double(maximumServingCountLimit),
              (count * serving.gramsPerUnit).rounded().truncatedSafely == grams
        else {
            return weight
        }
        return "\(serving.label(for: count.truncatedSafely)), \(weight)"
    }

    static func parsedGrams(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isWholeNumber) else {
            return nil
        }
        guard let value = Int(trimmed) else {
            return trimmed.allSatisfy(\.isASCII) ? maximumGrams : nil
        }
        return clampedGrams(value)
    }

    static func clampedGrams(_ grams: Int) -> Int {
        max(minimumGrams, min(maximumGrams, grams))
    }

    enum GramStep {
        case less
        case more
    }

    static let gramStepSize: Double = 10

    static func stepped(_ grams: Double, _ step: GramStep) -> Double {
        guard grams.isFinite else { return Double(minimumGrams) }
        let moved = grams + (step == .more ? gramStepSize : -gramStepSize)
        return max(Double(minimumGrams), min(Double(maximumGrams), moved))
    }

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
    var recipeTotalGrams: Double {
        defaultServingGrams ?? 100
    }
}
