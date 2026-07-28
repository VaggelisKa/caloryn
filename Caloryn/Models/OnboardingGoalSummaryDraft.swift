import Foundation

/// The editable state of the onboarding goal step, and the figures it derives.
///
/// The mirror of `GoalEditDraft` for first run: the same manual-target rule
/// applies, but the numbers come from the steps just answered rather than from
/// a saved profile, so the inputs arrive as `Basis` instead of a `UserProfile`.
struct OnboardingGoalSummaryDraft: Equatable {
    /// Below this a manual target is treated as a typo and the calculation
    /// stands. Deliberately the same threshold the goal editor applies — a
    /// target that is rejected in Settings must not be accepted here.
    static let minimumManualTarget = GoalEditDraft.minimumManualTarget

    /// Everything the calculation needs from the steps before this one, plus
    /// the adjustment this step's slider controls.
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

        /// The slider reads as a deficit in one direction and a surplus in the
        /// other, so the sign is spelled out rather than shown as a minus.
        var deficitLabel: String {
            if calorieDeficit > 0 {
                return "-\(Int(calorieDeficit)) kcal/day (lose weight)"
            } else if calorieDeficit < 0 {
                return "+\(Int(abs(calorieDeficit))) kcal/day (gain weight)"
            }
            return "Maintenance (no change)"
        }
    }

    var manualTargetText: String = ""
    var useManualOverride = false

    /// The typed target, or nil when the field is not a plain whole number.
    /// A numeric keypad is the only way to fill it, and the value is used as an
    /// `Int` throughout, so `Int(_:)` is the parse — there is no decimal here to
    /// route through `decimalInputValue`.
    var manualTarget: Int? { Int(manualTargetText) }

    /// Whether the typed target is the one that counts.
    var appliesManualTarget: Bool {
        useManualOverride && (manualTarget ?? 0) >= Self.minimumManualTarget
    }

    /// The figure the step shows and hands on: the typed target when it counts,
    /// otherwise the calculation. A too-low or half-typed entry keeps the
    /// calculation on screen rather than blanking it.
    func displayTarget(basis: Basis) -> Int {
        appliesManualTarget ? (manualTarget ?? basis.calculatedTarget) : basis.calculatedTarget
    }

    /// The field opens showing the calculation, so the user adjusts a real
    /// number instead of an empty box.
    mutating func seedManualTarget(basis: Basis) {
        manualTargetText = "\(basis.calculatedTarget)"
    }

    /// While the slider still drives the target the field tracks it. Once the
    /// manual toggle is on the typed value is left alone, so moving the slider
    /// cannot overwrite what was entered.
    mutating func calculatedTargetChanged(basis: Basis) {
        guard !useManualOverride else { return }
        manualTargetText = "\(basis.calculatedTarget)"
    }
}
