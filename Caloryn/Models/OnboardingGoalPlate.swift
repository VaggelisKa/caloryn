import Foundation

/// What the onboarding goal step ("Your daily plate") says about its number: the plate
/// drawn inside a dotted "what you burn" ring, the rows that show where the number comes
/// from, and the captions around them.
///
/// Takes the facts the step already has — the resting and daily burn from
/// `OnboardingGoalSummaryDraft.Basis`, the slider's adjustment and the target the step will
/// hand on — so the wording and the drawing can be checked without driving the step.
///
/// The rows and the explanation describe the target actually shown, not the slider: the
/// calculation never goes below its floor and a typed target ignores the slider, so "500
/// smaller" is worked out from the burn and the target rather than read off the adjustment.
struct OnboardingGoalPlate: Equatable {
    /// The adjustment slider: a surplus of up to 500 to a deficit of up to 1,000 a day.
    static let adjustmentRange: ClosedRange<Double> = -500...1000
    static let adjustmentStep: Double = 50

    /// Where "Keep" sits under the slider: the fraction of the track at which the adjustment
    /// is zero. One third, because the range is lopsided towards losing.
    static var maintenanceFraction: Double {
        (0 - adjustmentRange.lowerBound) / (adjustmentRange.upperBound - adjustmentRange.lowerBound)
    }

    /// The plate never drawn smaller than this share of the ring's diameter, so a large
    /// deficit still reads as a plate rather than a dot.
    static let minimumDiameterRatio = 0.5

    /// Calories burned at rest (BMR), as the step's first row shows it.
    let restKcal: Int
    /// Calories burned in a day at the chosen activity level: the dotted ring.
    let burnKcal: Int
    /// The number the step shows and hands on: the plate.
    let targetKcal: Int
    /// The slider's own value, positive for a deficit.
    let calorieDeficit: Double

    init(bmr: Double, tdee: Double, target: Int, calorieDeficit: Double) {
        // Truncated, like the calculated target itself, so the rows add up to it.
        self.restKcal = bmr.truncatedSafely
        self.burnKcal = tdee.truncatedSafely
        self.targetKcal = target
        self.calorieDeficit = calorieDeficit
    }

    init(basis: OnboardingGoalSummaryDraft.Basis, target: Int) {
        self.init(bmr: basis.bmr, tdee: basis.tdee, target: target, calorieDeficit: basis.calorieDeficit)
    }

    /// How far the plate is below the burn: positive is smaller, negative is bigger.
    var difference: Int {
        burnKcal.subtractingReportingOverflow(targetKcal).overflow ? 0 : burnKcal - targetKcal
    }

    // MARK: - Rows

    var restText: String { "\(restKcal.formatted()) kcal" }

    var burnText: String { "\(burnKcal.formatted()) kcal" }

    /// "500 less", "250 more", or "None" when the plate is exactly what you burn.
    var adjustmentText: String {
        switch difference {
        case 0: "None"
        case 1...: "\(difference.formatted()) less"
        default: "\(abs(difference).formatted()) more"
        }
    }

    // MARK: - Captions

    /// The line beside the number, which is what the drawing means.
    var explanation: String {
        let burn = "You burn about \(burnKcal.formatted()). The dotted ring is that;"
        switch difference {
        case 0:
            return "\(burn) the plate is the same size, so your weight stays put."
        case 1...:
            return "\(burn) the plate is \(difference.formatted()) smaller, so you lose weight."
        default:
            return "\(burn) the plate is \(abs(difference).formatted()) bigger, so you gain weight."
        }
    }

    /// Beside "How fast": what the slider is set to, in the same words the Settings goal row
    /// uses for an adjustment.
    var paceCaption: String {
        let deficit = calorieDeficit.truncatedSafely
        switch deficit {
        case 0: return "What you burn"
        case 1...: return "\(deficit.formatted()) under what you burn"
        default: return "\(deficit.magnitude.formatted()) over what you burn"
        }
    }

    // MARK: - Drawing

    /// The plate's and the dotted ring's diameters as shares of the drawing, the larger of
    /// the two filling it. Proportional to area rather than radius, since a plate reads as a
    /// disc: a 2,000 plate inside a 2,500 burn is 89% of the ring's width, not 80%.
    var plateDiameterRatio: Double { diameterRatio(for: targetKcal) }
    var burnDiameterRatio: Double { diameterRatio(for: burnKcal) }

    private func diameterRatio(for kcal: Int) -> Double {
        let largest = Double(max(burnKcal, targetKcal))
        guard largest > 0 else { return 1 }
        let ratio = (Double(max(kcal, 0)) / largest).squareRoot()
        return min(1, max(Self.minimumDiameterRatio, ratio))
    }
}
