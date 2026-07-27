import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

private let nutrientGoalExpansionAnimation = Animation.smooth(duration: 0.24)
private let nutrientGoalAnimationDuration: TimeInterval = 0.24
private let nutrientGoalPickerHeight: CGFloat = 32

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("showNutriscore") private var showNutriscore = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showRestartAlert = false
    @State private var isRequestingHealthAuthorization = false
    @State private var healthStatusMessage: String?
    @State private var settingsEnergyTracker = ActiveEnergyDayTracker()

    private let isHealthAvailableProvider: () -> Bool

    init() {
        self.isHealthAvailableProvider = {
            AppleHealthAdjustmentSettings.isHealthAvailable
        }
    }

    @MainActor
    init(
        settingsEnergyTracker: ActiveEnergyDayTracker,
        isHealthAvailable: @escaping () -> Bool
    ) {
        _settingsEnergyTracker = State(initialValue: settingsEnergyTracker)
        self.isHealthAvailableProvider = isHealthAvailable
    }

    private var profile: UserProfile? { profiles.first }
    private var isHealthAvailable: Bool { isHealthAvailableProvider() }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                    .listRowBackground(CalorynTheme.cardBackground)

                if let profile {
                    goalSection(profile)
                        .listRowBackground(CalorynTheme.cardBackground)
                    calorieEstimateSection(profile)
                        .listRowBackground(CalorynTheme.cardBackground)
                    profileSection(profile)
                        .listRowBackground(CalorynTheme.cardBackground)
                }

                DailyReminderSettingsSection()
                    .listRowBackground(CalorynTheme.cardBackground)
                dataSection
                    .listRowBackground(CalorynTheme.cardBackground)
                aboutSection
                    .listRowBackground(CalorynTheme.cardBackground)
            }
            .calorynGroupedListStyle()
            .navigationTitle("Settings")
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("iCloud sync changes will take effect the next time you open the app.")
            }
        }
        .calorynPageCanvas()
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let profile else { return }

            Task {
                await refreshPendingHealthAuthorizationIfNeeded(for: profile)
            }
        }
        .task(id: profile?.id) {
            guard scenePhase == .active, let profile else { return }
            await refreshPendingHealthAuthorizationIfNeeded(for: profile)
        }
    }

    private func calorieEstimateSection(_ profile: UserProfile) -> some View {
        let budget = settingsBudget(for: profile)

        return Section {
            if profile.manualOverride {
                Toggle(isOn: .constant(false)) {
                    calorieEstimateModeToggleLabel(for: profile)
                }
                .disabled(true)
            } else {
                Toggle(isOn: dynamicEnergyBinding(for: profile)) {
                    calorieEstimateModeToggleLabel(for: profile)
                }
                .disabled(isRequestingHealthAuthorization || (profile.energyCalculationMode != .dynamicHealth && !isHealthAvailable))
            }

            if !profile.manualOverride && profile.energyCalculationMode == .dynamicHealth {
                CalorieEstimateMetricRow(
                    title: "Valid Days",
                    description: "Active Energy days found; \(ActivityCalorieBudget.requiredDynamicActivityDays) days are needed before auto-adjust starts.",
                    value: "\(budget.validActivityDays)/\(ActivityCalorieBudget.requiredDynamicActivityDays)"
                )
                CalorieEstimateMetricRow(
                    title: "Baseline",
                    description: "Your typical Active Energy from recent valid days.",
                    value: dynamicBaselineText(for: budget)
                )
                CalorieEstimateMetricRow(
                    title: "Today",
                    description: "Active Energy read from Apple Health for today.",
                    value: Int(settingsEnergyTracker.activeEnergyKcal.rounded()).kcalFormatted
                )

                if let lastRefresh = settingsEnergyTracker.lastRefresh {
                    CalorieEstimateMetricRow(
                        title: "Updated",
                        description: "When Health data was last refreshed.",
                        value: lastRefresh.shortFormatted
                    )
                }
            }

            if isRequestingHealthAuthorization {
                HStack(spacing: 8) {
                    ProgressView()

                    Text("Requesting Apple Health access")
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            if let emptyActivityNotice = settingsEnergyTracker.emptyActivityNotice {
                VStack(alignment: .leading, spacing: 12) {
                    Text(emptyActivityNotice)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openHealthAccessSettings()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "gearshape")
                                .font(CalorynTheme.compactIcon)
                                .accessibilityHidden(true)

                            Text("Open App Settings")
                        }
                    }
                    .font(CalorynTheme.caption)
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Open app settings")
                }
            } else if let dynamicStatus = budget.dynamicStatusText {
                Text(dynamicStatus)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(profile.energyCalculationMode == .dynamicHealth ? CalorynTheme.textSecondary : CalorynTheme.terracotta)
            }

            if let healthStatusMessage {
                Text(healthStatusMessage)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.terracotta)
            }
        } header: {
            Text("Calorie Estimate")
        } footer: {
            Text(calorieEstimateFooterText(for: profile))
        }
        .task(id: "\(profile.energyCalculationModeRaw)-\(profile.manualOverride)") {
            await settingsEnergyTracker.configure(
                date: .now,
                isEnabled: profile.effectiveEnergyCalculationMode == .dynamicHealth
            )
        }
        .onChange(of: settingsEnergyTracker.message) { _, message in
            guard message != nil, profile.energyCalculationMode == .dynamicHealth else { return }
            profile.energyCalculationMode = .lifestyleEstimate
        }
    }

    private func calorieEstimateModeToggleLabel(for profile: UserProfile) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: calorieEstimateModeIcon(for: profile))
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.sage)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Auto-adjust calories")
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(calorieEstimateModeSubtitle(for: profile))
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func calorieEstimateModeIcon(for profile: UserProfile) -> String {
        profile.effectiveEnergyCalculationMode == .dynamicHealth ? "heart.text.square.fill" : "figure.walk"
    }

    private func calorieEstimateModeSubtitle(for profile: UserProfile) -> String {
        if profile.manualOverride {
            return "Off - manual calorie target is set"
        }

        if profile.energyCalculationMode == .dynamicHealth {
            return "On - using Health data when available"
        }

        return "Off - using your activity level"
    }

    private func dynamicEnergyBinding(for profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: {
                profile.energyCalculationMode == .dynamicHealth
            },
            set: { isEnabled in
                guard isEnabled != (profile.energyCalculationMode == .dynamicHealth) else { return }
                if isEnabled {
                    Task {
                        await enableDynamicEnergy(for: profile)
                    }
                } else {
                    disableDynamicEnergy(for: profile)
                }
            }
        )
    }

    @MainActor
    private func enableDynamicEnergy(for profile: UserProfile) async {
        guard !isRequestingHealthAuthorization else { return }

        isRequestingHealthAuthorization = true
        healthStatusMessage = nil
        defer {
            isRequestingHealthAuthorization = false
        }

        let update = await AppleHealthAdjustmentSettings.enable()
        if update.isEnabled {
            profile.energyCalculationMode = .dynamicHealth
            await settingsEnergyTracker.configure(date: .now, isEnabled: true)
        }
        healthStatusMessage = update.message
    }

    private func disableDynamicEnergy(for profile: UserProfile) {
        let update = AppleHealthAdjustmentSettings.disable()
        profile.energyCalculationMode = .lifestyleEstimate
        healthStatusMessage = update.message
    }

    @MainActor
    private func refreshPendingHealthAuthorizationIfNeeded(for profile: UserProfile) async {
        guard !profile.manualOverride else { return }
        guard profile.energyCalculationMode != .dynamicHealth else {
            settingsEnergyTracker.refreshWhenActive()
            return
        }
        guard AppleHealthAdjustmentSettings.authorizationRequested else { return }
        guard isHealthAvailable, !isRequestingHealthAuthorization else { return }

        isRequestingHealthAuthorization = true
        healthStatusMessage = nil
        defer {
            isRequestingHealthAuthorization = false
        }

        let update = await AppleHealthAdjustmentSettings.enable()
        if update.isEnabled {
            profile.energyCalculationMode = .dynamicHealth
            await settingsEnergyTracker.configure(date: .now, isEnabled: true)
        }
        healthStatusMessage = update.message
    }

    private func settingsBudget(for profile: UserProfile) -> ActivityCalorieBudget {
        profile.activityBudget(
            consumed: 0,
            activeEnergyKcal: settingsEnergyTracker.activeEnergyKcal,
            recentActiveEnergySamples: settingsEnergyTracker.recentActiveEnergySamples,
            isActivityLoading: settingsEnergyTracker.isLoading,
            activityMessage: settingsEnergyTracker.message,
            date: .now
        )
    }

    private func dynamicBaselineText(for budget: ActivityCalorieBudget) -> String {
        guard let baseline = budget.activityBaselineKcal else {
            return "-"
        }

        return Int(baseline.rounded()).kcalFormatted
    }

    private func calorieEstimateFooterText(for profile: UserProfile) -> String {
        if profile.manualOverride {
            return "Manual calorie targets stay fixed until you turn the override off."
        }

        if !isHealthAvailable {
            return AppleHealthAdjustmentSettings.unavailableMessage
        }

        if profile.energyCalculationMode == .dynamicHealth {
            return "Auto-adjust uses Apple Health activity to keep your daily calorie target up to date. Turn it off to use your activity level instead."
        }

        return "Your activity level sets the estimate. Auto-adjust can use Apple Health activity instead."
    }

    private func openHealthAccessSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $themePreferenceRaw) {
                ForEach(ThemePreference.allCases, id: \.self) { preference in
                    Label(preference.displayName, systemImage: preference.icon)
                        .tag(preference.rawValue)
                }
            }

            Toggle(isOn: $showNutriscore) {
                Label("Show Nutri-Score", systemImage: "leaf")
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Display nutrition quality scores from Open Food Facts on foods and in your daily summary.")
        }
    }

    private func goalSection(_ profile: UserProfile) -> some View {
        Section {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Text(profile.dailyCalorieTarget.kcalFormatted)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.sage)
                    .accessibilityIdentifier("settings.calorieTarget")
            }

            if !profile.manualOverride {
                HStack {
                    Label("Adjustment", systemImage: "plusminus")
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Text(adjustmentLabel(for: profile.calorieDeficit))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            ForEach(goalSummaryNutrients(for: profile)) { nutrient in
                HStack {
                    Label(nutrient.displayName, systemImage: nutrient.systemImage)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Spacer()

                    Text(goalSummaryText(for: nutrient, in: profile))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(nutrient.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(goalSummarySpokenText(for: nutrient, in: profile))
                }
            }

            NavigationLink("Edit Goal") {
                GoalEditView(profile: profile)
            }
            .accessibilityIdentifier("settings.editGoal")
        } header: {
            Text("Goal")
        }
    }

    private func goalSummaryNutrients(for profile: UserProfile) -> [TrackedNutrient] {
        TrackedNutrient.allCases.filter { profile.target(for: $0) != nil }
    }

    private func goalSummaryText(for nutrient: TrackedNutrient, in profile: UserProfile) -> String {
        goalSummary(for: nutrient, in: profile, formatter: nutrient.unit.formatted)
    }

    /// VoiceOver reads the bare "66.7g" as an unpronounceable glyph, so the spoken
    /// label spells the unit out.
    private func goalSummarySpokenText(for nutrient: TrackedNutrient, in profile: UserProfile) -> String {
        goalSummary(for: nutrient, in: profile, formatter: nutrient.unit.spokenFormatted)
    }

    private func goalSummary(
        for nutrient: TrackedNutrient,
        in profile: UserProfile,
        formatter: (Double) -> String
    ) -> String {
        guard let target = profile.target(for: nutrient) else { return "Not set" }
        let formattedTarget = formatter(target)

        switch profile.goalKind(for: nutrient) {
        case .minimum:
            return "At least \(formattedTarget)"
        case .target:
            return formattedTarget
        case .maximum:
            return "At most \(formattedTarget)"
        }
    }

    private func adjustmentLabel(for deficit: Double) -> String {
        if deficit > 0 {
            return "-\(Int(deficit)) kcal"
        } else if deficit < 0 {
            return "+\(Int(abs(deficit))) kcal"
        }
        return "Maintenance"
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        Section {
            LabeledContent("Age", value: "\(profile.age)")
            LabeledContent("Sex", value: profile.sex.displayName)
            LabeledContent("Height", value: "\(Int(profile.heightCm)) cm")
            LabeledContent("Weight", value: String(format: "%.1f kg", profile.weightKg))
            LabeledContent("Activity", value: profile.activityLevel.displayName)

            NavigationLink("Edit Profile") {
                ProfileEditView(profile: profile)
            }
            .accessibilityIdentifier("settings.editProfile")
        } header: {
            Text("Profile")
        }
    }

    private var dataSection: some View {
        Section {
            Toggle(isOn: $iCloudSyncEnabled) {
                Label("iCloud Sync", systemImage: "icloud")
            }
            .onChange(of: iCloudSyncEnabled) {
                showRestartAlert = true
            }

            Button {
                exportURL = CSVExporter.exportURL(from: allEntries)
                if exportURL != nil {
                    showExportSheet = true
                }
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(allEntries.isEmpty)
        } header: {
            Text("Data")
        } footer: {
            if iCloudSyncEnabled {
                Text("Your food log syncs automatically across your devices via iCloud.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)

            Link(destination: URL(string: "https://caloryn.app/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            HStack {
                Text("Food data by")
                Spacer()
                Link("Open Food Facts", destination: URL(string: "https://openfoodfacts.org")!)
                    .font(CalorynTheme.caption)
            }
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)
    let profile = UserProfile(age: 30, sex: .male, heightCm: 175, weightKg: 70, activityLevel: .moderatelyActive, dailyCalorieTarget: 2000)
    context.insert(profile)
    try? context.save()
    return SettingsView()
        .modelContainer(container)
}

#Preview("Settings - Auto-adjust Details") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)
    let profile = UserProfile(
        age: 34,
        sex: .female,
        heightCm: 168,
        weightKg: 72,
        activityLevel: .moderatelyActive,
        calorieDeficit: 400,
        energyCalculationMode: .dynamicHealth
    )
    let samples: [DailyActiveEnergySample] = [410.0, 480, 520, 540, 549, 560, 575, 590, 620].enumerated().compactMap { index, activeEnergyKcal in
        guard let date = Calendar.current.date(
            byAdding: .day,
            value: -(index + 1),
            to: Date.now.startOfDay
        ) else {
            return nil
        }

        return DailyActiveEnergySample(date: date, activeEnergyKcal: activeEnergyKcal)
    }
    let tracker = ActiveEnergyDayTracker(dataSource: ActiveEnergyDataSource(
        isHealthAvailable: { true },
        activeEnergyBurnedKcal: { _ in 225 },
        dailyActiveEnergyBurnedKcal: { _, _ in samples },
        observeActiveEnergyChanges: { _ in nil }
    ))

    let _ = context.insert(profile)
    let _ = try? context.save()

    SettingsView(
        settingsEnergyTracker: tracker,
        isHealthAvailable: { true }
    )
    .modelContainer(container)
}

private struct CalorieEstimateMetricRow: View {
    let title: String
    let description: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(description)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Goal Edit

private enum GoalEditFocus: Hashable {
    case manualTarget
    case nutrient(TrackedNutrient)
}

struct GoalEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: GoalEditFocus?

    /// Every rule this screen applies lives in the draft; the view reads it and
    /// renders. See `GoalEditDraft`.
    @State private var draft: GoalEditDraft

    init(profile: UserProfile) {
        self.profile = profile
        _draft = State(initialValue: GoalEditDraft(profile: profile))
    }

    private var calculatedTarget: Int { draft.calculatedTarget(tdee: profile.tdee) }
    private var previewProteinTarget: Double { draft.proteinTargetGrams(tdee: profile.tdee) }
    private var previewCarbTarget: Double { draft.carbTargetGrams(tdee: profile.tdee) }
    private var previewFatTarget: Double { draft.fatTargetGrams(tdee: profile.tdee) }

    var body: some View {
        Form {
            Section("Daily Calorie Target") {
                Toggle("Manual Override", isOn: $draft.manualOverride)
                    .accessibilityIdentifier("goalEdit.manualOverride")
                    .onChange(of: draft.manualOverride) { _, isManual in
                        draft.manualOverrideChanged(to: isManual, tdee: profile.tdee)
                    }

                if draft.manualOverride {
                    HStack {
                        TextField("Target", text: $draft.targetText)
                            .keyboardType(.numberPad)
                            .font(CalorynTheme.numericBody)
                            .focused($focusedField, equals: .manualTarget)
                            .calorynInputField(isFocused: focusedField == .manualTarget)
                            .accessibilityIdentifier("goalEdit.target")
                        Text("kcal")
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                } else {
                    LabeledContent("Estimated Daily Burn", value: "\(Int(profile.tdee)) kcal")
                    LabeledContent("Target", value: "\(calculatedTarget) kcal")
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            if !draft.manualOverride {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Surplus")
                                .font(CalorynTheme.microCaption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                            Slider(value: $draft.calorieDeficit, in: -500...1000, step: 50)
                            Text("Deficit")
                                .font(CalorynTheme.microCaption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        Text(draft.deficitLabel)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.terracotta)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } header: {
                    Text("Calorie Adjustment")
                } footer: {
                    Text("Positive values create a deficit for weight loss, negative values create a surplus for weight gain.")
                }
                .listRowBackground(CalorynTheme.cardBackground)
            }

            Section("Macro Goals") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protein: \(Int(draft.proteinRatio * 100))% · \(previewProteinTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.proteinRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.proteinColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carbs: \(Int(draft.carbRatio * 100))% · \(previewCarbTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.carbRatio, in: 0.10...0.60, step: 0.05)
                        .tint(CalorynTheme.carbColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fat: \(Int(draft.fatRatio * 100))% · \(previewFatTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.fatRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.fatColor)
                }

                if !draft.isMacroValid {
                    Text("Ratios should total 100% (currently \(Int(draft.macroTotal * 100))%)")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                ForEach(TrackedNutrient.editableGoalNutrients) { nutrient in
                    NutrientGoalEditRow(
                        nutrient: nutrient,
                        targetText: targetTextBinding(for: nutrient),
                        goalKind: goalKindBinding(for: nutrient),
                        isInvalid: draft.isInvalidTarget(for: nutrient),
                        focusedField: $focusedField
                    )
                }

                if !draft.areNutrientGoalsValid {
                    Text("Goal values must be positive numbers. Leave a field blank to remove that goal.")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            } header: {
                Text("Additional Nutrient Goals")
            } footer: {
                Text("These goals appear anywhere the nutrient is shown. Sodium and cholesterol are entered in milligrams.")
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if draft.disablesAppleHealthAdjustment {
                        AppleHealthAdjustmentSettings.disable()
                    }
                    draft.apply(to: profile)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(draft.canSave ? CalorynTheme.sage : CalorynTheme.textSecondary)
                }
                .accessibilityIdentifier("goalEdit.save")
                .disabled(!draft.canSave)
            }
        }
        .onAppear {
            draft.loadNutrientGoals(from: profile)
        }
    }

    private func targetTextBinding(for nutrient: TrackedNutrient) -> Binding<String> {
        Binding(
            get: { draft.targetText(for: nutrient) },
            set: { newValue in
                guard draft.targetText(for: nutrient) != newValue else { return }
                draft.nutrientTargetTexts[nutrient] = newValue
            }
        )
    }

    private func goalKindBinding(for nutrient: TrackedNutrient) -> Binding<NutrientGoalKind> {
        Binding(
            get: { draft.goalKind(for: nutrient) },
            set: { draft.nutrientGoalKinds[nutrient] = $0 }
        )
    }
}

private struct NutrientGoalEditRow: View {
    let nutrient: TrackedNutrient
    @Binding var targetText: String
    @Binding var goalKind: NutrientGoalKind
    let isInvalid: Bool
    @FocusState.Binding var focusedField: GoalEditFocus?
    @State private var isGoalTypePickerRendered = false
    @State private var isGoalTypePickerVisible = false

    private var hasValue: Bool {
        !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isGoalTypePickerVisible ? 8 : 0) {
            HStack(spacing: 10) {
                Label(nutrient.displayName, systemImage: nutrient.systemImage)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                TextField("Optional", text: $targetText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .nutrient(nutrient))
                    .multilineTextAlignment(.trailing)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(isInvalid ? CalorynTheme.terracotta : CalorynTheme.textPrimary)
                    .calorynInputField(isFocused: focusedField == .nutrient(nutrient))
                    .frame(width: 92)
                    .accessibilityLabel("\(nutrient.displayName) goal in \(nutrient.unit.inputUnitLabel)")

                Text(nutrient.unit.inputUnitLabel)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
            }

            if isGoalTypePickerRendered {
                Picker("Goal type", selection: $goalKind) {
                    ForEach(NutrientGoalKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: isGoalTypePickerVisible ? nutrientGoalPickerHeight : 0, alignment: .top)
                .opacity(isGoalTypePickerVisible ? 1 : 0)
                .scaleEffect(y: isGoalTypePickerVisible ? 1 : 0.97, anchor: .top)
                .clipped()
                .allowsHitTesting(isGoalTypePickerVisible)
                .accessibilityHidden(!isGoalTypePickerVisible)
                .accessibilityLabel("\(nutrient.displayName) goal type")
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            isGoalTypePickerRendered = hasValue
            isGoalTypePickerVisible = hasValue
        }
        .onChange(of: hasValue) { _, shouldShow in
            updateGoalTypePickerVisibility(shouldShow)
        }
    }

    private func updateGoalTypePickerVisibility(_ shouldShow: Bool) {
        if shouldShow {
            isGoalTypePickerRendered = true
            DispatchQueue.main.async {
                guard hasValue else { return }
                withAnimation(nutrientGoalExpansionAnimation) {
                    isGoalTypePickerVisible = true
                }
            }
        } else {
            withAnimation(nutrientGoalExpansionAnimation) {
                isGoalTypePickerVisible = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + nutrientGoalAnimationDuration) {
                guard !hasValue else { return }
                isGoalTypePickerRendered = false
            }
        }
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    private var isActivityLevelLocked: Bool {
        ProfileEditActivityLevelPolicy.isLocked(for: profile)
    }

    var body: some View {
        Form {
            Section("Personal Info") {
                Stepper("Age: \(profile.age)", value: $profile.age, in: 16...100)

                Picker("Sex", selection: $profile.sex) {
                    ForEach(Sex.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Height: \(Int(profile.heightCm)) cm")
                    Slider(value: $profile.heightCm, in: 120...220, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Weight: \(String(format: "%.1f", profile.weightKg)) kg")
                    Slider(value: $profile.weightKg, in: 40...200, step: 0.5)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                Picker("Activity", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .disabled(isActivityLevelLocked)
            } header: {
                Text("Activity Level")
            } footer: {
                if isActivityLevelLocked {
                    Text(ProfileEditActivityLevelPolicy.lockedExplanation)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    let cal = Double(profile.dailyCalorieTarget)
                    let proteinRatio = cal > 0 ? (profile.proteinTargetG * 4.0) / cal : 0.30
                    let carbRatio    = cal > 0 ? (profile.carbTargetG    * 4.0) / cal : 0.40
                    let fatRatio     = cal > 0 ? (profile.fatTargetG     * 9.0) / cal : 0.30
                    profile.recalculate(proteinRatio: proteinRatio, carbRatio: carbRatio, fatRatio: fatRatio)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(CalorynTheme.sage)
                }
            }
        }
    }
}
