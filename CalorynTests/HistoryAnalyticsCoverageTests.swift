import Foundation
import Testing
@testable import Caloryn

@MainActor
@Suite("History analytics coverage")
struct HistoryAnalyticsCoverageTests {
    @Test(
        "given each range, when naming it, then its id is its raw value and its label its day count",
        arguments: [
            (HistoryRange.week, "week", "7 Days", 7),
            (.twoWeeks, "twoWeeks", "14 Days", 14),
            (.month, "month", "30 Days", 30),
            (.quarter, "quarter", "90 Days", 90)
        ]
    )
    func rangeIdentityAndLabel(range: HistoryRange, id: String, label: String, days: Int) {
        #expect(range.id == id)
        #expect(range.label == label)
        #expect(range.days == days)
    }

    @Test(
        "given each goal status, when naming it, then its id is its raw value and its label title case",
        arguments: [
            (HistoryGoalStatus.under, "under", "Under"),
            (.onTrack, "onTrack", "On Track"),
            (.over, "over", "Over"),
            (.notLogged, "notLogged", "Not Logged")
        ]
    )
    func goalStatusIdentityAndLabel(status: HistoryGoalStatus, id: String, label: String) {
        #expect(status.id == id)
        #expect(status.label == label)
    }

    @Test(
        "given each coverage level, when naming it, then it reads as a confidence",
        arguments: [
            (HistoryCoverageLevel.high, "High confidence"),
            (.medium, "Medium confidence"),
            (.low, "Low confidence")
        ]
    )
    func coverageLevelLabel(level: HistoryCoverageLevel, label: String) {
        #expect(level.label == label)
    }

    @Test("given a day with nothing logged, when rating it, then it is not logged whatever the calories say")
    func nothingLoggedIsNotLoggedEvenWithCalories() {
        #expect(HistoryGoalStatus.calorieStatus(calories: 2_500, loggedCount: 0, targetCalories: 2_000) == .notLogged)
    }

    @Test(
        "given a logged day against no usable target, when rating it, then it reads as on track rather than dividing by it",
        arguments: [0, -250]
    )
    func noUsableTargetIsOnTrack(target: Int) {
        #expect(HistoryGoalStatus.calorieStatus(calories: 3_000, loggedCount: 1, targetCalories: target) == .onTrack)
        #expect(HistoryGoalStatus.calorieStatus(calories: 0, loggedCount: 1, targetCalories: target) == .onTrack)
    }

    @Test(
        "given calories around the five percent band, when rating the day, then the band edges are on track",
        arguments: [
            (1_899.99, HistoryGoalStatus.under),
            (1_900.0, .onTrack),
            (2_000.0, .onTrack),
            (2_100.0, .onTrack),
            (2_100.01, .over)
        ]
    )
    func bandEdgesAreOnTrack(calories: Double, expected: HistoryGoalStatus) {
        #expect(HistoryGoalStatus.calorieStatus(calories: calories, loggedCount: 1, targetCalories: 2_000) == expected)
    }

    @Test(
        "given a share of days logged, when grading coverage, then 80 percent is high and 50 percent medium",
        arguments: [
            (10, 10, 1.0, HistoryCoverageLevel.high),
            (8, 10, 0.8, .high),
            (7, 10, 0.7, .medium),
            (5, 10, 0.5, .medium),
            (4, 10, 0.4, .low),
            (0, 10, 0.0, .low)
        ] as [(Int, Int, Double, HistoryCoverageLevel)]
    )
    func coverageLevelThresholds(logged: Int, total: Int, ratio: Double, expected: HistoryCoverageLevel) {
        let dates = Self.days(from: Self.date(2026, 1, 5), count: total)
        let entries = dates.prefix(logged).map { entry(at: $0, calories: 2_000) }

        let summary = makeSummary(dates: dates, entries: entries)

        #expect(summary.totalDayCount == total)
        #expect(summary.loggedDayCount == logged)
        #expect(summary.coverageRatio == ratio)
        #expect(summary.coverageLevel == expected)
    }

