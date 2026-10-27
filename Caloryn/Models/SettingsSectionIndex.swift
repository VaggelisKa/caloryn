import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case goal
    case profile
    case appearance
    case reminder
    case chatbotLog
    case data
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goal: "Your goal"
        case .profile: "Your profile"
        case .appearance: "Appearance"
        case .reminder: "Reminder"
        case .chatbotLog: "Log from a chatbot"
        case .data: "Your data"
        case .about: "About"
        }
    }

    var accessibilityIdentifier: String { "settings.section.\(rawValue)" }

    fileprivate var needsProfile: Bool {
        self == .goal || self == .profile
    }
}

struct SettingsSectionIndex: Equatable {
    struct Profile: Equatable {
        let dailyCalorieTarget: Int
        let summary: SettingsProfileSummary
    }

    let profile: Profile?
    let theme: ThemePreference
    let isReminderEnabled: Bool
    let reminderMinutesFromMidnight: Int
    let isICloudSyncEnabled: Bool
    let versionText: String

    var sections: [SettingsSection] {
        SettingsSection.allCases.filter { profile != nil || !$0.needsProfile }
    }

    var defaultSelection: SettingsSection {
        profile == nil ? .appearance : .goal
    }

    func selection(resolving chosen: SettingsSection?) -> SettingsSection {
        guard let chosen, sections.contains(chosen) else { return defaultSelection }
        return chosen
    }

    func summary(
        for section: SettingsSection,
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> String {
        switch section {
        case .goal:
            guard let profile else { return "" }
            return "\(profile.dailyCalorieTarget.formatted(.number.locale(locale))) kcal"
        case .profile:
            guard let profile else { return "" }
            return "\(profile.summary.ageText) · \(profile.summary.weightText(locale: locale))"
        case .appearance:
            return theme.displayName
        case .reminder:
            return reminderText(locale: locale, calendar: calendar)
        case .chatbotLog:
            return ""
        case .data:
            return isICloudSyncEnabled ? "iCloud on" : "iCloud off"
        case .about:
            return versionText
        }
    }

    private func reminderText(locale: Locale, calendar: Calendar) -> String {
        guard isReminderEnabled else { return "Off" }
        guard let time = calendar.date(
            bySettingHour: reminderMinutesFromMidnight / 60,
            minute: reminderMinutesFromMidnight % 60,
            second: 0,
            of: Date(timeIntervalSinceReferenceDate: 0)
        ) else { return "On" }

        let style = Date.FormatStyle(
            date: .omitted,
            time: .shortened,
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        return "On · \(time.formatted(style))"
    }
}
