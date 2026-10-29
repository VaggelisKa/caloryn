import CoreGraphics
import Foundation

struct HistoryWeeklyConsistencyChart: Equatable {
    static let denseWeekThreshold = 10

    struct Tally: Equatable {
        let startDate: Date
        let onTrackDays: Int
        let loggedDays: Int
    }

    struct Week: Equatable, Identifiable {
        let index: Int
        let startDate: Date
        let onTrackDays: Int
        let loggedDays: Int
        let startText: String
        let isCurrent: Bool
        let showsAxisLabel: Bool

        var id: Date { startDate }

        var onTrackPercentage: Double {
            guard loggedDays > 0 else { return 0 }
            return min(100, max(0, Double(onTrackDays) / Double(loggedDays) * 100))
        }

        var axisLabel: String? {
            guard showsAxisLabel else { return nil }
            return isCurrent ? "This week" : startText
        }

        var countText: String {
            "\(onTrackDays)/\(loggedDays)"
        }

        var accessibilityLabel: String {
            guard loggedDays > 0 else { return "Week of \(startText), no days logged" }
            let dayWord = loggedDays == 1 ? "day" : "days"
            return "Week of \(startText), \(onTrackDays) of \(loggedDays) logged \(dayWord) on track"
        }
    }

    let axis: HistoryChartIndexAxis
    let weeks: [Week]

    init(tallies: [Tally], calendar: Calendar, today: Date) {
        axis = HistoryChartIndexAxis(slotCount: tallies.count)
        let isDense = tallies.count > Self.denseWeekThreshold
        let lastOffset = tallies.count - 1
        let currentWeekStart = today.startOfWeek(in: calendar)

        weeks = tallies.enumerated().map { offset, tally in
            Week(
                index: offset,
                startDate: tally.startDate,
                onTrackDays: tally.onTrackDays,
                loggedDays: tally.loggedDays,
                startText: tally.startDate.dayMonthFormatted(in: calendar),
                isCurrent: calendar.isDate(tally.startDate, inSameDayAs: currentWeekStart),
                showsAxisLabel: !isDense || (lastOffset - offset).isMultiple(of: 2)
            )
        }
    }

    var weekCount: Int { axis.slotCount }

    var isDense: Bool { weekCount > Self.denseWeekThreshold }

    var barWidth: CGFloat { isDense ? 12 : 16 }

    var showsCounts: Bool { !isDense }

    var xAxisDomain: ClosedRange<Double> { axis.domain }

    var indices: [Double] { axis.indices }

    static func label(forOffset offset: Int) -> String {
        "W\(offset + 1)"
    }

    func label(forChartValue value: Double) -> String? {
        guard let slot = axis.slot(for: value) else { return nil }
        return weeks[slot].axisLabel
    }

    static func accessibilityLabel(loggedDayCount: Int, totalDayCount: Int) -> String {
        "Weekly consistency of on-track days. \(loggedDayCount) of \(totalDayCount) days logged."
    }
}