    @Test("given a period with no days at all, when summarising it, then every ratio and average is zero rather than a division by zero")
    func aPeriodWithNoDaysHasZeroRatios() {
        let summary = makeSummary(dates: [], fallbackTarget: 1_850)

        #expect(summary.totalDayCount == 0)
        #expect(summary.coverageRatio == 0)
        #expect(summary.coverageLevel == .low)
        #expect(summary.averageCaloriesPerLoggedDay == 0)
        #expect(summary.loggedDayTargetTotal == 0)
        #expect(summary.dailyCalorieTarget == 1_850)
        #expect(summary.averageTargetPerLoggedDay == 1_850)
        #expect(summary.weeklyRollups.isEmpty)
        #expect(summary.hasEstimatedTargets == false)
    }

    @Test("given a period with no days and an absurd fallback target, when summarising it, then the reference target is clamped into the calorie domain")
    func anEmptyPeriodClampsItsFallbackTarget() {
        let summary = makeSummary(dates: [], fallbackTarget: Int.max)

        #expect(summary.dailyCalorieTarget == CalorieDomain.maximum)
    }

    @Test("given a range with nothing logged, when summarising it, then averages are zero and the average goal falls back to the period's reference")
    func anUnloggedRangeFallsBackToTheReferenceTarget() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.date(2026, 1, 30),
            calendar: Self.newYork
        )

        #expect(analytics.current.averageCaloriesPerLoggedDay == 0)
        #expect(analytics.current.averageTargetPerLoggedDay == 2_000)
        #expect(analytics.current.loggedDayTargetTotal == 0)
        #expect(analytics.current.coverageRatio == 0)
        #expect(analytics.current.count(for: .notLogged) == 7)
        #expect(analytics.goalComparison.onTrackDayDelta == 0)

        #expect(analytics.macroPatterns.map(\.nutrient) == [.protein, .carbs, .fat])
        for pattern in analytics.macroPatterns {
            #expect(pattern.current.loggedDays == 0)
            #expect(pattern.current.hitDays == 0)
            #expect(pattern.current.averageValue == 0)
            #expect(pattern.averageValueDelta == 0)
        }
    }

    @Test("given a week with no days, when rolling it up, then its ratios and goal are zero rather than a division by zero")
    func anEmptyWeekHasZeroRatios() {
        let week = HistoryWeekSummary(startDate: Self.date(2026, 1, 5), days: [])

        #expect(week.totalDays == 0)
        #expect(week.loggedDays == 0)
        #expect(week.onTrackDays == 0)
        #expect(week.onTrackRatio == 0)
        #expect(week.coverageRatio == 0)
        #expect(week.averageCaloriesPerLoggedDay == 0)
        #expect(week.targetPerLoggedDay == 0)
        #expect(week.hasEstimatedTargets == false)
        #expect(week.id == Self.date(2026, 1, 5))
    }

    @Test("given a week with nothing logged, when rolling it up, then its goal is the average of every day's own goal")
    func anUnloggedWeekAveragesEveryDaysGoal() throws {
        let monday = Self.date(2026, 1, 5)
        let dates = Self.days(from: monday, count: 7)
        let summary = makeSummary(
            dates: dates,
            fallbackTarget: 2_000,
            snapshotTargets: [dates[0]: 1_800, dates[1]: 1_801]
        )

        let week = try #require(summary.weeklyRollups.first)
        #expect(week.targetPerLoggedDay == 1_801)
        #expect(week.loggedDays == 0)
        #expect(week.onTrackRatio == 0)
    }

    @Test("given an unlogged week whose days have no saved goal, when rolling it up, then it is not flagged as using estimated targets")
    func anUnloggedWeekIsNotFlaggedAsEstimated() throws {
        let monday = Self.date(2026, 1, 5)
        let summary = makeSummary(dates: Self.days(from: monday, count: 7))

        let week = try #require(summary.weeklyRollups.first)

        #expect(week.hasEstimatedTargets == false)
        #expect(summary.hasEstimatedTargets == false)
    }

    @Test("given two logged days with goals half a calorie apart on average, when averaging the goal, then it rounds half up")
    func theAverageGoalRoundsHalfUp() {
        let monday = Self.date(2026, 1, 5)
        let dates = Self.days(from: monday, count: 7)
        let summary = makeSummary(
            dates: dates,
            entries: [entry(at: dates[0], calories: 1_000), entry(at: dates[1], calories: 1_001)],
            fallbackTarget: 2_000,
            snapshotTargets: [dates[0]: 2_000, dates[1]: 2_001]
        )

        #expect(summary.loggedDayTargetTotal == 4_001)
        #expect(summary.averageTargetPerLoggedDay == 2_001)
        #expect(summary.averageCaloriesPerLoggedDay == 1_000.5)
        #expect(summary.dailyCalorieTarget == 2_000)
    }

    @Test("given logged and unlogged days, when averaging calories, then only the logged days are divided by")
    func averagesDivideByLoggedDaysOnly() {
        let dates = Self.days(from: Self.date(2026, 1, 5), count: 7)
        let summary = makeSummary(
            dates: dates,
            entries: [
                entry(at: dates[0], calories: 1_500),
                entry(at: dates[3], calories: 2_500),
                entry(at: dates[3], calories: 300)
            ]
        )

        #expect(summary.loggedDayCount == 2)
        #expect(summary.averageCaloriesPerLoggedDay == 2_150)
        #expect(summary.days[3].entryCount == 2)
        #expect(summary.days[3].calorieDifference == 800)
    }

    @Test(
        "given a mix of statuses, when counting each, then the four counts add up to every day in the range",
        arguments: HistoryRange.allCases
    )
    func statusCountsCoverTheWholeRange(range: HistoryRange) {
        let end = Self.date(2026, 3, 20)
        let dates = Self.days(endingAt: end, count: range.days)
        let entries = dates.enumerated().compactMap { offset, date -> FoodLogEntry? in
            switch offset % 4 {
            case 0: entry(at: date, calories: 1_200)
            case 1: entry(at: date, calories: 2_000)
            case 2: entry(at: date, calories: 2_600)
            default: nil
            }
        }

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: Self.makeProfile(),
            range: range,
            endDate: end,
            calendar: Self.newYork
        )
        let current = analytics.current
        let statusTotal = HistoryGoalStatus.allCases.reduce(0) { $0 + current.count(for: $1) }

        #expect(statusTotal == range.days)
        #expect(current.count(for: .notLogged) == range.days - current.loggedDayCount)
        #expect(current.weeklyRollups.reduce(0) { $0 + $1.totalDays } == range.days)
        #expect(current.weeklyRollups.reduce(0) { $0 + $1.loggedDays } == current.loggedDayCount)
        #expect(current.weeklyRollups.reduce(0) { $0 + $1.onTrackDays } == current.onTrackLoggedDayCount)
        #expect(current.days.map(\.date) == dates)
    }

    @Test("given the previous period, when cutting it, then it is the same number of days ending the day before the current one starts")
    func thePreviousPeriodAbutsTheCurrentOne() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .twoWeeks,
            endDate: Self.date(2026, 3, 14, hour: 18),
            calendar: Self.newYork
        )

        #expect(analytics.current.days.first?.date == Self.date(2026, 3, 1, hour: 0))
        #expect(analytics.current.days.last?.date == Self.date(2026, 3, 14, hour: 0))
        #expect(analytics.previous.totalDayCount == 14)
        #expect(analytics.previous.days.first?.date == Self.date(2026, 2, 15, hour: 0))
        #expect(analytics.previous.days.last?.date == Self.date(2026, 2, 28, hour: 0))
        #expect(analytics.calendar == Self.newYork)
        #expect(analytics.current.calendar == Self.newYork)
    }

    @Test("given a week across the spring daylight-saving change, when cutting days, then each day starts at local midnight and the short day is still one day")
    func springForwardKeepsWholeDays() throws {
        let lateSunday = Self.date(2026, 3, 8, hour: 23, minute: 30)
        let earlyMonday = Self.date(2026, 3, 9, hour: 0, minute: 30)
        let analytics = HistoryAnalytics(
            entries: [entry(at: lateSunday, calories: 500), entry(at: earlyMonday, calories: 700)],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.date(2026, 3, 10),
            calendar: Self.newYork
        )
        let days = analytics.current.days

        #expect(days.map(\.date) == (4...10).map { Self.date(2026, 3, $0, hour: 0) })
        let sunday = try #require(days.first { $0.date == Self.date(2026, 3, 8, hour: 0) })
        let monday = try #require(days.first { $0.date == Self.date(2026, 3, 9, hour: 0) })
        #expect(monday.date.timeIntervalSince(sunday.date) == 23 * 3_600)
        #expect(sunday.calories == 500)
        #expect(monday.calories == 700)

        let weeks = analytics.current.weeklyRollups
        #expect(weeks.map(\.startDate) == [Self.date(2026, 3, 2, hour: 0), Self.date(2026, 3, 9, hour: 0)])
        #expect(weeks.map(\.totalDays) == [5, 2])
        #expect(weeks.map(\.loggedDays) == [1, 1])
    }

    @Test("given a week across the autumn daylight-saving change, when cutting days, then the long day is still one day and a late entry stays on it")
    func fallBackKeepsWholeDays() throws {
        let lateSunday = Self.date(2025, 11, 2, hour: 23, minute: 30)
        let earlyMonday = Self.date(2025, 11, 3, hour: 0, minute: 15)
        let analytics = HistoryAnalytics(
            entries: [entry(at: lateSunday, calories: 900), entry(at: earlyMonday, calories: 400)],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.date(2025, 11, 4),
            calendar: Self.newYork
        )
        let days = analytics.current.days

        #expect(days.count == 7)
        #expect(days.first?.date == Self.date(2025, 10, 29, hour: 0))
        let sunday = try #require(days.first { $0.date == Self.date(2025, 11, 2, hour: 0) })
        let monday = try #require(days.first { $0.date == Self.date(2025, 11, 3, hour: 0) })
        #expect(monday.date.timeIntervalSince(sunday.date) == 25 * 3_600)
        #expect(sunday.calories == 900)
        #expect(monday.calories == 400)
        #expect(analytics.current.weeklyRollups.map(\.totalDays) == [5, 2])
    }

    @Test("given an entry late in the evening in the analytics zone, when bucketing, then it belongs to that zone's day rather than the UTC one")
    func entriesAreBucketedInTheInjectedZone() throws {
        let lateEvening = Self.date(2026, 3, 4, hour: 22)
        let analytics = HistoryAnalytics(
            entries: [entry(at: lateEvening, calories: 1_234)],
            profile: Self.makeProfile(),
            range: .week,
            endDate: Self.date(2026, 3, 7),
            calendar: Self.newYork
        )

        let logged = analytics.current.days.filter(\.isLogged)
        #expect(logged.map(\.date) == [Self.date(2026, 3, 4, hour: 0)])
        #expect(logged.first?.calories == 1_234)
    }

    @Test("given a 30-day range ending on the first of March in a leap year, when cutting days, then February's 29th is one of them")
    func aMonthRangeIncludesTheLeapDay() {
        let analytics = HistoryAnalytics(
            entries: [entry(at: Self.date(2028, 2, 29), calories: 2_000)],
            profile: Self.makeProfile(),
            range: .month,
            endDate: Self.date(2028, 3, 1),
            calendar: Self.newYork
        )

        #expect(analytics.current.totalDayCount == 30)
        #expect(analytics.current.days.first?.date == Self.date(2028, 2, 1, hour: 0))
        #expect(analytics.current.days.last?.date == Self.date(2028, 3, 1, hour: 0))
        #expect(analytics.current.days.filter(\.isLogged).map(\.date) == [Self.date(2028, 2, 29, hour: 0)])
        #expect(analytics.previous.days.first?.date == Self.date(2028, 1, 2, hour: 0))
        #expect(analytics.previous.days.last?.date == Self.date(2028, 1, 31, hour: 0))
    }

    @Test(
        "given a week across the new year, when rolling up weeks, then they start on Mondays whatever the calendar's own week start",
        arguments: [1, 2, 7]
    )
    func weeksStartOnMondayAcrossTheYearEnd(firstWeekday: Int) {
        var calendar = Self.newYork
        calendar.firstWeekday = firstWeekday
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: Self.date(2026, 1, 2),
            calendar: calendar
        )

        let weeks = analytics.current.weeklyRollups
        #expect(weeks.map(\.startDate) == [Self.date(2025, 12, 22, hour: 0), Self.date(2025, 12, 29, hour: 0)])
        #expect(weeks.map(\.totalDays) == [2, 5])
        #expect(weeks.allSatisfy { calendar.component(.weekday, from: $0.startDate) == 2 })
        #expect(weeks.allSatisfy { $0.days.map(\.date) == $0.days.map(\.date).sorted() })
    }

    @Test("given a 90-day range across a daylight-saving change, when rolling up weeks, then every day is in exactly one Monday week")
    func aQuarterAcrossDaylightSavingRollsUpEveryDayOnce() {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .quarter,
            endDate: Self.date(2026, 4, 30),
            calendar: Self.newYork
        )
        let weeks = analytics.current.weeklyRollups

        #expect(weeks.reduce(0) { $0 + $1.totalDays } == 90)
        #expect(weeks.map(\.startDate) == weeks.map(\.startDate).sorted())
        #expect(Set(weeks.map(\.startDate)).count == weeks.count)
        #expect(weeks.allSatisfy { Self.newYork.component(.weekday, from: $0.startDate) == 2 })
        #expect(weeks.allSatisfy { $0.totalDays <= 7 })
        #expect(weeks.count == 14)
        #expect(weeks.first?.totalDays == 2)
        #expect(weeks.last?.totalDays == 4)
    }

    @Test("given a profile macro with no target, when listing macro patterns, then that macro is left out")
    func aMacroWithoutATargetIsLeftOut() {
        let profile = Self.makeProfile()
        profile.setTarget(0, for: .carbs)

        let analytics = HistoryAnalytics(
            entries: [entry(at: Self.date(2026, 1, 30), calories: 2_000)],
            profile: profile,
            range: .week,
            endDate: Self.date(2026, 1, 30),
            calendar: Self.newYork
        )

        #expect(analytics.macroPatterns.map(\.nutrient) == [.protein, .fat])
        #expect(analytics.macroPatterns.map(\.id) == ["protein", "fat"])
    }

    @Test("given a macro set as a maximum, when counting hit days, then staying at or under the target is a hit")
    func aMaximumMacroIsHitAtOrUnderTarget() throws {
        let profile = Self.makeProfile()
        profile.setGoalKind(.maximum, for: .fat)
        let fatTarget = profile.fatTargetG
        let end = Self.date(2026, 1, 30)

        let analytics = HistoryAnalytics(
            entries: [
                entry(at: end, calories: 2_000, fat: fatTarget),
                entry(at: Self.date(2026, 1, 29), calories: 2_000, fat: 10),
                entry(at: Self.date(2026, 1, 28), calories: 2_000, fat: fatTarget + 1)
            ],
            profile: profile,
            range: .week,
            endDate: end,
            calendar: Self.newYork
        )

        let fat = try #require(analytics.macroPatterns.first { $0.nutrient == .fat })
        #expect(fat.goalKind == .maximum)
        #expect(fat.current.loggedDays == 3)
        #expect(fat.current.hitDays == 2)
    }

    @Test("given macro averages in both periods, when comparing them, then the delta is this period's average minus the last one's")
    func theMacroDeltaIsCurrentMinusPrevious() throws {
        let end = Self.date(2026, 1, 30)
        let analytics = HistoryAnalytics(
            entries: [
                entry(at: end, calories: 2_000, protein: 120),
                entry(at: Self.date(2026, 1, 29), calories: 2_000, protein: 140),
                entry(at: Self.date(2026, 1, 22), calories: 2_000, protein: 100)
            ],
            profile: Self.makeProfile(),
            range: .week,
            endDate: end,
            calendar: Self.newYork
        )

        let protein = try #require(analytics.macroPatterns.first { $0.nutrient == .protein })
        #expect(protein.current.averageValue == 130)
        #expect(protein.previous.averageValue == 100)
        #expect(protein.averageValueDelta == 30)
    }

    @Test(
        "given a day's entries, when reading any tracked nutrient, then the summary and its detail both add it up",
        arguments: [
            (TrackedNutrient.protein, 10.0),
            (TrackedNutrient.carbs, 20.0),
            (TrackedNutrient.fat, 5.0),
            (TrackedNutrient.fiber, 7.0),
            (TrackedNutrient.sugars, 11.0),
            (TrackedNutrient.addedSugars, 12.0),
            (TrackedNutrient.saturatedFat, 13.0),
            (TrackedNutrient.sodium, 1.4),
            (TrackedNutrient.cholesterol, 0.15),
            (TrackedNutrient.alcohol, 16.0)
        ] as [(TrackedNutrient, Double)]
    )
    func everyNutrientIsSummed(nutrient: TrackedNutrient, perEntry: Double) {
        let expected = perEntry * 2
        let date = Self.date(2026, 1, 30)
        let food = makeTestFoodItem(
            name: "Everything",
            caloriesPer100g: 400,
            proteinPer100g: 10,
            carbsPer100g: 20,
            fatPer100g: 5,
            fiberPer100g: 7,
            sugarsPer100g: 11,
            addedSugarsPer100g: 12,
            saturatedFatPer100g: 13,
            sodiumPer100g: 1.4,
            cholesterolPer100g: 0.15,
            alcoholPer100g: 16
        )
        let entries = [food, food].map { item in
            let entry = makeTestEntry(date: date, mealType: .lunch, foodItem: item, portionGrams: 100)
            entry.date = date
            return entry
        }

        let day = HistoryDaySummary(date: date, entries: entries, dailyCalorieTarget: 2_000)
        let detail = day.makeDetail()

        #expect(abs(day.value(for: nutrient) - expected) < 0.000_001)
        #expect(abs(detail.value(for: nutrient) - expected) < 0.000_001)
    }

    @Test(
        "given entries with no optional nutrients recorded, when reading them, then they count as zero rather than missing",
        arguments: [TrackedNutrient.sugars, .addedSugars, .saturatedFat, .sodium, .cholesterol, .alcohol]
    )
    func missingOptionalNutrientsReadAsZero(nutrient: TrackedNutrient) {
        let date = Self.date(2026, 1, 30)
        let day = HistoryDaySummary(date: date, entries: [entry(at: date, calories: 500)], dailyCalorieTarget: 2_000)

        #expect(day.value(for: nutrient) == 0)
        #expect(day.makeDetail().value(for: nutrient) == 0)
    }

    @Test("given a day detail built without a status, when rating it, then it rates itself against its own target")
    func aDetailWithoutAStatusRatesItself() {
        let date = Self.date(2026, 1, 30)
        let over = HistoryDayDetail(date: date, entries: [entry(at: date, calories: 2_500)], dailyCalorieTarget: 2_000)
        let under = HistoryDayDetail(date: date, entries: [entry(at: date, calories: 1_000)], dailyCalorieTarget: 2_000)
        let empty = HistoryDayDetail(date: date, entries: [], dailyCalorieTarget: 2_000)

        #expect(over.status == .over)
        #expect(over.calorieDifference == 500)
        #expect(over.id == date)
        #expect(over.isLogged)
        #expect(under.status == .under)
        #expect(under.calorieDifference == -1_000)
        #expect(empty.status == .notLogged)
        #expect(empty.isLogged == false)
    }

    @Test("given a day detail with a stated status, when built, then that status is kept even where its own rule would differ")
    func aStatedStatusIsKept() {
        let date = Self.date(2026, 1, 30)
        let detail = HistoryDayDetail(
            date: date,
            entries: [entry(at: date, calories: 2_500)],
            dailyCalorieTarget: 2_000,
            status: .onTrack,
            isTargetEstimated: true
        )

        #expect(detail.status == .onTrack)
        #expect(detail.isTargetEstimated)
    }

    @Test("given an out-of-range target, when building a day or its detail, then the target is clamped into the calorie domain")
    func targetsAreClampedAtTheBoundary() {
        let date = Self.date(2026, 1, 30)
        let day = HistoryDaySummary(date: date, entries: [], dailyCalorieTarget: Int.min)
        let detail = HistoryDayDetail(date: date, entries: [], dailyCalorieTarget: Int.max)

        #expect(day.dailyCalorieTarget == CalorieDomain.minimum)
        #expect(detail.dailyCalorieTarget == CalorieDomain.maximum)
    }

    @Test("given portions across meals, when detailing the day, then grams are totalled and meals keep their canonical order")
    func theDetailTotalsPortionsAndOrdersMeals() {
        let date = Self.date(2026, 1, 30)
        let entries = [
            entry(at: date, calories: 300, mealType: .snack, portionGrams: 50),
            entry(at: date, calories: 200, mealType: .breakfast, portionGrams: 120),
            entry(at: date, calories: 100, mealType: .snack, portionGrams: 30)
        ]

        let detail = HistoryDayDetail(date: date, entries: entries, dailyCalorieTarget: 2_000)

        #expect(detail.totalPortionGrams == 200)
        #expect(detail.mealSummaries.map(\.id) == ["breakfast", "snack"])
        #expect(detail.mealSummaries.map(\.entryCount) == [1, 2])
    }

    @Test("given foods with equal calories, when ranking the day's foods, then they are ordered by name, numbers numerically")
    func equalCalorieFoodsAreOrderedByName() {
        let date = Self.date(2026, 1, 30)
        let entries = [
            entry(at: date, calories: 100, name: "Pear"),
            entry(at: date, calories: 100, name: "Item 10"),
            entry(at: date, calories: 100, name: "apple"),
            entry(at: date, calories: 100, name: "Item 9"),
            entry(at: date, calories: 400, name: "Toast")
        ]

        let foods = HistoryDayDetail(date: date, entries: entries, dailyCalorieTarget: 2_000).topFoods

        #expect(foods.map(\.name) == ["Toast", "apple", "Item 9", "Item 10", "Pear"])
    }

    @Test("given the same food spelled with different case, accents and spacing, when ranking foods, then it is one food under its first spelling")
    func foodsMergeAcrossCaseAndAccents() throws {
        let date = Self.date(2026, 1, 30)
        let entries = [
            entry(at: date, calories: 120, name: "Café Latte", portionGrams: 250),
            entry(at: date, calories: 120, name: "  cafe latte ", portionGrams: 250),
            entry(at: date, calories: 90, name: "CAFÉ LATTE", portionGrams: 200)
        ]

        let foods = HistoryDayDetail(date: date, entries: entries, dailyCalorieTarget: 2_000).topFoods

        let latte = try #require(foods.first)
        #expect(foods.count == 1)
        #expect(latte.name == "Café Latte")
        #expect(latte.id == "cafe latte")
        #expect(latte.entryCount == 3)
        #expect(latte.portionGrams == 700)
        #expect(latte.calories == 780)
    }

    @Test("given grades in either case and an unknown one, when distributing them, then they are counted a to e and the unknown is dropped")
    func nutriscoreGradesAreCaseInsensitiveAndOrdered() {
        let date = Self.date(2026, 1, 30)
        let entries = ["E", "a", "x", "C", "A", nil, "e"].map { grade in
            entry(at: date, calories: 100, nutriscoreGrade: grade)
        }

        let distribution = HistoryDayDetail(date: date, entries: entries, dailyCalorieTarget: 2_000).nutriscoreDistribution

        #expect(distribution.map(\.grade) == ["a", "c", "e"])
        #expect(distribution.map(\.id) == ["a", "c", "e"])
        #expect(distribution.map(\.count) == [2, 1, 2])
        #expect(distribution.reduce(0) { $0 + $1.count } == 5)
    }

    @Test("given a selected day or week, when identifying the selection, then it is keyed by kind and the UTC instant of its start")
    func selectionsAreKeyedByKindAndInstant() throws {
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: Self.date(2026, 3, 10),
            calendar: Self.newYork
        )
        let monday = try #require(analytics.current.days.first { $0.date == Self.date(2026, 3, 9, hour: 0) })
        let week = try #require(analytics.current.weeklyRollups.last)

        #expect(HistoryCalorieTrendSelection.day(monday).id == "day-2026-03-09T04:00:00Z")
        #expect(HistoryCalorieTrendSelection.week(week).id == "week-2026-03-09T04:00:00Z")
    }

    private static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func days(from start: Date, count: Int) -> [Date] {
        let first = newYork.startOfDay(for: start)
        return (0..<count).compactMap { newYork.date(byAdding: .day, value: $0, to: first) }
    }

    private static func days(endingAt end: Date, count: Int) -> [Date] {
        let last = newYork.startOfDay(for: end)
        let first = newYork.date(byAdding: .day, value: -(count - 1), to: last)!
        return days(from: first, count: count)
    }

    private static func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000
        )
    }

    private func entry(
        at date: Date,
        calories: Double,
        name: String = "Test Food",
        mealType: MealType = .lunch,
        portionGrams: Double = 100,
        protein: Double = 0,
        fat: Double = 0,
        nutriscoreGrade: String? = nil
    ) -> FoodLogEntry {
        let entry = makeTestEntry(
            date: date,
            mealType: mealType,
            foodItem: makeTestFoodItem(
                name: name,
                caloriesPer100g: calories,
                proteinPer100g: protein,
                carbsPer100g: 0,
                fatPer100g: fat,
                nutriscoreGrade: nutriscoreGrade
            ),
            portionGrams: portionGrams
        )
        entry.date = date
        return entry
    }

    private func makeSummary(
        dates: [Date],
        entries: [FoodLogEntry] = [],
        fallbackTarget: Int = 2_000,
        snapshotTargets: [Date: Int] = [:]
    ) -> HistoryPeriodSummary {
        let calendar = Self.newYork
        var valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
        for (date, target) in snapshotTargets {
            valuesByDayKey[DailyGoalSnapshot.dayKey(for: date, calendar: calendar)] = DailyGoalSnapshotValues(
                calorieTarget: target,
                isManualTarget: false
            )
        }

        return HistoryPeriodSummary(
            dates: dates,
            entriesByDate: Dictionary(grouping: entries) { calendar.startOfDay(for: $0.date) },
            targetResolver: HistoryDayTargetResolver(fallbackTarget: fallbackTarget, valuesByDayKey: valuesByDayKey),
            calendar: calendar
        )
    }
}
