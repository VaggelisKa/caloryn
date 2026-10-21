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
    @State private var energyCalculationMode: EnergyCalculationMode = .lifestyleEstimate
    @State private var calorieDeficit: Double = 500
    @State private var finalCalorieTarget: Int = 2000
    @State private var isManualCalorieTarget = false
    @State private var proteinRatio: Double = 0.30
    @State private var carbRatio: Double = 0.40
    @State private var fatRatio: Double = 0.30
    @State private var macroGramGoals = MacroGramGoals.empty
    @AppStorage("todayTrackedNutrients") private var selectedNutrientIDs = TrackedNutrient.defaultSelectionRaw
    @State private var isCompletingOnboarding = false
    @State private var isRequestingHealthAuthorization = false
    @State private var appleHealthOnboardingMessage: String?

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
                case .energyCalculationMode:
                    EnergyCalculationModeStepView(
                        selectedMode: $energyCalculationMode,
                        isRequestingAuthorization: isRequestingHealthAuthorization,
                        message: appleHealthOnboardingMessage,
                        onSelectionChanged: {
                            appleHealthOnboardingMessage = nil
                        },
                        onContinue: continueFromEnergyCalculationMode
                    )
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

    private func continueFromEnergyCalculationMode() {
        switch OnboardingFlow.energyModeContinuation(
            mode: energyCalculationMode,
            isRequestingAuthorization: isRequestingHealthAuthorization
        ) {
        case .ignore:
            return
        case .disableAppleHealthAndAdvance:
            appleHealthOnboardingMessage = nil
            AppleHealthAdjustmentSettings.disable()
            advance(from: .energyCalculationMode)
        case .requestAppleHealthAuthorization:
            appleHealthOnboardingMessage = nil
            Task {
                await requestAppleHealthAndContinue()
            }
        }
    }

    @MainActor
    private func requestAppleHealthAndContinue() async {
        isRequestingHealthAuthorization = true
        defer {
            isRequestingHealthAuthorization = false
        }

        let update = await AppleHealthAdjustmentSettings.enable()
        switch OnboardingFlow.appleHealthOutcome(isEnabled: update.isEnabled, message: update.message) {
        case .fallBackToLifestyleEstimate(let message):
            energyCalculationMode = .lifestyleEstimate
            appleHealthOnboardingMessage = message
        case .advance:
            advance(from: .energyCalculationMode)
        }
    }

    private func completeOnboarding() {
        guard OnboardingFlow.shouldComplete(isCompleting: isCompletingOnboarding) else { return }
        appleHealthOnboardingMessage = nil

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
            energyCalculationMode: energyCalculationMode,
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

        if isManualCalorieTarget {
            AppleHealthAdjustmentSettings.disable()
        }

        if let profile = profiles.first {
            OnboardingProfileSave.apply(selections, to: profile)
            return
        }

        modelContext.insert(OnboardingProfileSave.makeProfile(from: selections))
    }
}

struct EnergyCalculationModeStepView: View {
    @Binding var selectedMode: EnergyCalculationMode
    let isRequestingAuthorization: Bool
    let message: String?
    let isHealthAvailable: Bool
    var onSelectionChanged: () -> Void
    var onContinue: () -> Void

    init(
        selectedMode: Binding<EnergyCalculationMode>,
        isRequestingAuthorization: Bool,
        message: String?,
        isHealthAvailable: Bool = AppleHealthAdjustmentSettings.isHealthAvailable,
        onSelectionChanged: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self._selectedMode = selectedMode
        self.isRequestingAuthorization = isRequestingAuthorization
        self.message = message
        self.isHealthAvailable = isHealthAvailable
        self.onSelectionChanged = onSelectionChanged
        self.onContinue = onContinue
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: "Calorie estimate",
                    subtitle: "Choose how Caloryn estimates your daily calories."
                )

                VStack(spacing: 0) {
                    OnboardingHairline()
                    OnboardingChoiceRow(
                        title: EnergyCalculationMode.lifestyleEstimate.displayName.sentenceCased,
                        detail: "Uses the activity level you choose. Best when your routine stays similar.",
                        isSelected: selectedMode == .lifestyleEstimate
                    ) {
                        select(.lifestyleEstimate)
                    }

                    OnboardingHairline()
                    OnboardingChoiceRow(
                        title: EnergyCalculationMode.dynamicHealth.displayName.sentenceCased,
                        detail: isHealthAvailable
                            ? "Uses Apple Health when activity data is available."
                            : AppleHealthAdjustmentSettings.unavailableMessage,
                        isSelected: selectedMode == .dynamicHealth,
                        isDisabled: !isHealthAvailable
                    ) {
                        select(.dynamicHealth)
                    }
                }

                if let message {
                    Text(message)
                        .font(OnboardingTypography.detail)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CalorynTheme.cardPadding)
                        .calorynGroupSurface()
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingActionBar {
                Button(action: onContinue) {
                    HStack(spacing: 8) {
                        if isRequestingAuthorization {
                            ProgressView()
                                .tint(CalorynTheme.textSecondary)
                        }

                        Text(selectedMode == .dynamicHealth ? "Allow and continue" : "Continue")
                    }
                }
                .calorynPrimaryButton()
                .disabled(isRequestingAuthorization)
                .accessibilityIdentifier("onboarding.energyMode.continue")
            }
        }
        // Nested in a file whose outer view is the `NavigationStack` itself, which
        // is exactly how an unthemed screen hides from a file-scoped grep — see
        // docs/theme.md, "Audit per struct, not per file".
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .onChange(of: isHealthAvailable, initial: true) {
            if !isHealthAvailable && selectedMode == .dynamicHealth {
                selectedMode = .lifestyleEstimate
            }
        }
    }

    private func select(_ mode: EnergyCalculationMode) {
        onSelectionChanged()
        withAnimation(.smooth(duration: 0.25)) {
            selectedMode = mode
        }
    }
}

#Preview {
    OnboardingContainerView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}

#Preview("Calorie Estimate - Lifestyle") {
    @Previewable @State var selectedMode: EnergyCalculationMode = .lifestyleEstimate

    EnergyCalculationModeStepView(
        selectedMode: $selectedMode,
        isRequestingAuthorization: false,
        message: nil,
        isHealthAvailable: true,
        onSelectionChanged: {},
        onContinue: {}
    )
}

#Preview("Calorie Estimate - Dynamic") {
    @Previewable @State var selectedMode: EnergyCalculationMode = .dynamicHealth

    EnergyCalculationModeStepView(
        selectedMode: $selectedMode,
        isRequestingAuthorization: false,
        message: nil,
        isHealthAvailable: true,
        onSelectionChanged: {},
        onContinue: {}
    )
}

#Preview("Calorie Estimate - Requesting Health") {
    @Previewable @State var selectedMode: EnergyCalculationMode = .dynamicHealth

    EnergyCalculationModeStepView(
        selectedMode: $selectedMode,
        isRequestingAuthorization: true,
        message: nil,
        isHealthAvailable: true,
        onSelectionChanged: {},
        onContinue: {}
    )
}

#Preview("Calorie Estimate - Health Unavailable") {
    @Previewable @State var selectedMode: EnergyCalculationMode = .lifestyleEstimate

    EnergyCalculationModeStepView(
        selectedMode: $selectedMode,
        isRequestingAuthorization: false,
        message: AppleHealthAdjustmentSettings.unavailableMessage,
        isHealthAvailable: false,
        onSelectionChanged: {},
        onContinue: {}
    )
}
