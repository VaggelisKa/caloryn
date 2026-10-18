import SwiftUI

enum HistoryTheme {
    static let under = CalorynTheme.historyEatenLight

    static func color(for status: HistoryGoalStatus) -> Color {
        switch status {
        case .under:
            under
        case .onTrack:
            CalorynTheme.historyEaten
        case .over:
            CalorynTheme.textPrimary
        case .notLogged:
            CalorynTheme.hairline
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
