import SwiftUI
import UIKit

enum HistoryTheme {
    static let cardGlassTint = Color(UIColor { traits in
        UIColor.white.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.06 : 0.14)
    })

    static let under = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.784, green: 0.635, blue: 0.314, alpha: 1)
            : UIColor(red: 0.678, green: 0.506, blue: 0.180, alpha: 1)
    })

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
    func historyGlassCard() -> some View {
        glassCard(glassTint: HistoryTheme.cardGlassTint)
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
