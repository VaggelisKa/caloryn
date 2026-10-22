import Testing
@testable import Caloryn

@MainActor
@Suite("Onboarding flow")
struct OnboardingFlowTests {
    @Test("The steps run welcome, personal info, activity, calorie estimate, goal, macros, nutrients")
    func stepsRunInOrder() {
        var visited: [OnboardingStep] = [.welcome]

        while let next = OnboardingFlow.step(after: visited[visited.count - 1], calorieTarget: 2_000) {
            visited.append(next)
            #expect(visited.count <= 10, "the flow should end rather than loop")
        }

        #expect(visited == [
            .welcome,
            .personalInfo,
            .activityLevel,
            .goalSummary,
            .macroRatios(calorieTarget: 2_000, usesDirectGrams: false),
            .nutrientSelection
        ])
    }

    @Test("The last step has no successor, so its button saves instead of pushing")
    func lastStepEndsTheFlow() {
        #expect(OnboardingFlow.step(after: .nutrientSelection) == nil)
    }

    @Test("Choosing the estimate after typing grams keeps that split")
    func choosingTheEstimateKeepsTheTypedSplit() {
        let choice = OnboardingMacroChoice(
            proteinRatio: 0.30,
            carbRatio: 0.40,
            fatRatio: 0.30,
            grams: MacroGramGoals(proteinText: "150", carbText: "180", fatText: "50")
        ).afterGoalSummary(isManual: false, wasManual: true, calorieTarget: 1_800)

        #expect(abs(choice.proteinRatio - (600.0 / 1_770)) < 1e-12)
        #expect(abs(choice.carbRatio - (720.0 / 1_770)) < 1e-12)
        #expect(abs(choice.fatRatio - (450.0 / 1_770)) < 1e-12)
        #expect(choice.grams.proteinText == "150")
    }

    @Test("Continuing the estimate keeps later slider edits instead of the earlier gram split")
    func continuingTheEstimateKeepsSliderEdits() {
        let choice = OnboardingMacroChoice(
            proteinRatio: 0.25,
            carbRatio: 0.45,
            fatRatio: 0.30,
            grams: MacroGramGoals(proteinText: "150", carbText: "180", fatText: "50")
        ).afterGoalSummary(isManual: false, wasManual: false, calorieTarget: 1_800)

        #expect(choice.proteinRatio == 0.25)
        #expect(choice.carbRatio == 0.45)
        #expect(choice.fatRatio == 0.30)
        #expect(choice.grams.proteinText == "150")
    }

    @Test("Choosing the estimate with no gram goals keeps the percentage split")
    func choosingTheEstimateWithoutGramsKeepsTheSplit() {
        let choice = OnboardingMacroChoice(
            proteinRatio: 0.25,
            carbRatio: 0.45,
            fatRatio: 0.30,
            grams: .empty
        ).afterGoalSummary(isManual: false, wasManual: true, calorieTarget: 1_800)

        #expect(choice.proteinRatio == 0.25)
        #expect(choice.carbRatio == 0.45)
        #expect(choice.fatRatio == 0.30)
    }

    @Test("The goal step hands its calorie target to the macro step")
    func goalStepCarriesTheTarget() {
        #expect(
            OnboardingFlow.step(after: .goalSummary, calorieTarget: 1_750)
                == .macroRatios(calorieTarget: 1_750, usesDirectGrams: false)
        )
        #expect(
            OnboardingFlow.step(after: .goalSummary, calorieTarget: 1_800, usesDirectGrams: true)
                == .macroRatios(calorieTarget: 1_800, usesDirectGrams: true)
        )
    }

    @Test("No other step reads the calorie target")
    func otherStepsIgnoreTheTarget() {
        for step in [OnboardingStep.welcome, .personalInfo, .activityLevel] {
            #expect(
                OnboardingFlow.step(after: step, calorieTarget: 1_750)
                    == OnboardingFlow.step(after: step, calorieTarget: 9_999)
            )
        }

        #expect(
            OnboardingFlow.step(
                after: .macroRatios(calorieTarget: 1_750, usesDirectGrams: true),
                calorieTarget: 4_000
            ) == .nutrientSelection
        )
    }

    @Test("A double tap on Start Tracking cannot run the save twice")
    func completionIsNotReentrant() {
        #expect(OnboardingFlow.shouldComplete(isCompleting: false))
        #expect(!OnboardingFlow.shouldComplete(isCompleting: true))
    }
}
