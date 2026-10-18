import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History entry window")
struct HistoryEntryWindowTests {
    private struct Entry: Equatable {
        let name: String
        let date: Date
    }

    nonisolated private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    nonisolated private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        calendar: Calendar = utcCalendar()
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    @Test(
        "given a range, when asking for its analytics start, then the window spans twice the range so the previous period is not empty",
        arguments: [
            (HistoryRange.week, 13),
            (HistoryRange.twoWeeks, 27),
            (HistoryRange.month, 59),
            (HistoryRange.quarter, 179)
        ]
    )
    func analyticsStartSpansTwiceTheRange(range: HistoryRange, daysBack: Int) {
        let calendar = Self.utcCalendar()
        let now = Self.date(2026, 6, 15, hour: 9, calendar: calendar)

        let start = HistoryEntryWindow.analyticsStart(
            for: range,
            now: now,
            calendar: calendar
        )

        let expected = calendar.date(
            byAdding: .day,
            value: -daysBack,
            to: calendar.startOfDay(for: now)
        )!
        #expect(start == expected)
        #expect(start == calendar.startOfDay(for: start))
    }

    @Test(
        "given a range, when analytics reports its periods, then the earliest day it reads is exactly the window start",
        arguments: [HistoryRange.week, .twoWeeks, .month, .quarter]
    )
    func analyticsReadsExactlyTheWindowTheFetchProvides(range: HistoryRange) {
        let calendar = Self.utcCalendar()
        let now = Self.date(2026, 6, 15, hour: 9, calendar: calendar)

        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: range,
            endDate: now,
            calendar: calendar
        )

        let start = HistoryEntryWindow.analyticsStart(
            for: range,
            now: now,
            calendar: calendar
        )
        #expect(analytics.previous.days.first?.date == start)
        #expect(analytics.previous.days.count + analytics.current.days.count == range.days * 2)
        #expect(analytics.current.days.last?.date == calendar.startOfDay(for: now))
    }

    @Test("given a window that spans a daylight-saving change, when asking for its start, then it is still a whole number of calendar days back")
    func windowCountsCalendarDaysAcrossADaylightSavingChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Copenhagen") ?? .gmt

        let now = Self.date(2026, 4, 2, hour: 10, calendar: calendar)

        let start = HistoryEntryWindow.analyticsStart(
            for: .week,
            now: now,
            calendar: calendar
        )

        #expect(start == Self.date(2026, 3, 20, hour: 0, calendar: calendar))
        #expect(start == calendar.startOfDay(for: start))
    }

    @Test("given every selectable range, when asking for the widest start, then no range reaches further back than it")
    func widestStartCoversEveryRange() {
        let calendar = Self.utcCalendar()
        let now = Self.date(2026, 6, 15, hour: 9, calendar: calendar)

        let widest = HistoryEntryWindow.widestAnalyticsStart(now: now, calendar: calendar)

        for range in HistoryRange.allCases {
            let start = HistoryEntryWindow.analyticsStart(
                for: range,
                now: now,
                calendar: calendar
            )
            #expect(widest <= start)
        }
        #expect(
            widest == HistoryEntryWindow.analyticsStart(
                for: .quarter,
                now: now,
                calendar: calendar
            )
        )
    }

    @Test("given the recurring-pattern engine, when asking where its evidence starts, then the window start is the engine's own lower bound")
    func recurringPatternStartComesFromTheEngine() {
        let calendar = Self.utcCalendar()
        let now = Self.date(2026, 6, 15, hour: 9, calendar: calendar)
        let engine = HistoryRecurringCaloriePatternEngine()

        let start = HistoryEntryWindow.recurringPatternStart(
            engine: engine,
            now: now,
            calendar: calendar
        )

        #expect(start == engine.evidenceWindow(now: now, calendar: calendar).lowerBound)
    }

    @Test("given the widest analytics fetch, when the recurring pattern needs evidence, then that evidence is already inside the fetched window")
    func widestFetchAlreadyCoversTheRecurringPatternEvidence() {
        let calendar = Self.utcCalendar()
        let now = Self.date(2026, 6, 15, hour: 9, calendar: calendar)

        let widest = HistoryEntryWindow.widestAnalyticsStart(now: now, calendar: calendar)
        let patternStart = HistoryEntryWindow.recurringPatternStart(
            now: now,
            calendar: calendar
        )

        #expect(widest <= patternStart)
    }

    @Test("given a newest-first log, when selecting from a start, then entries on or after it are kept and older ones are dropped")
    func selectionKeepsEntriesOnOrAfterTheStart() {
        let start = Self.date(2026, 6, 10, hour: 0)
        let entries = [
            Entry(name: "today", date: Self.date(2026, 6, 12)),
            Entry(name: "boundary-noon", date: Self.date(2026, 6, 10)),
            Entry(name: "boundary-midnight", date: start),
            Entry(name: "just-before", date: start.addingTimeInterval(-1)),
            Entry(name: "much-older", date: Self.date(2026, 5, 1))
        ]

        let window = HistoryEntryWindow.entries(
            entries,
            newestFirstFrom: start,
            date: \.date
        )

        #expect(window.map(\.name) == ["today", "boundary-noon", "boundary-midnight"])
    }

    @Test("given a log that continues past the window, when selecting from a start, then the scan stops at the first older entry")
    func selectionStopsAtTheFirstEntryOutsideTheWindow() {
        let start = Self.date(2026, 6, 10, hour: 0)
        var visited: [String] = []
        let entries = [
            Entry(name: "in-1", date: Self.date(2026, 6, 12)),
            Entry(name: "in-2", date: Self.date(2026, 6, 11)),
            Entry(name: "out-1", date: Self.date(2026, 6, 1)),
            Entry(name: "out-2", date: Self.date(2026, 5, 20))
        ]

        let window = HistoryEntryWindow.entries(entries, newestFirstFrom: start) { entry in
            visited.append(entry.name)
            return entry.date
        }

        #expect(window.map(\.name) == ["in-1", "in-2"])
        #expect(visited == ["in-1", "in-2", "out-1"])
    }

    @Test("given an empty log, when selecting from a start, then nothing is selected")
    func selectionFromAnEmptyLogIsEmpty() {
        let window = HistoryEntryWindow.entries(
            [Entry](),
            newestFirstFrom: Self.date(2026, 6, 10),
            date: \.date
        )

        #expect(window.isEmpty)
    }

    @Test("given a log entirely inside the window, when selecting from a start, then every entry is kept in log order")
    func selectionKeepsAWhollyInsideLogInOrder() {
        let entries = [
            Entry(name: "newest", date: Self.date(2026, 6, 12)),
            Entry(name: "middle", date: Self.date(2026, 6, 11)),
            Entry(name: "oldest", date: Self.date(2026, 6, 10))
        ]

        let window = HistoryEntryWindow.entries(
            entries,
            newestFirstFrom: Self.date(2026, 6, 1),
            date: \.date
        )

        #expect(window.map(\.name) == entries.map(\.name))
    }

    @Test("given a start after everything logged, when selecting, then nothing is selected")
    func selectionFromAStartAfterTheLogIsEmpty() {
        let entries = [
            Entry(name: "old", date: Self.date(2026, 5, 1)),
            Entry(name: "older", date: Self.date(2026, 4, 1))
        ]

        let window = HistoryEntryWindow.entries(
            entries,
            newestFirstFrom: Self.date(2026, 6, 1),
            date: \.date
        )

        #expect(window.isEmpty)
    }
}
