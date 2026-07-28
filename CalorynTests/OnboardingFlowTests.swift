import Testing
@testable import Caloryn

/// Covers the onboarding step order and its two branches, which until now were
/// only reachable by driving the whole first-run flow.
@MainActor
@Suite("Onboarding flow")
struct OnboardingFlowTests {

    // MARK: - Order

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
            .energyCalculationMode,
            .goalSummary,
            .macroRatios(2_000),
            .nutrientSelection
        ])
    }

    @Test("The last step has no successor, so its button saves instead of pushing")
    func lastStepEndsTheFlow() {
        #expect(OnboardingFlow.step(after: .nutrientSelection) == nil)
    }

    @Test("The goal step hands its calorie target to the macro step")
    func goalStepCarriesTheTarget() {
        #expect(OnboardingFlow.step(after: .goalSummary, calorieTarget: 1_750) == .macroRatios(1_750))
    }

    @Test("No other step reads the calorie target")
    func otherStepsIgnoreTheTarget() {
        for step in [OnboardingStep.welcome, .personalInfo, .activityLevel, .energyCalculationMode] {
            #expect(
                OnboardingFlow.step(after: step, calorieTarget: 1_750)
                    == OnboardingFlow.step(after: step, calorieTarget: 9_999)
            )
        }

        #expect(
            OnboardingFlow.step(after: .macroRatios(1_750), calorieTarget: 4_000) == .nutrientSelection
        )
    }

    // MARK: - Calorie estimate branch

    @Test("Choosing the lifestyle estimate switches Apple Health adjustment off and advances")
    func lifestyleEstimateDisablesAppleHealth() {
        #expect(
            OnboardingFlow.energyModeContinuation(mode: .lifestyleEstimate, isRequestingAuthorization: false)
                == .disableAppleHealthAndAdvance
        )
    }

    @Test("Choosing Apple Health asks for authorization before advancing")
    func appleHealthRequestsAuthorization() {
        #expect(
            OnboardingFlow.energyModeContinuation(mode: .dynamicHealth, isRequestingAuthorization: false)
                == .requestAppleHealthAuthorization
        )
    }

    @Test("A second tap while a request is in flight does nothing, whichever mode is chosen")
    func inFlightRequestIgnoresTaps() {
        for mode in EnergyCalculationMode.allCases {
            #expect(
                OnboardingFlow.energyModeContinuation(mode: mode, isRequestingAuthorization: true) == .ignore
            )
        }
    }

    // MARK: - Apple Health answer

    @Test("Granted authorization advances the flow")
    func grantedAuthorizationAdvances() {
        #expect(OnboardingFlow.appleHealthOutcome(isEnabled: true, message: nil) == .advance)
    }

    @Test("Refused authorization stays on the step and reverts to the lifestyle estimate")
    func refusedAuthorizationFallsBack() {
        #expect(
            OnboardingFlow.appleHealthOutcome(isEnabled: false, message: "Health is unavailable.")
                == .fallBackToLifestyleEstimate(message: "Health is unavailable.")
        )
    }

    @Test("A refusal with no explanation still falls back")
    func silentRefusalFallsBack() {
        #expect(
            OnboardingFlow.appleHealthOutcome(isEnabled: false, message: nil)
                == .fallBackToLifestyleEstimate(message: nil)
        )
    }

    @Test("A granted request carries no message, so nothing is shown on the way out")
    func grantedAuthorizationDropsAnyMessage() {
        #expect(OnboardingFlow.appleHealthOutcome(isEnabled: true, message: "ignored") == .advance)
    }

    // MARK: - Completing

    @Test("A double tap on Start Tracking cannot run the save twice")
    func completionIsNotReentrant() {
        #expect(OnboardingFlow.shouldComplete(isCompleting: false))
        #expect(!OnboardingFlow.shouldComplete(isCompleting: true))
    }
}
