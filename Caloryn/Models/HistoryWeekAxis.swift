import Foundation

struct HistoryWeekAxis: Equatable {
    static let denseWeekThreshold = 10

    struct Week: Equatable, Identifiable {
        let startDate: Date
        let startText: String
        let isCurrent: Bool
        let showsLabel: Bool

        var id: Date { startDate }

        var label: String? {
            guard showsLabel else { return nil }
            return isCurrent ? "This week" : startText
        }
    }

    let weeks: [Week]

    init(weekStarts: [Date], calendar: Calendar, today: Date) {
        let isDense = weekStarts.count > Self.denseWeekThreshold
        let lastOffset = weekStarts.count - 1
        let currentWeekStart = today.startOfWeek(in: calendar)

        weeks = weekStarts.enumerated().map { offset, start in
            Week(
                startDate: start,
                startText: start.dayMonthFormatted(in: calendar),
                isCurrent: calendar.isDate(start, inSameDayAs: currentWeekStart),
                showsLabel: !isDense || (lastOffset - offset).isMultiple(of: 2)
            )
        }
    }

    var isDense: Bool { weeks.count > Self.denseWeekThreshold }
}
