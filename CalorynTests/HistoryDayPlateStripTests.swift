import Foundation
import Testing
@testable import Caloryn

/// History's consistency strip as day plates: how each plate is outlined and labelled, what
/// it is filled with, and how the strip is laid out and spoken for each range.
@Suite("History day plate strip")
struct HistoryDayPlateStripTests {

    // MARK: - One plate

    @Test("given a day over its goal, when drawing its plate, then it is ringed in ink with an ink label")
    func anOverDayIsRinged() {
        let plate = makeStrip([period(calories: 2_800, status: .over)]).plates[0]

        #expect(plate.outline == .over)
        #expect(plate.labelStyle == .emphasized)
        #expect(plate.donut.eatenKcal == 2_800)
        #expect(plate.donut.isOver)
    }

    @Test(
        "given a past day at or under its goal, when drawing its plate, then it has the plain outline",
        arguments: [HistoryGoalStatus.under, .onTrack]
    )
    func anUnderOrOnTrackDayIsPlain(status: HistoryGoalStatus) {
        let plate = makeStrip([period(calories: 1_700, status: status)]).plates[0]

        #expect(plate.outline == .standard)
        #expect(plate.labelStyle == .regular)
        #expect(plate.donut.eatenKcal == 1_700)
        #expect(plate.donut.budgetKcal == 2_000)
        #expect(plate.donut.isOver == false)
    }

    @Test(
        "given today, when drawing its plate, then it is dashed even when already over",
        arguments: [HistoryGoalStatus.under, .over, .notLogged]
    )
    func todayIsDashedWhateverItsStatus(status: HistoryGoalStatus) {
        let plate = makeStrip([period(calories: 2_100, status: status, isCurrent: true)]).plates[0]

        #expect(plate.outline == .current)
        #expect(plate.labelStyle == .current)
    }

    @Test("given a day with nothing logged, when drawing its plate, then the plate is empty")
    func anUnloggedDayIsAnEmptyPlate() {
        let plate = makeStrip([period(calories: 0, status: .notLogged)]).plates[0]

        #expect(plate.donut.eatenKcal == 0)
        #expect(plate.outline == .standard)
    }

    // MARK: - The strip

