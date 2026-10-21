import Foundation
import SwiftData

enum FoodLogEntryWindow {
    private static let marginDays = 2

    static func recentStart(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -marginDays, to: calendar.startOfDay(for: now)) ?? .distantPast
    }

    static func loggedSince(_ start: Date) -> Predicate<FoodLogEntry> {
        #Predicate { $0.date >= start }
    }
}
