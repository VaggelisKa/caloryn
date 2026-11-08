import Foundation
import Testing
@testable import Caloryn

@Suite("History week axis")
@MainActor
struct HistoryWeekAxisTests {
    @Test("given the dense threshold exactly, when laying out the axis, then it is not yet dense")
    func theThresholdItselfIsNotDense() {
        #expect(makeAxis(weekCount: 10).isDense == false)
        #expect(makeAxis(weekCount: 11).isDense)
    }

    @Test("given five weeks ending with today's, when labelling the axis, then each week shows its start date and the last reads This week")
    func labelsAreStartDatesEndingInThisWeek() {
        let axis = makeAxis(weekCount: 5)

        #expect(axis.weeks.map(\.label) == ["28 Sep", "5 Oct", "12 Oct", "19 Oct", "This week"])
    }

    @Test("given a period that ended before this week, when labelling the axis, then no week reads This week")
    func aPastPeriodHasNoCurrentWeek() {
        let axis = makeAxis(weekCount: 2, today: date(2026, 11, 20))

        #expect(axis.weeks.map(\.label) == ["19 Oct", "26 Oct"])
        #expect(axis.weeks.allSatisfy { !$0.isCurrent })
    }

    @Test("given thirteen weeks, when labelling the axis, then every other week is labelled counting back from this week")
    func aDenseAxisLabelsEveryOtherWeek() {
        let axis = makeAxis(weekCount: 13)
        let labelled = axis.weeks.indices.filter { axis.weeks[$0].label != nil }

        #expect(labelled == [0, 2, 4, 6, 8, 10, 12])
        #expect(axis.weeks.last?.label == "This week")
        #expect(axis.weeks[1].label == nil)
    }

    @Test("given an even dense week count, when labelling the axis, then this week stays labelled and the oldest is skipped")
    func anEvenDenseAxisStillLabelsThisWeek() {
        let axis = makeAxis(weekCount: 12)

        #expect(axis.weeks.first?.label == nil)
        #expect(axis.weeks.last?.label == "This week")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private func makeAxis(weekCount: Int, today: Date? = nil) -> HistoryWeekAxis {
        let lastWeekStart = date(2026, 10, 26)
        let starts = (0 ..< weekCount).map { offset in
            calendar.date(byAdding: .day, value: -7 * (weekCount - 1 - offset), to: lastWeekStart) ?? lastWeekStart
        }
        return HistoryWeekAxis(weekStarts: starts, calendar: calendar, today: today ?? date(2026, 10, 29))
    }
}
