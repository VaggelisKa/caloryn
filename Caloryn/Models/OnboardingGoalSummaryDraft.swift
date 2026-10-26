import Foundation

struct OnboardingGoalSummaryDraft: Equatable {
    static let minimumManualTarget = GoalEditDraft.minimumManualTarget

    struct Basis: Equatable {
        var age: Int
        var sex: Sex
        var heightCm: Double
        var weightKg: Double
        var activityLevel: ActivityLevel
        var calorieDeficit: Double

        var bmr: Double {
            NutritionCalculator.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        }

        var tdee: Double {
            NutritionCalculator.tdee(bmr: bmr, activity: activityLevel)
        }

        var calculatedTarget: Int {
            NutritionCalculator.defaultTarget(tdee: tdee, deficit: calorieDeficit)
        }
    }

    var manualTargetText: String = ""
    var useManualOverride = false

    var manualTarget: Int? { Int(manualTargetText).map(CalorieDomain.clamped) }

    var appliesManualTarget: Bool {
        useManualOverride && (manualTarget ?? 0) >= Self.minimumManualTarget
    }

    func displayTarget(basis: Basis) -> Int {
        appliesManualTarget ? (manualTarget ?? basis.calculatedTarget) : basis.calculatedTarget
    }

    mutating func seedManualTarget(basis: Basis) {
        manualTargetText = "\(basis.calculatedTarget)"
    }

    mutating func calculatedTargetChanged(basis: Basis) {
        guard !useManualOverride else { return }
        manualTargetText = "\(basis.calculatedTarget)"
    }
}
