import SwiftUI

enum HistoryTheme {
    static let under = Color(.historyUnder)

    static func color(for status: HistoryGoalStatus) -> Color {
        switch status {
        case .under:
            under
        case .onTrack:
            CalorynTheme.sage
        case .over:
            CalorynTheme.terracotta
        case .notLogged:
            CalorynTheme.textSecondary.opacity(0.22)
        }
    }

    static func weeklyConsistencyColor(for week: HistoryWeekSummary) -> Color {
        guard week.loggedDays > 0 else {
            return CalorynTheme.textSecondary.opacity(0.22)
        }
        if week.onTrackRatio >= 0.66 { return CalorynTheme.sage }
        if week.onTrackRatio >= 0.34 { return under }
        return CalorynTheme.terracotta
    }
}

extension View {
    func historyCard() -> some View {
        solidCard()
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
