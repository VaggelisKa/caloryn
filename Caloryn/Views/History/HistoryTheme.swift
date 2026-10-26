import SwiftUI

enum HistoryTheme {
    static let under = CalorynTheme.dataTertiary

    static func color(for status: HistoryGoalStatus) -> Color {
        switch status {
        case .under:
            under
        case .onTrack:
            CalorynTheme.dataSecondary
        case .over:
            CalorynTheme.dataPrimary
        case .notLogged:
            CalorynTheme.fillTrack
        }
    }

    static func weeklyConsistencyColor(for week: HistoryWeekSummary) -> Color {
        color(for: .weeklyConsistency(onTrackDays: week.onTrackDays, loggedDays: week.loggedDays))
    }
}

extension HistoryGoalStatus {
    var tint: Color {
        HistoryTheme.color(for: self)
    }
}

extension HistoryWeekSummary {
    var consistencyTint: Color {
        HistoryTheme.weeklyConsistencyColor(for: self)
    }
}
