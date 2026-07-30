import Foundation

/// How far back History has to read the food log, and which part of an
/// already-sorted log falls inside that window.
///
/// The selection rule is generic over the entry so it can be exercised without a
/// SwiftData store: it takes the one fact it needs — the entry's date — as an
/// accessor rather than reaching into a `FoodLogEntry`. Every date rule takes its
/// `Calendar`, so a window can be asserted under a fixed calendar rather than
/// whichever one the test host happens to run in.
enum HistoryEntryWindow {
    /// The earliest day `HistoryAnalytics` reads for `range`.
    ///
    /// `HistoryAnalytics` reports a current period of `range.days` ending today
    /// *and* a previous period of the same length ending the day before that, so
    /// the two together span `range.days * 2` days: today back through
    /// `range.days * 2 - 1` days ago. Fetching a day less silently empties the
    /// previous period, and every comparison drawn from it reads as "no change"
    /// rather than as missing. `HistoryEntryWindowTests` pins this against what
    /// `HistoryAnalytics` actually reads, so the two cannot drift apart.
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

    /// The earliest day *any* range could ask for.
    ///
    /// History fetches this once and re-slices it in memory, so switching the
    /// range picker never goes back to the store. Taken as the minimum over every
    /// range rather than naming the longest one, so adding a range cannot leave
    /// the fetch short of it.
    static func widestAnalyticsStart(now: Date, calendar: Calendar) -> Date {
        HistoryRange.allCases
            .map { analyticsStart(for: $0, now: now, calendar: calendar) }
            .min() ?? calendar.startOfDay(for: now)
    }

    /// The earliest day the recurring-calorie observation reads.
    ///
    /// Asked of the engine rather than recomputed from its policy: the window is
    /// the engine's own definition (it ends yesterday, not today), and a second
    /// derivation of it would be free to disagree.
    static func recurringPatternStart(
        engine: HistoryRecurringCaloriePatternEngine = HistoryRecurringCaloriePatternEngine(),
        now: Date,
        calendar: Calendar
    ) -> Date {
        engine.evidenceWindow(now: now, calendar: calendar).lowerBound
    }

    /// Everything logged on or after `start`, from a log already sorted
    /// newest-first.
    ///
    /// The scan stops at the first entry older than `start` instead of filtering
    /// the whole log: History's query is bounded only by how long the person has
    /// been logging, and everything past the window is a row the screen will
    /// never read. That early exit is only correct while the log is sorted, so in
    /// DEBUG the ordering is checked as it goes.
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
