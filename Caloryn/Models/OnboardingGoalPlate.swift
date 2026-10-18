import Foundation

struct OnboardingGoalPlate: Equatable {
    static let adjustmentRange: ClosedRange<Double> = -500...1000
    static let adjustmentStep: Double = 50

    static var maintenanceFraction: Double {
        (0 - adjustmentRange.lowerBound) / (adjustmentRange.upperBound - adjustmentRange.lowerBound)
    }

    static let minimumDiameterRatio = 0.5

    let restKcal: Int
    let burnKcal: Int
    let targetKcal: Int
    let calorieDeficit: Double

    init(bmr: Double, tdee: Double, target: Int, calorieDeficit: Double) {
        self.restKcal = bmr.truncatedSafely
        self.burnKcal = tdee.truncatedSafely
        self.targetKcal = target
        self.calorieDeficit = calorieDeficit
    }

    init(basis: OnboardingGoalSummaryDraft.Basis, target: Int) {
        self.init(bmr: basis.bmr, tdee: basis.tdee, target: target, calorieDeficit: basis.calorieDeficit)
    }

    var difference: Int {
        burnKcal.subtractingReportingOverflow(targetKcal).overflow ? 0 : burnKcal - targetKcal
    }

    var restText: String { "\(restKcal.formatted()) kcal" }

    var burnText: String { "\(burnKcal.formatted()) kcal" }

    var adjustmentText: String {
        switch difference {
        case 0: "None"
        case 1...: "\(difference.formatted()) less"
        default: "\(abs(difference).formatted()) more"
        }
    }

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

    var paceCaption: String {
        let deficit = calorieDeficit.truncatedSafely
        switch deficit {
        case 0: return "What you burn"
        case 1...: return "\(deficit.formatted()) under what you burn"
        default: return "\(deficit.magnitude.formatted()) over what you burn"
        }
    }

    var plateDiameterRatio: Double { diameterRatio(for: targetKcal) }
    var burnDiameterRatio: Double { diameterRatio(for: burnKcal) }

    private func diameterRatio(for kcal: Int) -> Double {
        let largest = Double(max(burnKcal, targetKcal))
        guard largest > 0 else { return 1 }
        let ratio = (Double(max(kcal, 0)) / largest).squareRoot()
        return min(1, max(Self.minimumDiameterRatio, ratio))
    }
}
