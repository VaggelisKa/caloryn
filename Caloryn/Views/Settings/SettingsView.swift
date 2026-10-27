import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(filter: FoodLogEntryWindow.loggedSince(FoodLogEntryWindow.recentStart(now: .now, calendar: .current)))
    private var recentEntries: [FoodLogEntry]
    @Query(FoodLogEntryWindow.anyEntry) private var anyEntry: [FoodLogEntry]
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("showNutriscore") private var showNutriscore = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @AppStorage("dailyReminderEnabled") private var isReminderEnabled = false
    @AppStorage("dailyReminderMinutesFromMidnight") private var reminderMinutes = DailyReminderPlanner.defaultReminderMinutes
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showRestartAlert = false
    @State private var isEditingGoal = false
    @State private var isEditingProfile = false
    @State private var pageSize: CGSize = .zero
    @State private var chosenSection: SettingsSection?

    private var profile: UserProfile? { profiles.first }

    private var sectionIndex: SettingsSectionIndex {
        SettingsSectionIndex(
            profile: profile.map { profile in
                SettingsSectionIndex.Profile(
                    dailyCalorieTarget: profile.dailyCalorieTarget,
                    summary: profileSummary(profile)
                )
            },
            theme: ThemePreference(rawValue: themePreferenceRaw) ?? .system,
            isReminderEnabled: isReminderEnabled,
            reminderMinutesFromMidnight: reminderMinutes,
            isICloudSyncEnabled: iCloudSyncEnabled,
            versionText: appVersion
        )
    }

    var body: some View {
        let index = sectionIndex
        let split = RegularWidthSplit(
            isRegularWidth: horizontalSizeClass == .regular,
            isRegularHeight: verticalSizeClass == .regular,
            pageSize: pageSize
        )

        NavigationStack {
            Group {
                if split.showsColumns {
                    SplitColumns(split: split) {
                        sectionList(index)
                    } secondary: {
                        List {
                            section(index.selection(resolving: chosenSection))
                        }
                        .calorynGroupedListStyle()
                    }
                } else {
                    List {
                        ForEach(index.sections) { section($0) }
                    }
                    .calorynGroupedListStyle()
                }
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { pageSize = $0 }
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
    }

    @ViewBuilder
    private func section(_ section: SettingsSection) -> some View {
        Group {
            switch section {
            case .goal:
                if let profile {
                    goalSection(profile)
                }
            case .profile:
                if let profile {
                    profileSection(profile)
                }
            case .appearance:
                appearanceSection
            case .reminder:
                DailyReminderSettingsSection()
            case .chatbotLog:
                ChatbotLogSettingsSection()
            case .data:
                dataSection
            case .about:
                aboutSection
            }
        }
        .listRowBackground(CalorynTheme.backgroundSecondary)
    }

    private func sectionList(_ index: SettingsSectionIndex) -> some View {
        let selected = index.selection(resolving: chosenSection)

        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(index.sections) { section in
                    let isSelected = section == selected

                    Button {
                        chosenSection = section
                    } label: {
                        SettingsSectionIndexRow(
                            title: section.title,
                            summary: index.summary(for: section),
                            isSelected: isSelected
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier(section.accessibilityIdentifier)
                }
            }
            .padding(.leading, CalorynTheme.pagePadding)
            .padding(.trailing, CalorynTheme.pagePadding / 2)
            .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
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
        } header: {
            SettingsSectionTitle("Your goal")
        } footer: {
            SettingsSectionFooter(SettingsGoalSummary.footerText(isManualOverride: profile.manualOverride))
        }
    }

    private func goalPlate(for profile: UserProfile) -> CalorieDonutSummary {
        let entries = DayFoodLogSelection.entries(recentEntries, on: .now, date: \.date)
            .map { SettingsGoalPlate.Entry(meal: $0.mealType, calories: $0.calories) }
        let budget = profile.calorieBudget(consumed: SettingsGoalPlate.eaten(entries))

        return CalorieDonutSummary(mealTotals: SettingsGoalPlate.mealTotals(entries), budget: budget)
    }

    private func profileSummary(_ profile: UserProfile) -> SettingsProfileSummary {
        SettingsProfileSummary(
            age: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            activityLevel: profile.activityLevel
        )
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        let summary = profileSummary(profile)

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

private struct SettingsSectionIndexRow: View {
    let title: String
    let summary: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(CalorynTheme.bodyText.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? CalorynTheme.textOnAccent : CalorynTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !summary.isEmpty {
                Text(summary)
                    .font(CalorynTheme.cardSubtitle.monospacedDigit())
                    .foregroundStyle(isSelected ? CalorynTheme.textOnAccent.opacity(0.75) : CalorynTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
                    .fill(CalorynTheme.accent)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
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
