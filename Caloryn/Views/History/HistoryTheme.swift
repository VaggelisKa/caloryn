import SwiftUI

/// History's status colours on the Plate / Market palette.
///
/// Red no longer means "over" — it means lunch — so status is told by weight instead, three
/// steps that stay apart in both appearances: a light grey day is under, the neutral eaten
/// fill is on track, a full ink day is over, and an unlogged day is only a hairline.
///
/// Under is `dataTertiary`, not the spec's first draft of `textSecondary`: that sat at
/// 1.04:1 against `dataSecondary` in light mode, so an under day and an on-track day were the
/// same colour on every strip and bar that tells them apart by colour alone.
enum HistoryTheme {
    /// The colour of an under-goal day.
    static let under = CalorynTheme.dataTertiary

    static func color(for status: HistoryGoalStatus) -> Color {
        switch status {
        case .under:
            under
        case .onTrack:
            CalorynTheme.dataSecondary
        case .over:
            CalorynTheme.textPrimary
        case .notLogged:
            CalorynTheme.hairline
        }
    }

    /// A week's consistency, in the day palette: a mostly on-track week (two thirds or more)
    /// takes the on-track colour, a middling one the under colour, a poor one the over colour.
    /// The same three steps as the days, so the tiers are as far apart as the statuses are.
    /// The rule is `HistoryGoalStatus.weeklyConsistency`, which the 90-day plates share.
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
