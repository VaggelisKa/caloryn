import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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
            .calorynPageCanvas()
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
        let estimate = calorieEstimate(for: profile)

        return Section {
            if estimate.isToggleBound {
                Toggle(isOn: dynamicEnergyBinding(for: profile)) {
                    calorieEstimateModeToggleLabel(estimate)
                }
                .disabled(estimate.isToggleDisabled)
            } else {
                Toggle(isOn: .constant(estimate.isToggleOn)) {
                    calorieEstimateModeToggleLabel(estimate)
                }
                .disabled(estimate.isToggleDisabled)
            }

            if estimate.showsDynamicMetrics {
                CalorieEstimateMetricRow(
                    title: "Valid Days",
                    description: SettingsCalorieEstimate.validActivityDaysDescription,
                    value: SettingsCalorieEstimate.validActivityDaysText(validActivityDays: budget.validActivityDays)
                )
                CalorieEstimateMetricRow(
                    title: "Baseline",
                    description: "Your typical Active Energy from recent valid days.",
                    value: SettingsCalorieEstimate.baselineText(activityBaselineKcal: budget.activityBaselineKcal)
                )
                CalorieEstimateMetricRow(
                    title: "Today",
                    description: "Active Energy read from Apple Health for today.",
                    value: SettingsCalorieEstimate.todayText(
                        activeEnergyKcal: settingsEnergyTracker.activeEnergyKcal
                    )
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
                    .foregroundStyle(estimate.isDynamicStatusInformational ? CalorynTheme.textSecondary : CalorynTheme.terracotta)
            }

            if let healthStatusMessage {
                Text(healthStatusMessage)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.terracotta)
            }
        } header: {
            Text("Calorie Estimate")
        } footer: {
            Text(estimate.footerText)
        }
        .task(id: "\(profile.energyCalculationModeRaw)-\(profile.manualOverride)") {
            await settingsEnergyTracker.configure(
                date: .now,
                isEnabled: calorieEstimate(for: profile).isActiveEnergyTrackingEnabled
            )
        }
        .onChange(of: settingsEnergyTracker.message) { _, message in
            guard SettingsCalorieEstimate.fallsBackToLifestyle(
                energyCalculationMode: profile.energyCalculationMode,
                trackerMessage: message
            ) else { return }
            profile.energyCalculationMode = .lifestyleEstimate
        }
    }

    private func calorieEstimate(for profile: UserProfile) -> SettingsCalorieEstimate {
        SettingsCalorieEstimate(
            isManualOverride: profile.manualOverride,
            energyCalculationMode: profile.energyCalculationMode,
            isHealthAvailable: isHealthAvailable,
            isRequestingAuthorization: isRequestingHealthAuthorization
        )
    }

    private func calorieEstimateModeToggleLabel(_ estimate: SettingsCalorieEstimate) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: estimate.modeIconName)
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.sage)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Auto-adjust calories")
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(estimate.modeSubtitle)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func dynamicEnergyBinding(for profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: {
                profile.energyCalculationMode == .dynamicHealth
            },
            set: { isEnabled in
                switch SettingsDynamicEnergyFlow.toggleRequest(
                    isEnabled: isEnabled,
                    energyCalculationMode: profile.energyCalculationMode
                ) {
                case .none:
                    return
                case .enable:
                    Task {
                        await enableDynamicEnergy(for: profile)
                    }
                case .disable:
                    let step = SettingsDynamicEnergyFlow.disable(
                        isRequestingAuthorization: isRequestingHealthAuthorization
                    )
                    applyImmediately(step, to: profile)
                }
            }
        )
    }

    @MainActor
    private func enableDynamicEnergy(for profile: UserProfile) async {
        guard let step = await SettingsDynamicEnergyFlow.enable(
            isRequestingAuthorization: isRequestingHealthAuthorization,
            onRequestStarted: { applyState($0) }
        ) else { return }

        await apply(step, to: profile)
    }

    @MainActor
    private func refreshPendingHealthAuthorizationIfNeeded(for profile: UserProfile) async {
        let action = SettingsHealthAuthorizationRefresh.action(
            isManualOverride: profile.manualOverride,
            energyCalculationMode: profile.energyCalculationMode,
            isAuthorizationRequested: AppleHealthAdjustmentSettings.authorizationRequested,
            isHealthAvailable: isHealthAvailable,
            isRequestingAuthorization: isRequestingHealthAuthorization
        )

        guard let step = await SettingsDynamicEnergyFlow.step(
            after: action,
            isRequestingAuthorization: isRequestingHealthAuthorization,
            onRequestStarted: { applyState($0) }
        ) else { return }

        await apply(step, to: profile)
    }

    /// Performs a step's writes in order: the profile, then the tracker, then
    /// the screen state the section renders.
    @MainActor
    private func apply(_ step: SettingsDynamicEnergyFlow.Step, to profile: UserProfile) async {
        if let energyCalculationMode = step.energyCalculationMode {
            profile.energyCalculationMode = energyCalculationMode
        }

        switch step.trackerCommand {
        case .start:
            await settingsEnergyTracker.configure(date: .now, isEnabled: true)
        case .refresh:
            settingsEnergyTracker.refreshWhenActive()
        case .none:
            break
        }

        if let state = step.state {
            applyState(state)
        }
    }

    /// `apply` for a step with no tracker work, so turning auto-adjust off still
    /// happens in the same turn as the tap rather than a `Task` later.
    @MainActor
    private func applyImmediately(_ step: SettingsDynamicEnergyFlow.Step, to profile: UserProfile) {
        if let energyCalculationMode = step.energyCalculationMode {
            profile.energyCalculationMode = energyCalculationMode
        }

        if let state = step.state {
            applyState(state)
        }
    }

    @MainActor
    private func applyState(_ state: SettingsDynamicEnergyFlow.State) {
        isRequestingHealthAuthorization = state.isRequestingAuthorization
        healthStatusMessage = state.statusMessage
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
        let summary = SettingsGoalSummary(
            targets: profile.nutrientTargets,
            goalKinds: profile.nutrientGoalKinds
        )

        return Section {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Text(profile.dailyCalorieTarget.kcalFormatted)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.sage)
                    .accessibilityIdentifier("settings.calorieTarget")
            }

            if SettingsGoalSummary.showsAdjustmentRow(isManualOverride: profile.manualOverride) {
                HStack {
                    Label("Adjustment", systemImage: "plusminus")
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Text(SettingsGoalSummary.adjustmentLabel(calorieDeficit: profile.calorieDeficit))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            ForEach(summary.nutrients) { nutrient in
                HStack {
                    Label(nutrient.displayName, systemImage: nutrient.systemImage)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Spacer()

                    Text(summary.text(for: nutrient))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(nutrient.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel(summary.spokenText(for: nutrient))
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

    private func profileSection(_ profile: UserProfile) -> some View {
        let summary = SettingsProfileSummary(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevel: profile.activityLevel
        )

        return Section {
            LabeledContent("Age", value: summary.ageText)
            LabeledContent("Sex", value: summary.sexText)
            LabeledContent("Height", value: summary.heightText)
            LabeledContent("Weight", value: summary.weightText)
            LabeledContent("Activity", value: summary.activityText)

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
                if SettingsDataSectionRules.presentsShareSheet(exportURL: exportURL) {
                    showExportSheet = true
                }
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(!SettingsDataSectionRules.isExportEnabled(loggedEntryCount: allEntries.count))
        } header: {
            Text("Data")
        } footer: {
            if SettingsDataSectionRules.showsSyncFooter(isICloudSyncEnabled: iCloudSyncEnabled) {
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
        SettingsAboutInfo.versionText(
            shortVersionString: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
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

private struct PreviewActiveEnergyReader: ActiveEnergyReading {
    let activeEnergyKcal: Double
    let samples: [DailyActiveEnergySample]

    var isHealthDataAvailable: Bool { true }

    func requestActiveEnergyAuthorization() async throws {}

    func activeEnergyBurnedKcal(for date: Date, calendar: Calendar) async throws -> Double {
        activeEnergyKcal
    }

    func dailyActiveEnergyBurnedKcal(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [DailyActiveEnergySample] {
        samples
    }

    func observeActiveEnergyChanges(onChange: @escaping @MainActor () -> Void) -> ActiveEnergyObservation? {
        nil
    }
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
    let tracker = ActiveEnergyDayTracker(
        reader: PreviewActiveEnergyReader(activeEnergyKcal: 225, samples: samples)
    )

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

