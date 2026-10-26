import Foundation

enum OnboardingStep: Hashable {
    case welcome
    case personalInfo
    case activityLevel
    case goalSummary
    case macroRatios(calorieTarget: Int, usesDirectGrams: Bool)
    case nutrientSelection
}

enum OnboardingFlow {
    static func step(
        after step: OnboardingStep,
        calorieTarget: Int = 0,
        usesDirectGrams: Bool = false
    ) -> OnboardingStep? {
        switch step {
        case .welcome:
            .personalInfo
        case .personalInfo:
            .activityLevel
        case .activityLevel:
            .goalSummary
        case .goalSummary:
            .macroRatios(calorieTarget: calorieTarget, usesDirectGrams: usesDirectGrams)
        case .macroRatios:
            .nutrientSelection
        case .nutrientSelection:
            nil
        }
    }

    static func shouldComplete(isCompleting: Bool) -> Bool {
        !isCompleting
    }
}

struct OnboardingMacroChoice: Equatable {
    var proteinRatio: Double
    var carbRatio: Double
    var fatRatio: Double
    var grams: MacroGramGoals

    func afterGoalSummary(isManual: Bool, wasManual: Bool, calorieTarget: Int) -> OnboardingMacroChoice {
        if isManual {
            guard !grams.isValid else { return self }
            var choice = self
            choice.grams = .derived(
                calorieTarget: calorieTarget,
                protein: proteinRatio,
                carbs: carbRatio,
                fat: fatRatio
            )
            return choice
        }

        guard wasManual, let snapped = grams.snappedRatios() else { return self }
        var choice = self
        choice.proteinRatio = snapped.protein
        choice.carbRatio = snapped.carbs
        choice.fatRatio = snapped.fat
        return choice
    }
}
