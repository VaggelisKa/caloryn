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
}

extension HistoryGoalStatus {
    var tint: Color {
        HistoryTheme.color(for: self)
    }
}
