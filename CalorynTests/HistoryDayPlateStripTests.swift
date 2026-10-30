import Foundation
import Testing
@testable import Caloryn

@Suite("History day plate strip")
@MainActor
struct HistoryDayPlateStripTests {
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

    @Test("given weeks, when keying and speaking the strip, then it reads each week as its plate says it")
    func aWeeklyStripTalksAboutWeeks() {
        let strip = makeStrip(
            [
                week(onTrackDays: 6, loggedDays: 7, averageCalories: 2_400),
                week(day: 7, onTrackDays: 0, loggedDays: 0, averageCalories: 0)
            ],
            granularity: .week
        )

        #expect(strip.ringKeyText == "avg over goal")
        #expect(strip.currentKeyText == "this week so far")
        #expect(
            strip.accessibilityLabel
                == "Weekly goal consistency: W1, 6 of 7 days on track, average over goal; W2, 0 of 7 days on track."
        )
    }

    @Test("given days, when keying the ring, then it means over goal")
    func aDailyStripKeysTheRingAsOverGoal() {
        #expect(makeStrip([period(calories: 2_000, status: .onTrack)]).ringKeyText == "over goal")
    }

    @Test("given days, when drawing their plates, then none carries a week's caption")
    func dayPlatesHaveNoWeekCaption() {
        let plate = makeStrip([period(calories: 2_800, status: .over)]).plates[0]

        #expect(plate.consistencyText == nil)
        #expect(plate.overGoalText == nil)
    }

    @Test(
        "given a week's days on track, when captioning its plate, then it counts them out of the week's days",
        arguments: [(6, 7, 7, "6/7 on track"), (2, 5, 7, "2/7 on track"), (0, 0, 7, "0/7 on track"), (3, 3, 3, "3/3 on track")]
    )
    func aWeekIsCaptionedByItsDaysOnTrack(onTrackDays: Int, loggedDays: Int, totalDays: Int, text: String) {
        let plate = makeStrip(
            [week(onTrackDays: onTrackDays, loggedDays: loggedDays, totalDays: totalDays, averageCalories: 1_900)],
            granularity: .week
        ).plates[0]

        #expect(plate.consistencyText == text)
    }

    @Test("given a week mostly on track whose one big day lifts the average over goal, when drawing its plate, then it is ringed for its average")
    func aMostlyOnTrackWeekOverOnAverageIsRinged() {
        let plate = makeStrip(
            [week(onTrackDays: 6, loggedDays: 7, averageCalories: 2_114)],
            granularity: .week
        ).plates[0]

        #expect(plate.outline == .over)
        #expect(plate.labelStyle == .emphasized)
        #expect(plate.consistencyText == "6/7 on track")
        #expect(plate.overGoalText == "avg over goal")
        #expect(plate.donut.eatenKcal == 2_114)
        #expect(plate.donut.isOver)
    }

    @Test(
        "given a week whose average is within or under its goal band, when drawing its plate, then it is not ringed however few days were on track",
        arguments: [(0, 7, 1_500.0), (2, 7, 1_900.0), (1, 7, 2_100.0)]
    )
    func aWeekNotOverOnAverageIsNotRinged(onTrackDays: Int, loggedDays: Int, averageCalories: Double) {
        let plate = makeStrip(
            [week(onTrackDays: onTrackDays, loggedDays: loggedDays, averageCalories: averageCalories)],
            granularity: .week
        ).plates[0]

        #expect(plate.outline == .standard)
        #expect(plate.labelStyle == .regular)
        #expect(plate.overGoalText == nil)
    }

    @Test("given this week already over on average, when drawing its plate, then it is dashed and not yet called over")
    func theCurrentWeekIsDashedEvenWhenOver() {
        let strip = makeStrip(
            [week(onTrackDays: 1, loggedDays: 3, totalDays: 3, averageCalories: 2_600, isCurrent: true)],
            granularity: .week
        )
        let plate = strip.plates[0]

        #expect(plate.outline == .current)
        #expect(plate.consistencyText == "1/3 on track")
        #expect(plate.overGoalText == nil)
        #expect(strip.accessibilityLabel == "Weekly goal consistency: W1, 1 of 3 days on track.")
    }

    @Test("given a week with nothing logged, when drawing its plate, then the plate is empty and not ringed")
    func anUnloggedWeekIsAnEmptyPlate() {
        let plate = makeStrip(
            [week(onTrackDays: 0, loggedDays: 0, averageCalories: 0)],
            granularity: .week
        ).plates[0]

        #expect(plate.donut.eatenKcal == 0)
        #expect(plate.outline == .standard)
        #expect(plate.consistencyText == "0/7 on track")
    }

    @Test(
        "given a week's share of logged days on track, when rating it for the weekly chart, then it takes the day steps",
        arguments: [
            (7, 7, HistoryGoalStatus.onTrack),
            (5, 7, .onTrack),
            (3, 7, .under),
            (2, 5, .under),
            (2, 3, .onTrack),
            (1, 3, .under),
            (2, 6, .under),
            (2, 7, .over),
            (0, 5, .over),
            (0, 0, .notLogged)
        ]
    )
    func aWeekIsRatedForTheChartByItsShareOnTrack(
        onTrackDays: Int,
        loggedDays: Int,
        status: HistoryGoalStatus
    ) {
        #expect(HistoryGoalStatus.weeklyConsistency(onTrackDays: onTrackDays, loggedDays: loggedDays) == status)
    }

    @Test("given no columns, when laying out, then there is still one column")
    func theStripAlwaysHasAColumn() {
        #expect(makeStrip([], columnCount: 0).columnCount == 1)
    }

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

    @Test("given ninety days ending on a Saturday, when captioning the weeks, then this week counts only its days so far")
    func ninetyDaysCountEachWeekInItsOwnDays() {
        let captions = makeRangeStrip(.quarter).plates.map(\.consistencyText)

        #expect(captions.count == 13)
        #expect(captions.first == "0/7 on track")
        #expect(captions.last == "0/6 on track")
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_GB")
        calendar.firstWeekday = 2
        return calendar
    }()

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
        totalDays: Int = 7,
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
                totalDays: totalDays
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
