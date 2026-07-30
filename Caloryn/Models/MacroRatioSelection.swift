import Foundation

/// The macro split being chosen on the onboarding step, and the figures the
/// three sliders show.
///
/// The opposite direction to `ProfileEditMacroRatios`, which reads the ratios a
/// *saved* profile's grams already represent. Here there are no saved grams
/// yet: ratios are what the user is setting, grams are what falls out of them,
/// and the split can be temporarily invalid while three independent sliders are
/// moved one at a time. That validity rule has nowhere to live in the settings
/// type, whose ratios are derived and therefore always total 1 — so this is its
/// own rule. What the two do share is the default split, which is taken from
/// `ProfileEditMacroRatios` rather than restated.
struct MacroRatioSelection: Equatable {
    /// The split "Skip" applies, and the one a profile starts from.
    static let defaultSplit = ProfileEditMacroRatios.defaultSplit

    /// How far off 100% the three sliders may total and still be accepted.
    ///
    /// The sliders step in whole 5% increments, so a valid split lands exactly
    /// on 1; the tolerance is there for the binary representation of those
    /// steps, not to allow a split that is genuinely short.
    static let totalTolerance = 0.01

    enum Macro: CaseIterable {
        case protein
        case carbs
        case fat

        var displayName: String {
            switch self {
            case .protein: "Protein"
            case .carbs: "Carbs"
            case .fat: "Fat"
            }
        }

        /// Fat carries more than twice the energy per gram, which is why the
        /// same ratio buys far fewer grams of it.
        var caloriesPerGram: Double {
            switch self {
            case .protein, .carbs: 4
            case .fat: 9
            }
        }

        /// What a slider may be dragged to. Each macro keeps a floor of 10% —
        /// a split that zeroes one out is a diet, not a preference — and carbs
        /// are allowed the highest ceiling because they are the usual remainder.
        var sliderRange: ClosedRange<Double> {
            switch self {
            case .protein: 0.10...0.50
            case .carbs: 0.10...0.60
            case .fat: 0.10...0.50
            }
        }
    }

    let calorieTarget: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    init(calorieTarget: Int, protein: Double, carbs: Double, fat: Double) {
        self.calorieTarget = calorieTarget
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }

    func ratio(for macro: Macro) -> Double {
        switch macro {
        case .protein: protein
        case .carbs: carbs
        case .fat: fat
        }
    }

    var total: Double {
        protein + carbs + fat
    }

    /// The step cannot be completed on a split that does not add up: the grams
    /// it would save would not spend the calorie target.
    var isValid: Bool {
        abs(total - 1.0) <= Self.totalTolerance
    }

    /// The grams the ratio buys out of the target, by the same calculation the
    /// profile save performs, so the number previewed here is the number saved.
    func grams(for macro: Macro) -> Double {
        NutritionCalculator.macroGrams(
            calories: Double(calorieTarget),
            ratio: ratio(for: macro),
            caloriesPerGram: macro.caloriesPerGram
        )
    }

    /// Rendered through `truncatedSafely`: `Int(_:)` terminates the process on a
    /// value that is not finite rather than throwing, and these strings exist to
    /// display whatever the ratios currently are.
    func percentText(for macro: Macro) -> String {
        "\(Self.percent(ratio(for: macro)))%"
    }

    func gramsText(for macro: Macro) -> String {
        "\(grams(for: macro).truncatedSafely)g"
    }

    /// Says how far off the split is rather than only that it is wrong, so the
    /// remaining percentage does not have to be worked out from three sliders.
    var validationMessage: String? {
        guard !isValid else { return nil }
        return "Ratios should total 100% (currently \(Self.percent(total))%)"
    }

    private static func percent(_ ratio: Double) -> Int {
        (ratio * 100).truncatedSafely
    }
}
