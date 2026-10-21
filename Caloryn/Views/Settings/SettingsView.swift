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
    @Query(filter: FoodLogEntryWindow.loggedSince(FoodLogEntryWindow.recentStart(now: .now, calendar: .current)))
    private var recentEntries: [FoodLogEntry]
    @Query(FoodLogEntryWindow.anyEntry) private var anyEntry: [FoodLogEntry]
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("showNutriscore") private var showNutriscore = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showRestartAlert = false
    @State private var isRequestingHealthAuthorization = false
    @State private var healthStatusMessage: String?
    @State private var settingsEnergyTracker = ActiveEnergyDayTracker()
    @State private var isEditingGoal = false
    @State private var isEditingProfile = false

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
                if let profile {
                    goalSection(profile)
                        .listRowBackground(CalorynTheme.backgroundSecondary)
                    profileSection(profile)
                        .listRowBackground(CalorynTheme.backgroundSecondary)
                }

                appearanceSection
                    .listRowBackground(CalorynTheme.backgroundSecondary)
                DailyReminderSettingsSection()
                    .listRowBackground(CalorynTheme.backgroundSecondary)
                dataSection
                    .listRowBackground(CalorynTheme.backgroundSecondary)
                aboutSection
                    .listRowBackground(CalorynTheme.backgroundSecondary)
            }
            .calorynGroupedListStyle()
            .calorynPageCanvas()
            .calorynLargeTitle("Settings")
            .navigationDestination(isPresented: $isEditingGoal) {
                if let profile {
                    GoalEditView(profile: profile)
                }
            }
            .navigationDestination(isPresented: $isEditingProfile) {
                if let profile {
                    ProfileEditView(profile: profile)
                }
            }
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

    @ViewBuilder
    private func calorieEstimateRows(_ profile: UserProfile) -> some View {
        let budget = settingsBudget(for: profile)
        let estimate = calorieEstimate(for: profile)

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
                title: "Valid days",
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
                    .tint(CalorynTheme.textSecondary)

                Text("Requesting Apple Health access")
                    .font(CalorynTheme.cardSubtitle)
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
                    .foregroundStyle(CalorynTheme.accent)
                }
                .font(CalorynTheme.caption)
                .buttonStyle(.borderless)
                .accessibilityLabel("Open app settings")
            }
        } else if let dynamicStatus = budget.dynamicStatusText {
            if estimate.isDynamicStatusInformational {
                Text(dynamicStatus)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            } else {
                SettingsWarningText(dynamicStatus)
            }
        }

        if let healthStatusMessage {
            SettingsWarningText(healthStatusMessage)
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
        SettingsToggleLabel(title: "Auto-adjust calories", subtitle: estimate.modeSubtitle)
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
            SettingsThemeRow(selection: $themePreferenceRaw)

            Toggle(isOn: $showNutriscore) {
                SettingsToggleLabel(title: "Show Nutri-Score")
            }
        } header: {
            SettingsSectionTitle("Appearance")
        } footer: {
            SettingsSectionFooter("Display nutrition quality scores from Open Food Facts on foods and in your daily summary.")
        }
    }

    private func goalSection(_ profile: UserProfile) -> some View {
        let summary = SettingsGoalSummary(
            targets: profile.nutrientTargets,
            goalKinds: profile.nutrientGoalKinds
        )
        let estimate = calorieEstimate(for: profile)

        return Section {
            // The button is laid over the headline rather than wrapping it: a button's label
            // collapses into the button for accessibility, and the number has to stay its own
            // element (`settings.calorieTarget`) for a journey to read it. The headline's text
            // takes no touches, so a tap anywhere on the row still lands on the button.
            SettingsDisclosureLabel {
                SettingsGoalHeadline(
                    plate: goalPlate(for: profile),
                    targetText: SettingsGoalSummary.dailyTargetText(profile.dailyCalorieTarget),
                    subtitle: SettingsGoalSummary.goalSubtitle(
                        calorieDeficit: profile.calorieDeficit,
                        isManualOverride: profile.manualOverride
                    )
                )
            }
            .allowsHitTesting(false)
            .overlay {
                Button {
                    isEditingGoal = true
                } label: {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Edit goal")
                .accessibilityIdentifier("settings.editGoal")
                .accessibilityHint("Double tap to edit your goal")
            }

            ForEach(summary.nutrients) { nutrient in
                SettingsValueRow(
                    title: nutrient.displayName.sentenceCased,
                    value: summary.text(for: nutrient),
                    valueAccessibilityLabel: summary.spokenText(for: nutrient)
                )
            }

            calorieEstimateRows(profile)
        } header: {
            SettingsSectionTitle("Your goal")
        } footer: {
            SettingsSectionFooter(estimate.footerText)
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

    private func goalPlate(for profile: UserProfile) -> CalorieDonutSummary {
        let entries = DayFoodLogSelection.entries(recentEntries, on: .now, date: \.date)
            .map { SettingsGoalPlate.Entry(meal: $0.mealType, calories: $0.calories) }
        let budget = profile.activityBudget(
            consumed: SettingsGoalPlate.eaten(entries),
            activeEnergyKcal: settingsEnergyTracker.activeEnergyKcal,
            recentActiveEnergySamples: settingsEnergyTracker.recentActiveEnergySamples,
            isActivityLoading: settingsEnergyTracker.isLoading,
            activityMessage: settingsEnergyTracker.message,
            date: .now
        )

        return CalorieDonutSummary(mealTotals: SettingsGoalPlate.mealTotals(entries), budget: budget)
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
            SettingsValueRow(title: "Age", value: summary.ageText)
                .accessibilityIdentifier("settings.profile.age")
            SettingsValueRow(title: "Sex", value: summary.sexText)
                .accessibilityIdentifier("settings.profile.sex")
            SettingsValueRow(title: "Height", value: summary.heightText)
            SettingsValueRow(title: "Weight", value: summary.weightText)
            SettingsValueRow(title: "Activity", value: summary.activityText)

            Button {
                isEditingProfile = true
            } label: {
                SettingsDisclosureLabel {
                    Text("Edit profile")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textPrimary)
                }
            }
            .accessibilityIdentifier("settings.editProfile")
        } header: {
            SettingsSectionTitle("Your profile")
        }
    }

    private var dataSection: some View {
        let isExportEnabled = SettingsDataSectionRules.isExportEnabled(loggedEntryCount: anyEntry.count)

        return Section {
            Toggle(isOn: $iCloudSyncEnabled) {
                SettingsToggleLabel(title: "iCloud sync", subtitle: "Private to your Apple account")
            }
            .onChange(of: iCloudSyncEnabled) {
                showRestartAlert = true
            }

            Button {
                exportURL = CSVExporter.exportURL(from: everyLoggedEntry())
                if SettingsDataSectionRules.presentsShareSheet(exportURL: exportURL) {
                    showExportSheet = true
                }
            } label: {
                HStack {
                    Text("Export everything as CSV")
                        .font(CalorynTheme.bodyText)
                    Spacer(minLength: 12)
                    Image(systemName: "square.and.arrow.up")
                        .font(CalorynTheme.toolbarIcon)
                        .accessibilityHidden(true)
                }
                .foregroundStyle(isExportEnabled ? CalorynTheme.accent : CalorynTheme.textTertiary)
                .contentShape(Rectangle())
            }
            .disabled(!isExportEnabled)
            .accessibilityIdentifier("settings.export")
        } header: {
            SettingsSectionTitle("Your data")
        } footer: {
            if SettingsDataSectionRules.showsSyncFooter(isICloudSyncEnabled: iCloudSyncEnabled) {
                SettingsSectionFooter("Your food log syncs automatically across your devices via iCloud.")
            }
        }
    }

    private func everyLoggedEntry() -> [FoodLogEntry] {
        (try? modelContext.fetch(FetchDescriptor<FoodLogEntry>())) ?? []
    }

    private var aboutSection: some View {
        Section {
            SettingsValueRow(title: "Version", value: appVersion)

            Link(destination: URL(string: "https://caloryn.app/privacy")!) {
                HStack {
                    Text("Privacy policy")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }
            }

            HStack {
                Text("Food data by")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Link("Open Food Facts", destination: URL(string: "https://openfoodfacts.org")!)
                    .font(CalorynTheme.bodyText.weight(.semibold))
                    .foregroundStyle(CalorynTheme.accent)
            }
        } header: {
            SettingsSectionTitle("About")
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

private struct SettingsGoalHeadline: View {
    let plate: CalorieDonutSummary
    let targetText: String
    let subtitle: String

    @ScaledMetric(relativeTo: .headline) private var plateSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            CalorieMiniDonutView(
                summary: plate,
                size: plateSize,
                plateColor: CalorynTheme.backgroundPrimary,
                fillsPlate: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(targetText)
                    .font(CalorynTheme.itemTitle.monospacedDigit())
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .accessibilityIdentifier("settings.calorieTarget")

                Text(subtitle)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        // The hairline under the headline runs from the group's edge like every other row's,
        // not from the text beside the plate, where the system would start it.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}

private struct SettingsThemeRow: View {
    @Binding var selection: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                title
                Spacer(minLength: 8)
                segments
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                segments
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                stackedChoices
            }
        }
    }

    private var stackedChoices: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(ThemePreference.allCases, id: \.self) { preference in
                let isSelected = selection == preference.rawValue

                Button {
                    selection = preference.rawValue
                } label: {
                    Text(preference.displayName)
                        .calorynChip(isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preference.displayName) theme")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }

    private var title: some View {
        Text("Theme")
            .font(CalorynTheme.bodyText)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityHidden(true)
    }

    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(ThemePreference.allCases, id: \.self) { preference in
                let isSelected = selection == preference.rawValue

                Button {
                    selection = preference.rawValue
                } label: {
                    Text(preference.displayName)
                        .font(CalorynTheme.chipLabel.weight(isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? CalorynTheme.textOnAccent : CalorynTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 28)
                        .background {
                            if isSelected {
                                Capsule().fill(CalorynTheme.accent)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(preference.displayName) theme")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(CalorynTheme.backgroundPrimary, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Theme")
    }
}

private struct CalorieEstimateMetricRow: View {
    let title: String
    let description: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(description)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Text(value)
                .font(CalorynTheme.bodyText.monospacedDigit())
                .foregroundStyle(CalorynTheme.textPrimary)
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
