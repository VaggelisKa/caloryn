import Foundation
import Testing
@testable import Caloryn

/// The recurring-calorie observation: what its card says, how competing candidates are ranked
/// when more than one qualifies, and how its 30-day evidence window and supporting days are
/// cut under an injected calendar that crosses a daylight-saving change.
///
/// Dates are built in a fixed New York calendar so a rule that read the host calendar fails.
@MainActor
@Suite("History recurring calorie pattern coverage")
struct HistoryRecurringCaloriePatternCoverageTests {

    // MARK: - Card copy

    @Test("given a weekday pattern, when headlining it, then it names the weekday and the meal in the plural")
    func weekdayHeadline() {
        let pattern = makePattern(kind: .weekdayMeal, weekday: 6, mealType: .dinner)

        #expect(pattern.headline == "Friday dinners stood out")
        #expect(pattern.weekdayName == "Friday")
    }

    @Test(
        "given a meal-only pattern, when headlining it, then it names the meal and the outcome",
        arguments: [
            (MealType.breakfast, HistoryRecurringCalorieOutcome.above, "Breakfasts stood out on above target days"),
            (.lunch, .below, "Lunches stood out on below target days"),
            (.dinner, .above, "Dinners stood out on above target days"),
            (.snack, .below, "Snacks stood out on below target days")
        ]
    )
    func mealOnlyHeadline(mealType: MealType, outcome: HistoryRecurringCalorieOutcome, expected: String) {
        let pattern = makePattern(kind: .mealOnly, outcome: outcome, weekday: nil, mealType: mealType)

        #expect(pattern.headline == expected)
    }

