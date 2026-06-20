import SwiftUI
import SwiftData

enum OnboardingStep: Hashable {
    case welcome
    case personalInfo
    case activityLevel
    case energyCalculationMode
    case goalSummary
    case macroRatios(Int)
    case nutrientSelection
}

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
                path.append(.personalInfo)
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
                        path.append(.activityLevel)
                    }
                case .activityLevel:
                    ActivityLevelStepView(activityLevel: $activityLevel) {
                        path.append(.energyCalculationMode)
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
                    ) { target in
                        finalCalorieTarget = target
                        path.append(.macroRatios(target))
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
                        path.append(.nutrientSelection)
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

    private func continueFromEnergyCalculationMode() {
        guard !isRequestingHealthAuthorization else { return }
        appleHealthOnboardingMessage = nil

        guard energyCalculationMode == .dynamicHealth else {
            AppleHealthAdjustmentSettings.disable()
            path.append(.goalSummary)
            return
        }

        Task {
            await requestAppleHealthAndContinue()
        }
    }

    @MainActor
    private func requestAppleHealthAndContinue() async {
        isRequestingHealthAuthorization = true
        defer {
            isRequestingHealthAuthorization = false
        }

        let update = await AppleHealthAdjustmentSettings.enable()
        guard update.isEnabled else {
            energyCalculationMode = .lifestyleEstimate
            appleHealthOnboardingMessage = update.message
            return
        }

        path.append(.goalSummary)
    }

    private func completeOnboarding() {
        guard !isCompletingOnboarding else { return }
        appleHealthOnboardingMessage = nil

        isCompletingOnboarding = true
        defer {
            isCompletingOnboarding = false
        }

        saveProfile()
    }

    private func saveProfile() {
        let computedBmr = NutritionCalculator.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        let computedTdee = NutritionCalculator.tdee(bmr: computedBmr, activity: activityLevel)

        if let profile = profiles.first {
            profile.age = age
            profile.sex = sex
            profile.heightCm = heightCm
            profile.weightKg = weightKg
            profile.activityLevel = activityLevel
            profile.energyCalculationMode = energyCalculationMode
            profile.manualOverride = false
            profile.calorieDeficit = calorieDeficit
            profile.bmr = computedBmr
            profile.tdee = computedTdee
            profile.dailyCalorieTarget = finalCalorieTarget
            profile.proteinTargetG = NutritionCalculator.macroGrams(calories: Double(finalCalorieTarget), ratio: proteinRatio, caloriesPerGram: 4)
            profile.carbTargetG = NutritionCalculator.macroGrams(calories: Double(finalCalorieTarget), ratio: carbRatio, caloriesPerGram: 4)
            profile.fatTargetG = NutritionCalculator.macroGrams(calories: Double(finalCalorieTarget), ratio: fatRatio, caloriesPerGram: 9)
            profile.updatedAt = Date()
            return
        }

        let profile = UserProfile(
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            dailyCalorieTarget: finalCalorieTarget,
            calorieDeficit: calorieDeficit,
            energyCalculationMode: energyCalculationMode,
            proteinRatio: proteinRatio,
            carbRatio: carbRatio,
            fatRatio: fatRatio
        )
        modelContext.insert(profile)
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
                            .tint(.white)
                    }

                    Text(selectedMode == .dynamicHealth ? "Allow & Continue" : "Continue")
                        .font(.system(.headline, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .tint(CalorynTheme.sage)
            .disabled(isRequestingAuthorization)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 16)
        }
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
                    .font(.title2)
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
                    .font(.title3)
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
