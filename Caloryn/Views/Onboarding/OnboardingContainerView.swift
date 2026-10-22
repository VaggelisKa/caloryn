import SwiftUI
import SwiftData

struct OnboardingContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @State private var path: [OnboardingStep] = []

    @State private var age: Int = 30
    @State private var sex: Sex = .male
    @State private var heightCm: Double = 175
    @State private var weightKg: Double = 75
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var calorieDeficit: Double = 500
    @State private var finalCalorieTarget: Int = 2000
    @State private var isManualCalorieTarget = false
    @State private var proteinRatio: Double = 0.30
    @State private var carbRatio: Double = 0.40
    @State private var fatRatio: Double = 0.30
    @State private var macroGramGoals = MacroGramGoals.empty
    @AppStorage("todayTrackedNutrients") private var selectedNutrientIDs = TrackedNutrient.defaultSelectionRaw
    @State private var isCompletingOnboarding = false

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeStepView {
                advance(from: .welcome)
            }
            .navigationDestination(for: OnboardingStep.self) { step in
                switch step {
                case .welcome:
                    EmptyView()
                case .personalInfo:
                    PersonalInfoStepView(
                        age: $age,
                        sex: $sex,
                        heightCm: $heightCm,
                        weightKg: $weightKg
                    ) {
                        advance(from: .personalInfo)
                    }
                case .activityLevel:
                    ActivityLevelStepView(activityLevel: $activityLevel) {
                        advance(from: .activityLevel)
                    }
                case .goalSummary:
                    GoalSummaryStepView(
                        age: age,
                        sex: sex,
                        heightCm: heightCm,
                        weightKg: weightKg,
                        activityLevel: activityLevel,
                        calorieDeficit: $calorieDeficit
                    ) { target, isManual in
                        let choice = OnboardingMacroChoice(
                            proteinRatio: proteinRatio,
                            carbRatio: carbRatio,
                            fatRatio: fatRatio,
                            grams: macroGramGoals
                        ).afterGoalSummary(
                            isManual: isManual,
                            wasManual: isManualCalorieTarget,
                            calorieTarget: target
                        )
                        proteinRatio = choice.proteinRatio
                        carbRatio = choice.carbRatio
                        fatRatio = choice.fatRatio
                        macroGramGoals = choice.grams
                        finalCalorieTarget = target
                        isManualCalorieTarget = isManual
                        advance(from: .goalSummary, calorieTarget: target, usesDirectGrams: isManual)
                    }
                case .macroRatios(let calorieTarget, let usesDirectGrams):
                    MacroRatioStepView(
                        calorieTarget: calorieTarget,
                        proteinRatio: $proteinRatio,
                        carbRatio: $carbRatio,
                        fatRatio: $fatRatio,
                        usesDirectGrams: usesDirectGrams,
                        gramGoals: $macroGramGoals,
                        primaryButtonTitle: "Continue"
                    ) {
                        finalCalorieTarget = calorieTarget
                        advance(from: .macroRatios(calorieTarget: calorieTarget, usesDirectGrams: usesDirectGrams))
                    }
                case .nutrientSelection:
                    NutrientSelectionStepView(
                        selectedNutrientIDs: $selectedNutrientIDs,
                        isCompleting: isCompletingOnboarding,
                        onComplete: completeOnboarding
                    )
                }
            }
        }
    }

    private func advance(from step: OnboardingStep, calorieTarget: Int = 0, usesDirectGrams: Bool = false) {
        guard let next = OnboardingFlow.step(
            after: step,
            calorieTarget: calorieTarget,
            usesDirectGrams: usesDirectGrams
        ) else { return }
        path.append(next)
    }

    private func completeOnboarding() {
        guard OnboardingFlow.shouldComplete(isCompleting: isCompletingOnboarding) else { return }
        isCompletingOnboarding = true
        defer {
            isCompletingOnboarding = false
        }

        saveProfile()
        CalorynHaptics.success()
    }

    private func saveProfile() {
        let selections = OnboardingProfileSave.Selections(
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            calorieDeficit: calorieDeficit,
            calorieTarget: finalCalorieTarget,
            isManualTarget: isManualCalorieTarget,
            proteinRatio: proteinRatio,
            carbRatio: carbRatio,
            fatRatio: fatRatio,
            proteinGrams: isManualCalorieTarget ? macroGramGoals.grams(for: .protein) : nil,
            carbGrams: isManualCalorieTarget ? macroGramGoals.grams(for: .carbs) : nil,
            fatGrams: isManualCalorieTarget ? macroGramGoals.grams(for: .fat) : nil
        )

        if let profile = profiles.first {
            OnboardingProfileSave.apply(selections, to: profile)
            return
        }

        modelContext.insert(OnboardingProfileSave.makeProfile(from: selections))
    }
}

#Preview {
    OnboardingContainerView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
