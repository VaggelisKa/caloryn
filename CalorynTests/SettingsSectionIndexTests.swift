import Foundation
import Testing
@testable import Caloryn

@Suite("Settings section index")
@MainActor
struct SettingsSectionIndexTests {
    private static let english = Locale(identifier: "en_US")
    private static let greek = Locale(identifier: "el_GR")

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static let profile = SettingsSectionIndex.Profile(
        dailyCalorieTarget: 2_000,
        summary: SettingsProfileSummary(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive
        )
    )

    private func index(
        profile: SettingsSectionIndex.Profile? = Self.profile,
        theme: ThemePreference = .system,
        isReminderEnabled: Bool = false,
        reminderMinutes: Int = 21 * 60,
        isICloudSyncEnabled: Bool = true,
        versionText: String = "2.1.0"
    ) -> SettingsSectionIndex {
        SettingsSectionIndex(
            profile: profile,
            theme: theme,
            isReminderEnabled: isReminderEnabled,
            reminderMinutesFromMidnight: reminderMinutes,
            isICloudSyncEnabled: isICloudSyncEnabled,
            versionText: versionText
        )
    }

    @Test("With a profile every section is listed, in the order of the single page")
    func everySectionWithAProfile() {
        #expect(index().sections == [.goal, .profile, .appearance, .reminder, .chatbotLog, .data, .about])
    }

    @Test("Without a profile there is no goal or profile to show")
    func noProfileDropsGoalAndProfile() {
        #expect(index(profile: nil).sections == [.appearance, .reminder, .chatbotLog, .data, .about])
    }

    @Test("The goal is selected first when there is a profile")
    func defaultsToGoal() {
        #expect(index().selection(resolving: nil) == .goal)
    }

    @Test("Appearance is selected first when there is no profile")
    func defaultsToAppearanceWithoutProfile() {
        #expect(index(profile: nil).selection(resolving: nil) == .appearance)
    }

    @Test("A section the person picked stays selected")
    func keepsAChosenSection() {
        #expect(index().selection(resolving: .data) == .data)
    }

    @Test("A picked section that is no longer listed falls back to the default")
    func chosenSectionThatVanished() {
        #expect(index(profile: nil).selection(resolving: .profile) == .appearance)
    }

    @Test("The goal reads as the daily calorie target, grouped for the locale")
    func goalSummary() {
        #expect(index().summary(for: .goal, locale: Self.english) == "2,000 kcal")
        #expect(index().summary(for: .goal, locale: Self.greek) == "2.000 kcal")
    }

    @Test("The profile reads as age and weight")
    func profileSummary() {
        #expect(index().summary(for: .profile, locale: Self.english) == "30 · 80.0 kg")
        #expect(index().summary(for: .profile, locale: Self.greek) == "30 · 80,0 kg")
    }

    @Test("Appearance reads as the chosen theme", arguments: ThemePreference.allCases)
    func appearanceSummary(theme: ThemePreference) {
        #expect(index(theme: theme).summary(for: .appearance) == theme.displayName)
    }

    @Test("A reminder that is off says so")
    func reminderOff() {
        #expect(index(isReminderEnabled: false).summary(for: .reminder) == "Off")
    }

    @Test("A reminder that is on carries its time in the locale's clock")
    func reminderOn() {
        let reminder = index(isReminderEnabled: true, reminderMinutes: 21 * 60 + 30)

        #expect(reminder.summary(for: .reminder, locale: Self.english, calendar: Self.utc) == "On · 9:30\u{202F}PM")
        #expect(reminder.summary(for: .reminder, locale: Locale(identifier: "en_GB"), calendar: Self.utc) == "On · 21:30")
    }

    @Test("A stored time outside the day still reads as on")
    func reminderWithAnImpossibleTime() {
        #expect(index(isReminderEnabled: true, reminderMinutes: -5).summary(for: .reminder) == "On")
    }

    @Test("Your data reads as whether iCloud sync is on")
    func dataSummary() {
        #expect(index(isICloudSyncEnabled: true).summary(for: .data) == "iCloud on")
        #expect(index(isICloudSyncEnabled: false).summary(for: .data) == "iCloud off")
    }

    @Test("About reads as the app version")
    func aboutSummary() {
        #expect(index(versionText: "2.1.0").summary(for: .about) == "2.1.0")
    }

    @Test("The chatbot section has nothing to summarise")
    func chatbotSummary() {
        #expect(index().summary(for: .chatbotLog).isEmpty)
    }

    @Test("Each section row has its own identifier")
    func identifiers() {
        #expect(SettingsSection.goal.accessibilityIdentifier == "settings.section.goal")
        #expect(Set(SettingsSection.allCases.map(\.accessibilityIdentifier)).count == SettingsSection.allCases.count)
    }
}
