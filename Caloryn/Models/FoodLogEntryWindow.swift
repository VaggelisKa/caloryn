import Foundation
import SwiftData

enum FoodLogEntryWindow {
    private static let marginDays = 2

    static func recentStart(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -marginDays, to: calendar.startOfDay(for: now)) ?? .distantPast
    }

    static func days(around day: Date, calendar: Calendar) -> Range<Date> {
        let dayStart = calendar.startOfDay(for: day)
        let start = calendar.date(byAdding: .day, value: -marginDays, to: dayStart) ?? .distantPast
        let end = calendar.date(byAdding: .day, value: marginDays, to: dayStart) ?? .distantFuture
        return start..<end
    }

    static func loggedSince(_ start: Date) -> Predicate<FoodLogEntry> {
        #Predicate { $0.date >= start }
    }

    static func logged(in window: Range<Date>) -> Predicate<FoodLogEntry> {
        let start = window.lowerBound
        let end = window.upperBound
        return #Predicate { $0.date >= start && $0.date < end }
    }
}