    @Test("given a weekday pattern, when comparing it, then the cohort share and the rounded meal difference are stated")
    func weekdayComparisonText() {
        let pattern = makePattern(
            kind: .weekdayMeal,
            outcome: .above,
            weekday: 2,
            mealType: .lunch,
            supportingDayCount: 4,
            cohortDayCount: 5,
            mealDifferenceCalories: 312.6
        )

        #expect(
            pattern.comparisonText
                == "4 of 5 logged Mondays were above target. Lunch averaged 313 kcal more than on your other eligible logged days."
        )
    }

    @Test("given a meal-only pattern eating less, when comparing it, then the meal is lower case mid-sentence and the difference reads as less")
    func mealOnlyComparisonText() {
        let pattern = makePattern(
            kind: .mealOnly,
            outcome: .below,
            weekday: nil,
            mealType: .dinner,
            supportingDayCount: 6,
            mealDifferenceCalories: -449.5
        )

        #expect(
            pattern.comparisonText
                == "Across 6 below target logged days, dinner averaged 450 kcal less than on your other eligible logged days."
        )
    }

    @Test("given a snack pattern, when comparing it, then snacks are named in the plural")
    func snackComparisonIsPlural() {
        let weekday = makePattern(kind: .weekdayMeal, weekday: 7, mealType: .snack, mealDifferenceCalories: 200)
        let mealOnly = makePattern(kind: .mealOnly, weekday: nil, mealType: .snack, mealDifferenceCalories: 200)

        #expect(weekday.comparisonText.contains("Saturdays were above target. Snacks averaged 200 kcal more"))
        #expect(mealOnly.comparisonText.contains("logged days, snacks averaged 200 kcal more"))
    }

    @Test("given a pattern, when stating its basis, then it counts the eligible logged days in the 30-day window")
    func basisText() {
        #expect(makePattern(eligibleDayCount: 11).basisText == "Based on 11 logged days in the last 30 days")
    }

    @Test("given each kind, when stating the comparison group, then a weekday pattern gives a share and a meal-only one a count")
    func outcomeComparisonText() {
        let weekday = makePattern(
            kind: .weekdayMeal,
            outcome: .below,
            weekday: 4,
            outcomeComparisonCount: 1,
            outcomeComparisonDayCount: 6
        )
        let mealOnly = makePattern(kind: .mealOnly, weekday: nil, mealComparisonDayCount: 7)

        #expect(weekday.outcomeComparisonText == "1 of 6 other eligible logged days were below target.")
        #expect(mealOnly.outcomeComparisonText == "7 other eligible logged days form the comparison.")
    }

    @Test(
        "given a calendar weekday number, when naming it, then 1 is Sunday through 7 Saturday and anything else is blank",
        arguments: [
            (Int?.some(1), "Sunday"),
            (2, "Monday"),
            (3, "Tuesday"),
            (4, "Wednesday"),
            (5, "Thursday"),
            (6, "Friday"),
            (7, "Saturday"),
            (0, ""),
            (8, ""),
            (nil, "")
        ] as [(Int?, String)]
    )
    func weekdayNames(weekday: Int?, expected: String) {
        #expect(makePattern(weekday: weekday).weekdayName == expected)
    }

    @Test("given each outcome, when describing it, then it maps to the day status it counts and reads as a target side")
    func outcomeWording() {
        #expect(HistoryRecurringCalorieOutcome.above.status == .over)
        #expect(HistoryRecurringCalorieOutcome.below.status == .under)
        #expect(HistoryRecurringCalorieOutcome.above.targetText == "above target")
        #expect(HistoryRecurringCalorieOutcome.below.targetText == "below target")
    }

    @Test("given the drill-down's meal comparison, when captioning it, then the baseline is the other eligible days")
    func detailSummaryCaption() {
        let summary = HistoryRecurringCaloriePatternDetailSummary(
            kind: .mealOnly,
            outcomeTargetText: "above target",
            weekdayName: "",
            mealType: .dinner,
            supportingDayCount: 4,
            cohortDayCount: 4,
            outcomeComparisonCount: 0,
            outcomeComparisonDayCount: 4,
            mealComparisonDayCount: 4,
            mealDifferenceCalories: 600
        )

        #expect(summary.mealDifferenceCaption == "Average difference versus other eligible logged days")
        #expect(summary.comparisonTitle == "Other logged days")
        #expect(summary.mealComparisonTitle == "Dinner comparison")
    }

    // MARK: - Ranking between candidates

    @Test("given a weekday candidate and a meal-only candidate, when ranking, then the stronger outcome separation wins")
    func strongerSeparationWins() throws {
        let fridays = [2, 9, 16, 23].map { Self.date(2026, 1, $0) }
        let others = [3, 5, 6, 7, 8, 10, 30].map { Self.date(2026, 1, $0) }
        var entries = fridays.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 1_300, snack: 100) }
        entries += others.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 500, snack: 100) }
        let targets = fridays + others

        let weekdayOnly = try #require(discover(
            entries,
            exactTargets: targets,
            policy: HistoryRecurringCaloriePatternPolicy(minimumMealOnlyGroupCount: 100)
        ))
        let ranked = try #require(discover(entries, exactTargets: targets))

        // Four of five Fridays were over against none of the other days: a 0.8 separation.
        #expect(weekdayOnly.id == "weekdayMeal|6|above|dinner")
        #expect(abs(weekdayOnly.rateSeparation - 0.8) < 0.000_001)
        // The meal-only reading of the same days separates completely, so it ranks first.
        #expect(ranked.id == "mealOnly|above|dinner")
        #expect(ranked.rateSeparation == 1)
        #expect(ranked.kind == .mealOnly)
        #expect(ranked.weekday == nil)
    }

    @Test("given two meal-only candidates equally separated, when ranking, then the larger share of the day's target wins")
    func largerTargetShareWins() throws {
        let above = [3, 12, 20, 29].map { Self.date(2026, 1, $0) }
        let below = [4, 13, 21, 30].map { Self.date(2026, 1, $0) }
        let onTrack = [6, 15, 24, 26].map { Self.date(2026, 1, $0) }
        var entries = above.flatMap { day(on: $0, breakfast: 1_000, lunch: 500, dinner: 800) }
        entries += below.flatMap { day(on: $0, breakfast: 1_000, lunch: 500, dinner: 100) }
        entries += onTrack.flatMap { day(on: $0, breakfast: 1_000, lunch: 500, dinner: 500) }

        let pattern = try #require(discover(entries, exactTargets: above + below + onTrack))

        // Above: 800 against an average 300 elsewhere, a quarter of the target.
        // Below: 100 against an average 650 elsewhere, 0.275 of it, so it outranks the above one.
        #expect(pattern.id == "mealOnly|below|dinner")
        #expect(abs(pattern.mealDifferenceCalories - -550) < 0.000_001)
        #expect(abs(pattern.targetRelativeMealDifference - -0.275) < 0.000_001)
        #expect(pattern.eligibleDayCount == 12)
    }

    @Test("given two meal-only candidates tied on separation and share, when ranking, then the one with more supporting days wins before the identifier")
    func moreSupportingDaysWinsBeforeTheIdentifier() throws {
        let above = [3, 12, 20, 29].map { Self.date(2026, 1, $0) }
        let below = [4, 8, 13, 21, 30].map { Self.date(2026, 1, $0) }
        // Dinner shares of 0.5 and 0.125 are exact in binary, so the two candidates tie exactly.
        var entries = above.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 1_000) }
        entries += below.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 250) }

        let pattern = try #require(discover(entries, exactTargets: above + below))

        // By identifier alone "above" would sort first; five supporting days beat four.
        #expect(pattern.id == "mealOnly|below|dinner")
        #expect(pattern.supportingDays.count == 5)
        #expect(pattern.cohortDayCount == 5)
        #expect(pattern.mealComparisonDayCount == 4)
    }

    @Test("given a weekday that is reliably over but with the excess spread thinly across meals, when discovering, then no pattern is shown")
    func aWeekdayWithoutAStandoutMealIsRejected() {
        let fridays = [2, 9, 16, 23].map { Self.date(2026, 1, $0) }
        let others = [3, 5, 6, 7, 8, 10, 30].map { Self.date(2026, 1, $0) }
        // Fridays run 200 over in total, but no single meal moves by the required tenth of the target.
        var entries = fridays.flatMap { day(on: $0, breakfast: 800, lunch: 800, dinner: 600) }
        entries += others.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 500, snack: 100) }

        let weekdayOnly = discover(
            entries,
            exactTargets: fridays + others,
            policy: HistoryRecurringCaloriePatternPolicy(minimumMealOnlyGroupCount: 100)
        )
        let standard = discover(entries, exactTargets: fridays + others)

        #expect(weekdayOnly == nil)
        #expect(standard == nil)
    }

    // MARK: - Supporting days

    @Test("given a supporting day with several foods in the meal, when listing them, then they rank by calories and equal ones by name")
    func supportingFoodsRankByCaloriesThenName() throws {
        let above = [3, 12, 20, 29].map { Self.date(2026, 1, $0) }
        let comparison = [4, 13, 21, 30].map { Self.date(2026, 1, $0) }
        var entries = comparison.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 500, snack: 100) }
        for date in above {
            entries += day(on: date, breakfast: 700, lunch: 700, dinner: 0, snack: 100)
            entries.append(entry(at: date, mealType: .dinner, name: "Zucchini bake", calories: 650))
            entries.append(entry(at: date, mealType: .dinner, name: "apple crumble", calories: 650))
            entries.append(entry(at: date, mealType: .dinner, name: "Bread", calories: 200))
        }

        let pattern = try #require(discover(entries, exactTargets: above + comparison))
        let firstDay = try #require(pattern.supportingDays.first)

        #expect(pattern.mealType == .dinner)
        #expect(firstDay.id == firstDay.date)
        #expect(firstDay.mealCalories == 1_500)
        #expect(firstDay.totalCalories == 3_000)
        #expect(firstDay.mealFoods.map(\.name) == ["apple crumble", "Zucchini bake", "Bread"])
        #expect(firstDay.mealFoods.map(\.calories) == [650, 650, 200])
        #expect(firstDay.mealFoods.map(\.entryCount) == [1, 1, 1])
    }

    // MARK: - Calendar

    @Test("given now just after the spring daylight-saving change, when cutting the evidence window, then it is 30 local midnights ending yesterday")
    func evidenceWindowAcrossDaylightSaving() {
        let window = HistoryRecurringCaloriePatternEngine().evidenceWindow(
            now: Self.date(2026, 3, 20, hour: 8),
            calendar: Self.newYork
        )

        #expect(window.lowerBound == Self.date(2026, 2, 18, hour: 0))
        #expect(window.upperBound == Self.date(2026, 3, 19, hour: 0))
        // 29 days apart, one of which was 23 hours long.
        #expect(window.upperBound.timeIntervalSince(window.lowerBound) == 29 * 86_400 - 3_600)
    }

    @Test("given a pattern whose evidence spans the daylight-saving change, when discovering it, then days are bucketed and labelled in the injected calendar")
    func patternAcrossDaylightSaving() throws {
        let now = Self.date(2026, 3, 20, hour: 8)
        let above = [
            Self.date(2026, 2, 21),
            Self.date(2026, 3, 1),
            // Late on the short day: 03:30 the next morning in UTC.
            Self.date(2026, 3, 8, hour: 23, minute: 30),
            Self.date(2026, 3, 17)
        ]
        let comparison = [
            Self.date(2026, 2, 23),
            Self.date(2026, 3, 4),
            Self.date(2026, 3, 10),
            Self.date(2026, 3, 12)
        ]
        var entries = above.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 900, snack: 100) }
        entries += comparison.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 500, snack: 100) }
        // Outside the window on either side: today, and the day before the window opens.
        let outside = [Self.date(2026, 3, 20), Self.date(2026, 2, 17)]
        entries += outside.flatMap { day(on: $0, breakfast: 700, lunch: 700, dinner: 900, snack: 100) }

        let pattern = try #require(discover(
            entries,
            exactTargets: above + comparison + outside,
            now: now
        ))

        #expect(pattern.id == "mealOnly|above|dinner")
        #expect(pattern.eligibleDayCount == 8)
        #expect(pattern.calendar == Self.newYork)
        #expect(pattern.windowStart == Self.date(2026, 2, 18, hour: 0))
        #expect(pattern.windowEnd == Self.date(2026, 3, 19, hour: 0))
        #expect(pattern.supportingDays.map(\.date) == [
            Self.date(2026, 2, 21, hour: 0),
            Self.date(2026, 3, 1, hour: 0),
            Self.date(2026, 3, 8, hour: 0),
            Self.date(2026, 3, 17, hour: 0)
        ])
        #expect(pattern.supportingDays.map { pattern.dayText(for: $0.date) } == [
            "Sat, 21 Feb", "Sun, 1 Mar", "Sun, 8 Mar", "Tue, 17 Mar"
        ])
        #expect(pattern.headline == "Dinners stood out on above target days")
        #expect(
            pattern.comparisonText
                == "Across 4 above target logged days, dinner averaged 400 kcal more than on your other eligible logged days."
        )
        #expect(pattern.basisText == "Based on 8 logged days in the last 30 days")
        #expect(pattern.outcomeComparisonText == "4 other eligible logged days form the comparison.")
    }

    // MARK: - Fixtures

    private static let newYork: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        newYork.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func discover(
        _ entries: [FoodLogEntry],
        exactTargets dates: [Date],
        target: Int = 2_000,
        now: Date? = nil,
        policy: HistoryRecurringCaloriePatternPolicy = .standard
    ) -> HistoryRecurringCaloriePattern? {
        var valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
        for date in dates {
            valuesByDayKey[DailyGoalSnapshot.dayKey(for: date, calendar: Self.newYork)] = DailyGoalSnapshotValues(
                baseCalorieTarget: target,
                healthAdjustment: 0,
                effectiveCalorieTarget: target,
                calculationMode: .lifestyleEstimate,
                isManualTarget: false
            )
        }
        return HistoryRecurringCaloriePatternEngine(policy: policy).discover(
            entries: entries,
            targetResolver: HistoryDayTargetResolver(fallbackTarget: target, valuesByDayKey: valuesByDayKey),
            // Unless stated, evidence is January 2026: the window is 2 to 31 January.
            now: now ?? Self.date(2026, 2, 1, hour: 9),
            calendar: Self.newYork
        )
    }

    private func day(
        on date: Date,
        breakfast: Double,
        lunch: Double,
        dinner: Double,
        snack: Double = 0
    ) -> [FoodLogEntry] {
        [(MealType.breakfast, breakfast), (.lunch, lunch), (.dinner, dinner), (.snack, snack)]
            .compactMap { meal, calories in
                guard calories > 0 else { return nil }
                return entry(at: date, mealType: meal, name: "\(meal.displayName) evidence", calories: calories)
            }
    }

    /// An entry at an exact instant. The factory normalises dates with the host calendar,
    /// so the instant is put back and bucketing is left to the calendar under test.
    private func entry(at date: Date, mealType: MealType, name: String, calories: Double) -> FoodLogEntry {
        let entry = makeTestEntry(
            date: date,
            mealType: mealType,
            foodItem: makeTestFoodItem(name: name, caloriesPer100g: calories),
            portionGrams: 100
        )
        entry.date = date
        return entry
    }

    private func makePattern(
        kind: HistoryRecurringCaloriePatternKind = .weekdayMeal,
        outcome: HistoryRecurringCalorieOutcome = .above,
        weekday: Int? = 6,
        mealType: MealType = .dinner,
        supportingDayCount: Int = 4,
        cohortDayCount: Int = 5,
        outcomeComparisonCount: Int = 0,
        outcomeComparisonDayCount: Int = 6,
        mealComparisonDayCount: Int = 7,
        eligibleDayCount: Int = 11,
        mealDifferenceCalories: Double = 800
    ) -> HistoryRecurringCaloriePattern {
        let start = Self.date(2026, 1, 2, hour: 0)
        let supportingDays = (0..<supportingDayCount).map { offset in
            HistoryRecurringCaloriePatternDay(
                date: Self.newYork.date(byAdding: .day, value: offset * 7, to: start)!,
                dailyCalorieTarget: 2_000,
                totalCalories: 2_800,
                mealCalories: 1_300,
                mealFoods: []
            )
        }
        return HistoryRecurringCaloriePattern(
            id: "fixture",
            kind: kind,
            outcome: outcome,
            weekday: weekday,
            mealType: mealType,
            supportingDays: supportingDays,
            cohortDayCount: cohortDayCount,
            outcomeComparisonCount: outcomeComparisonCount,
            outcomeComparisonDayCount: outcomeComparisonDayCount,
            mealComparisonDayCount: mealComparisonDayCount,
            eligibleDayCount: eligibleDayCount,
            mealDifferenceCalories: mealDifferenceCalories,
            targetRelativeMealDifference: mealDifferenceCalories / 2_000,
            rateSeparation: 1,
            windowStart: start,
            windowEnd: Self.date(2026, 1, 31, hour: 0),
            calendar: Self.newYork
        )
    }
}