    @Test("given a mix of days, when spoken, then it is a count per status rather than plate by plate")
    func theStripIsSpokenAsCounts() {
        let strip = makeStrip([
            period(day: 0, calories: 1_500, status: .under),
            period(day: 1, calories: 2_000, status: .onTrack),
            period(day: 2, calories: 2_000, status: .onTrack),
            period(day: 3, calories: 2_800, status: .over),
            period(day: 4, calories: 0, status: .notLogged)
        ])

        #expect(strip.plates.count == 5)
        #expect(
            strip.accessibilityLabel
                == "Goal consistency: 1 under, 2 on track, 1 over, 1 not logged."
        )
        #expect(strip.currentKeyText == "today so far")
    }

    @Test("given weeks, when keying and speaking the strip, then it reads each week's share on track")
    func aWeeklyStripTalksAboutWeeks() {
        let strip = makeStrip(
            [
                week(onTrackDays: 6, loggedDays: 7),
                week(day: 7, onTrackDays: 0, loggedDays: 0, averageCalories: 0)
            ],
            granularity: .week
        )

        #expect(strip.ringKeyText == "few days on track")
        #expect(strip.currentKeyText == "this week so far")
        #expect(
            strip.accessibilityLabel
                == "Weekly goal consistency: 86 percent on track, 7 of 7 days logged; 0 percent on track, 0 of 7 days logged."
        )
    }

    @Test("given days, when keying the ring, then it means over goal")
    func aDailyStripKeysTheRingAsOverGoal() {
        #expect(makeStrip([period(calories: 2_000, status: .onTrack)]).ringKeyText == "over goal")
    }

    // MARK: - One week

    @Test("given a week mostly on track whose one big day lifts the average over goal, when drawing its plate, then it is not ringed")
    func aMostlyOnTrackWeekIsNotRingedForOneBigDay() {
        // Six 2,000 kcal days and one 2,800 kcal Friday: the average, 2,114, is past the
        // 2,100 band, but six of seven days were on track.
        let strip = makeStrip(
            [week(onTrackDays: 6, loggedDays: 7, averageCalories: 2_114)],
            granularity: .week
        )
        let plate = strip.plates[0]

        #expect(strip.statusCounts == [.onTrack: 1])
        #expect(plate.outline == .standard)
        #expect(plate.labelStyle == .regular)
        #expect(plate.donut.eatenKcal == 2_114)
    }

    @Test(
        "given a week's share of logged days on track, when rating it, then it takes the weekly chart's steps",
        arguments: [
            (7, 7, HistoryGoalStatus.onTrack, HistoryDayPlateStrip.Outline.standard),
            (5, 7, .onTrack, .standard),
            (3, 7, .under, .standard),
            (2, 5, .under, .standard),
            (2, 3, .onTrack, .standard),
            (1, 3, .under, .standard),
            (2, 6, .under, .standard),
            (2, 7, .over, .over),
            (0, 5, .over, .over),
            (0, 0, .notLogged, .standard)
        ]
    )
    func aWeekIsRatedByItsShareOnTrack(
        onTrackDays: Int,
        loggedDays: Int,
        status: HistoryGoalStatus,
        outline: HistoryDayPlateStrip.Outline
    ) {
        let strip = makeStrip(
            [week(onTrackDays: onTrackDays, loggedDays: loggedDays, averageCalories: 1_900)],
            granularity: .week
        )

        #expect(strip.statusCounts == [status: 1])
        #expect(strip.plates[0].outline == outline)
        #expect(HistoryGoalStatus.weeklyConsistency(onTrackDays: onTrackDays, loggedDays: loggedDays) == status)
    }

    @Test("given a week rated poorly but eaten under goal on average, when drawing its plate, then it is ringed but not full")
    func aPoorWeekUnderGoalIsRingedButNotFull() {
        let plate = makeStrip(
            [week(onTrackDays: 0, loggedDays: 7, averageCalories: 1_500)],
            granularity: .week
        ).plates[0]

        #expect(plate.outline == .over)
        #expect(plate.donut.isOver == false)
        #expect(plate.donut.remainingKcal == 500)
    }

    @Test("given no columns, when laying out, then there is still one column")
    func theStripAlwaysHasAColumn() {
        #expect(makeStrip([], columnCount: 0).columnCount == 1)
    }

    // MARK: - Fitting the width

    @Test(
        "given a row wide enough, when fitting the plates, then they keep the strip's own size",
        arguments: [(HistoryRange.week, CGFloat(362)), (.month, 362), (.quarter, 362), (.month, 334)]
    )
    func wideRowsKeepThePlateSize(range: HistoryRange, width: CGFloat) {
        let strip = makeRangeStrip(range)

        #expect(strip.plateSize(fittingWidth: width) == strip.plateSize)
    }

    @Test(
        "given a 320pt screen under Display Zoom, when fitting the plates, then every row fits between the margins",
        arguments: [(HistoryRange.week, CGFloat(34)), (.twoWeeks, 34), (.month, 22), (.quarter, 34)]
    )
    func narrowRowsShrinkThePlates(range: HistoryRange, expectedSize: CGFloat) {
        let strip = makeRangeStrip(range)
        let width: CGFloat = 280
        let size = strip.plateSize(fittingWidth: width)
        let rowWidth = size * CGFloat(strip.columnCount)
            + HistoryDayPlateStrip.columnSpacing * CGFloat(strip.columnCount - 1)

        #expect(size == expectedSize)
        #expect(rowWidth <= width)
    }

    @Test("given the width is not measured yet, when fitting the plates, then they keep the strip's own size")
    func anUnmeasuredRowKeepsThePlateSize() {
        let strip = makeRangeStrip(.month)

        #expect(strip.plateSize(fittingWidth: nil) == 28)
    }

    // MARK: - Per range

    @Test(
        "given a day range, when laying out, then a week sits on a row and thirty days take smaller plates",
        arguments: [
            (HistoryRange.week, 7, 7, CGFloat(40)),
            (.twoWeeks, 14, 7, CGFloat(40)),
            (.month, 30, 10, CGFloat(28))
        ]
    )
    func dayRangesLayOutByLength(range: HistoryRange, plates: Int, columns: Int, size: CGFloat) {
        let strip = makeRangeStrip(range)

        #expect(strip.granularity == .day)
        #expect(strip.plates.count == plates)
        #expect(strip.columnCount == columns)
        #expect(strip.plateSize == size)
        #expect(strip.plates.last?.outline == .current)
        #expect(strip.plates.dropLast().allSatisfy { $0.outline == .standard })
    }

    @Test("given thirty days, when labelling the plates, then each carries its day of the month")
    func thirtyDaysAreLabelledByDayOfMonth() {
        let labels = makeRangeStrip(.month).plates.map(\.label)

        #expect(labels.first == "18")
        #expect(labels.last == "17")
    }

    @Test("given ninety days, when laying out, then there is a plate per week numbered from the oldest")
    func ninetyDaysArePlatesPerWeek() {
        let strip = makeRangeStrip(.quarter)

        #expect(strip.granularity == .week)
        #expect(strip.columnCount == 7)
        #expect(strip.plates.first?.label == "W1")
        #expect(strip.plates.last?.label == "W\(strip.plates.count)")
        #expect(strip.plates.last?.outline == .current)
    }

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Saturday 17 October 2026, midday.
    private static let today: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 12)) ?? .now
    }()

    private func period(
        day: Int = 0,
        calories: Double,
        status: HistoryGoalStatus,
        isCurrent: Bool = false
    ) -> HistoryDayPlateStrip.Period {
        HistoryDayPlateStrip.Period(
            start: Self.calendar.date(byAdding: .day, value: day, to: Self.today) ?? Self.today,
            label: "D\(day)",
            calories: calories,
            target: 2_000,
            status: status,
            isCurrent: isCurrent
        )
    }

    private func week(
        day: Int = 0,
        onTrackDays: Int,
        loggedDays: Int,
        averageCalories: Double = 2_000,
        isCurrent: Bool = false
    ) -> HistoryDayPlateStrip.Period {
        HistoryDayPlateStrip.Period(
            weekStart: Self.calendar.date(byAdding: .day, value: day, to: Self.today) ?? Self.today,
            label: "W\(day / 7 + 1)",
            averageCalories: averageCalories,
            target: 2_000,
            consistency: HistoryDayPlateStrip.WeekConsistency(
                onTrackDays: onTrackDays,
                loggedDays: loggedDays,
                totalDays: 7
            ),
            isCurrent: isCurrent
        )
    }

    private func makeStrip(
        _ periods: [HistoryDayPlateStrip.Period],
        granularity: HistoryDayPlateStrip.Granularity = .day,
        columnCount: Int = 7
    ) -> HistoryDayPlateStrip {
        HistoryDayPlateStrip(
            periods: periods,
            granularity: granularity,
            columnCount: columnCount,
            plateSize: 40
        )
    }

    private func makeRangeStrip(_ range: HistoryRange) -> HistoryDayPlateStrip {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: range,
            endDate: Self.today,
            calendar: Self.calendar
        )
        return HistoryDayPlateStrip(
            range: range,
            summary: analytics.current,
            today: Self.calendar.startOfDay(for: Self.today)
        )
    }
}
