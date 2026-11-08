import Foundation

struct HistoryAverages: Equatable {
    enum Grouping: String, CaseIterable, Identifiable {
        case week
        case month

        var id: String { rawValue }

        var title: String {
            switch self {
            case .week:
                "Weekly"
            case .month:
                "Monthly"
            }
        }

        var blockLength: Int {
            switch self {
            case .week:
                7
            case .month:
                30
            }
        }
    }

    struct Day: Equatable {
        let date: Date
        let calories: Double
        let target: Int
        let isLogged: Bool
    }

    struct Period: Equatable, Identifiable {
        let startDate: Date
        let title: String
        let loggedDayCount: Int
        let averageCalories: Double
        let target: Int

        var id: Date { startDate }

        var roundedAverage: Int { averageCalories.roundedCalories }

        var status: HistoryGoalStatus {
            HistoryGoalStatus.calorieStatus(
                calories: averageCalories,
                loggedCount: loggedDayCount,
                targetCalories: target
            )
        }

        var valueText: String { roundedAverage.formatted() }

        var unitText: String { " kcal a day" }

        var gapText: String { "\(gap) goal" }

        var accessibilityLabel: String {
            "\(title), \(valueText) kcal a day on average, \(gapText) of \(target.formatted())"
        }

        private var gap: String {
            let difference = roundedAverage - target
            if difference < 0 { return "\(difference.magnitude.formatted()) under" }
            if difference > 0 { return "\(difference.formatted()) over" }
            return "Right on"
        }
    }

    struct Series: Equatable {
        let periods: [Period]

        private var scale: Double {
            let largest = periods
                .map { max($0.averageCalories, Double($0.target)) }
                .max() ?? 0
            return largest.isFinite && largest > 0 ? largest : 1
        }

        func fillFraction(for period: Period) -> Double {
            Self.clamped(period.averageCalories / scale)
        }

        func goalFraction(for period: Period) -> Double {
            Self.clamped(Double(period.target) / scale)
        }

        private static func clamped(_ fraction: Double) -> Double {
            guard fraction.isFinite else { return 0 }
            return min(1, max(0, fraction))
        }
    }

    let groupings: [Grouping]
    private let seriesByGrouping: [Grouping: Series]

    init(days: [Day], calendar: Calendar) {
        let chronological = days.sorted { $0.date < $1.date }
        let seriesByGrouping = Dictionary(
            uniqueKeysWithValues: Grouping.allCases.map { grouping in
                (grouping, Self.series(of: chronological, blockLength: grouping.blockLength, calendar: calendar))
            }
            .filter { $0.1.periods.count >= 2 }
        )

        groupings = Grouping.allCases.filter { seriesByGrouping[$0] != nil }
        self.seriesByGrouping = seriesByGrouping
    }

    var isEmpty: Bool { groupings.isEmpty }

    func resolved(_ grouping: Grouping) -> Grouping {
        groupings.contains(grouping) ? grouping : groupings.first ?? .week
    }

    func series(for grouping: Grouping) -> Series {
        seriesByGrouping[resolved(grouping)] ?? Series(periods: [])
    }

    private static func series(of days: [Day], blockLength: Int, calendar: Calendar) -> Series {
        var periods: [Period] = []
        var end = days.endIndex

        while end > days.startIndex {
            let start = max(days.startIndex, end - blockLength)
            let block = Array(days[start..<end])
            let title = title(of: block, isNewest: end == days.endIndex, blockLength: blockLength, calendar: calendar)
            if let period = period(of: block, title: title) {
                periods.append(period)
            }
            end = start
        }

        return Series(periods: periods)
    }

    private static func period(of block: [Day], title: String) -> Period? {
        let logged = block.filter(\.isLogged)
        guard let first = block.first, !logged.isEmpty else { return nil }

        return Period(
            startDate: first.date,
            title: title,
            loggedDayCount: logged.count,
            averageCalories: mean(of: logged.map(\.calories)),
            target: mean(of: logged.map { Double($0.target) }).roundedCalories
        )
    }

    private static func mean(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func title(of block: [Day], isNewest: Bool, blockLength: Int, calendar: Calendar) -> String {
        if isNewest, block.count == blockLength {
            return "Last \(blockLength) days"
        }

        guard let first = block.first?.date, let last = block.last?.date else { return "" }
        let span = dateSpan(from: first, to: last, calendar: calendar)
        guard block.count < blockLength else { return span }
        return "\(span) (\(block.count) \(block.count == 1 ? "day" : "days"))"
    }

    private static func dateSpan(from first: Date, to last: Date, calendar: Calendar) -> String {
        if calendar.isDate(first, inSameDayAs: last) {
            return first.dayMonthFormatted(in: calendar)
        }

        let sameYear = calendar.isDate(first, equalTo: last, toGranularity: .year)
        let sameMonth = calendar.isDate(first, equalTo: last, toGranularity: .month)
        let lastText = last.formatted(pattern: sameYear ? "d MMM" : "d MMM yyyy", in: calendar)
        let firstPattern = sameMonth ? "d" : (sameYear ? "d MMM" : "d MMM yyyy")
        return "\(first.formatted(pattern: firstPattern, in: calendar)) – \(lastText)"
    }
}
