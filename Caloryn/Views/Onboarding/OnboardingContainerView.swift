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
                        finalCalorieTarget = target
                        isManualCalorieTarget = isManual
                        advance(from: .goalSummary, calorieTarget: target)
                    }
                case .macroRatios(let calorieTarget):
                    MacroRatioStepView(
                        calorieTarget: calorieTarget,
                        proteinRatio: $proteinRatio,
                        carbRatio: $carbRatio,
                        fatRatio: $fatRatio,
                        primaryButtonTitle: "Continue"
                    ) {
                        finalCalorieTarget = calorieTarget
                        advance(from: .macroRatios(calorieTarget))
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

    /// Pushes whatever `OnboardingFlow` says comes next, so the order lives in
    /// one place rather than in each step's continue handler.
    private func advance(from step: OnboardingStep, calorieTarget: Int = 0) {
        guard let next = OnboardingFlow.step(after: step, calorieTarget: calorieTarget) else { return }
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
            fatRatio: fatRatio
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
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Calorie Estimate")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text("Choose how Caloryn estimates your daily calories.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                VStack(spacing: CalorynTheme.cardSpacing) {
                    EnergyCalculationModeCard(
                        title: EnergyCalculationMode.lifestyleEstimate.displayName,
                        detail: "Uses the activity level you choose. Best when your routine stays similar.",
                        iconName: "figure.walk",
                        isSelected: selectedMode == .lifestyleEstimate,
                        isDisabled: false
                    ) {
                        onSelectionChanged()
                        withAnimation(.smooth(duration: 0.25)) {
                            selectedMode = .lifestyleEstimate
                        }
                    }

                    EnergyCalculationModeCard(
                        title: EnergyCalculationMode.dynamicHealth.displayName,
                        detail: isHealthAvailable
                            ? "Uses Apple Health when activity data is available."
                            : AppleHealthAdjustmentSettings.unavailableMessage,
                        iconName: "heart.text.square.fill",
                        isSelected: selectedMode == .dynamicHealth,
                        isDisabled: !isHealthAvailable
                    ) {
                        onSelectionChanged()
                        withAnimation(.smooth(duration: 0.25)) {
                            selectedMode = .dynamicHealth
                        }
                    }
                }

                if let message {
                    Text(message)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                HStack(spacing: 8) {
                    if isRequestingAuthorization {
                        ProgressView()
                            .tint(CalorynTheme.warmWhite)
                    }

                    Text(selectedMode == .dynamicHealth ? "Allow & Continue" : "Continue")
                        .font(CalorynTheme.buttonLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .disabled(isRequestingAuthorization)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
            .accessibilityIdentifier("onboarding.energyMode.continue")
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
}

private struct EnergyCalculationModeCard: View {
    let title: String
    let detail: String
    let iconName: String
    let isSelected: Bool
    let isDisabled: Bool
    var onTap: () -> Void

    private var usesLiquidGlassSelectedStyle: Bool {
        if #available(iOS 26.0, *) {
            isSelected
        } else {
            false
        }
    }

    private var contentForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite : CalorynTheme.textPrimary
    }

    private var secondaryForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite.opacity(0.9) : CalorynTheme.textSecondary
    }

    private var accentForeground: Color {
        usesLiquidGlassSelectedStyle ? CalorynTheme.warmWhite : CalorynTheme.sage
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: iconName)
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(accentForeground)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(contentForeground)

                    Text(detail)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(secondaryForeground)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(accentForeground)
                    .font(CalorynTheme.inlineIcon)
                    .accessibilityHidden(true)
            }
            .padding(CalorynTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveSelectableGlass(
                isSelected: isSelected,
                cornerRadius: CalorynTheme.smallCornerRadius
            )
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("\(title), \(isSelected ? "selected" : "not selected")")
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
