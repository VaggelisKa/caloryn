import Foundation

enum HistoryEntryWindow {
    static func analyticsStart(
        for range: HistoryRange,
        now: Date,
        calendar: Calendar
    ) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(
            byAdding: .day,
            value: -(range.days * 2 - 1),
            to: today
        ) ?? today
    }

    static func widestAnalyticsStart(now: Date, calendar: Calendar) -> Date {
        HistoryRange.allCases
            .map { analyticsStart(for: $0, now: now, calendar: calendar) }
            .min() ?? calendar.startOfDay(for: now)
    }

    static func recurringPatternStart(
        engine: HistoryRecurringCaloriePatternEngine = HistoryRecurringCaloriePatternEngine(),
        now: Date,
        calendar: Calendar
    ) -> Date {
        engine.evidenceWindow(now: now, calendar: calendar).lowerBound
    }

    static func entries<Entry>(
        _ entries: [Entry],
        newestFirstFrom start: Date,
        date: (Entry) -> Date
    ) -> [Entry] {
        var window: [Entry] = []
        #if DEBUG
        var previousDate: Date?
        #endif

        for entry in entries {
            let entryDate = date(entry)

            #if DEBUG
            if let previousDate {
                precondition(
                    previousDate >= entryDate,
                    "History entries must stay sorted newest-first by date."
                )
            }
            previousDate = entryDate
            #endif

            guard entryDate >= start else { break }
            window.append(entry)
        }

        return window
    }
}
