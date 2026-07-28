import Foundation

/// One screen of the first-run flow.
///
/// `macroRatios` carries the calorie target the goal step settled on, because
/// the macro sliders render grams against it and the profile is not written
/// until the flow ends — there is nowhere else to read it from yet.
enum OnboardingStep: Hashable {
    case welcome
    case personalInfo
    case activityLevel
    case energyCalculationMode
    case goalSummary
    case macroRatios(Int)
    case nutrientSelection
}

/// The order the onboarding steps run in, and the two points where continuing
/// is not simply "push the next screen".
///
/// The container view pushes and pops; this decides *what* comes next, so the
/// order can be checked without driving a `NavigationStack`.
enum OnboardingFlow {
    /// The step that follows `step`, or nil at the end of the flow — where the
    /// button saves the profile instead of pushing anything.
    ///
    /// `calorieTarget` is only read after `.goalSummary`, the one transition
    /// that carries a value forward.
    static func step(after step: OnboardingStep, calorieTarget: Int = 0) -> OnboardingStep? {
        switch step {
        case .welcome:
            .personalInfo
        case .personalInfo:
            .activityLevel
        case .activityLevel:
            .energyCalculationMode
        case .energyCalculationMode:
            .goalSummary
        case .goalSummary:
            .macroRatios(calorieTarget)
        case .macroRatios:
            .nutrientSelection
        case .nutrientSelection:
            nil
        }
    }

    /// What tapping Continue on the calorie-estimate step should do.
    enum EnergyModeContinuation: Equatable {
        /// An authorization request is already in flight, so the tap does
        /// nothing — otherwise a second tap would push the goal step twice.
        case ignore

        /// The lifestyle estimate was chosen. Apple Health adjustment is
        /// switched off before advancing, so a mode picked and then changed on
        /// a re-run of onboarding does not leave the setting enabled.
        case disableAppleHealthAndAdvance

        /// Apple Health was chosen. Authorization is asked for first and the
        /// flow only advances if it is granted.
        case requestAppleHealthAuthorization
    }

    static func energyModeContinuation(
        mode: EnergyCalculationMode,
        isRequestingAuthorization: Bool
    ) -> EnergyModeContinuation {
        guard !isRequestingAuthorization else { return .ignore }
        return mode == .dynamicHealth ? .requestAppleHealthAuthorization : .disableAppleHealthAndAdvance
    }

    /// What the answer to the Apple Health request means for the flow.
    enum AppleHealthAuthorizationOutcome: Equatable {
        case advance

        /// Refused or unavailable: the choice reverts to the lifestyle estimate
        /// and the reason is shown in place, so the user stays on the step and
        /// can pick again rather than being pushed on with a mode that will not
        /// work.
        case fallBackToLifestyleEstimate(message: String?)
    }

    static func appleHealthOutcome(isEnabled: Bool, message: String?) -> AppleHealthAuthorizationOutcome {
        isEnabled ? .advance : .fallBackToLifestyleEstimate(message: message)
    }

    /// Whether tapping Start Tracking should run the save. A save already in
    /// flight is ignored, so a double tap cannot write two profiles.
    static func shouldComplete(isCompleting: Bool) -> Bool {
        !isCompleting
    }
}
