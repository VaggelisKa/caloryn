import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class DailyGoalSnapshotTests: XCTestCase {
    func testDayKeyIsStableAcrossTimesOfDay() {
        let morning = makeTestDate(year: 2026, month: 3, day: 9, hour: 0, minute: 1)
        let night = makeTestDate(year: 2026, month: 3, day: 9, hour: 23, minute: 59)

        XCTAssertEqual(DailyGoalSnapshot.dayKey(for: morning), "2026-03-09")
        XCTAssertEqual(DailyGoalSnapshot.dayKey(for: night), "2026-03-09")
    }

    func testDayKeyUsesSuppliedCalendarTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = TimeZone(identifier: "UTC")!
        components.year = 2026
        components.month = 3
        components.day = 9
        components.hour = 23
        let date = components.date!

        XCTAssertEqual(DailyGoalSnapshot.dayKey(for: date, calendar: calendar), "2026-03-09")
    }

    func testSnapshotValuesMatchTheBudgetTodayDisplays() {
        let values = CalorieBudget(consumed: 0, target: 2_000).goalSnapshotValues

        XCTAssertEqual(values.calorieTarget, 2_000)
        XCTAssertFalse(values.isManualTarget)
    }

    func testManualBudgetSnapshotPreservesManualSemantics() {
        let values = CalorieBudget(consumed: 0, target: 1_800, isManualOverride: true).goalSnapshotValues

        XCTAssertTrue(values.isManualTarget)
        XCTAssertEqual(values.calorieTarget, 1_800)
    }

    func testRecordingWritesTheTargetAsBothBaseAndEffectiveWithNoHealthAdjustment() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)

        DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 1_950),
            for: today,
            profile: profile,
            in: context,
            now: today
        )

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<DailyGoalSnapshot>()).first)
        XCTAssertEqual(stored.baseCalorieTarget, 1_950)
        XCTAssertEqual(stored.effectiveCalorieTarget, 1_950)
        XCTAssertEqual(stored.healthAdjustment, 0)
        XCTAssertEqual(stored.calculationModeRaw, "lifestyleEstimate")
    }

    func testASnapshotRecordedWithAHealthAdjustmentStillReadsItsEffectiveTarget() throws {
        let context = try makeContext()
        let snapshot = DailyGoalSnapshot(
            dayKey: "2026-03-09",
            values: makeValues(target: 2_000),
            profile: nil
        )
        snapshot.healthAdjustment = 250
        snapshot.effectiveCalorieTarget = 2_250
        snapshot.calculationModeRaw = "dynamicHealth"
        context.insert(snapshot)

        XCTAssertEqual(snapshot.values.calorieTarget, 2_250)
    }

    func testRecordingCreatesOneSnapshotForTheCurrentDay() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)

        let didRecord = DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 2_000),
            for: today,
            profile: profile,
            in: context,
            now: today
        )

        XCTAssertTrue(didRecord)
        let stored = try context.fetch(FetchDescriptor<DailyGoalSnapshot>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.dayKey, "2026-03-09")
        XCTAssertEqual(stored.first?.effectiveCalorieTarget, 2_000)
    }

    func testRecordingTwiceOnTheSameDayUpsertsRatherThanDuplicating() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)

        DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 2_000),
            for: today,
            profile: profile,
            in: context,
            now: today
        )
        DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 2_250),
            for: today,
            profile: profile,
            in: context,
            now: today
        )

        let stored = try context.fetch(FetchDescriptor<DailyGoalSnapshot>())
        XCTAssertEqual(stored.count, 1, "One canonical snapshot per calendar day")
        XCTAssertEqual(stored.first?.effectiveCalorieTarget, 2_250)
    }

    func testRecordingUnchangedValuesDoesNotRewriteTheSnapshot() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)
        let values = makeValues(target: 2_000)

        DailyGoalSnapshotStore.recordSnapshot(
            values: values, for: today, profile: profile, in: context, now: today
        )
        let didRecordAgain = DailyGoalSnapshotStore.recordSnapshot(
            values: values, for: today, profile: profile, in: context, now: today
        )

        XCTAssertFalse(didRecordAgain)
    }

    func testPastAndFutureDaysAreNeverRecorded() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)
        let yesterday = makeTestDate(year: 2026, month: 3, day: 8)
        let tomorrow = makeTestDate(year: 2026, month: 3, day: 10)

        let recordedPast = DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 2_000),
            for: yesterday, profile: profile, in: context, now: today
        )
        let recordedFuture = DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(target: 2_000),
            for: tomorrow, profile: profile, in: context, now: today
        )

        XCTAssertFalse(recordedPast, "A finalized past day must never be rewritten")
        XCTAssertFalse(recordedFuture)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DailyGoalSnapshot>()).isEmpty)
    }

    func testDuplicateSnapshotsCollapseToTheMostRecentlyUpdated() {
        let profile = makeProfile()
        let older = DailyGoalSnapshot(
            dayKey: "2026-03-09",
            values: makeValues(target: 2_000),
            profile: profile,
            recordedAt: makeTestDate(year: 2026, month: 3, day: 9, hour: 8)
        )
        let newer = DailyGoalSnapshot(
            dayKey: "2026-03-09",
            values: makeValues(target: 2_300),
            profile: profile,
            recordedAt: makeTestDate(year: 2026, month: 3, day: 9, hour: 20)
        )

        let collapsed = DailyGoalSnapshotStore.latestValuesByDayKey([older, newer])

        XCTAssertEqual(collapsed.count, 1)
        XCTAssertEqual(collapsed["2026-03-09"]?.calorieTarget, 2_300)
    }

    func testResolverUsesTheSnapshotWhenOneExists() {
        let date = makeTestDate(year: 2026, month: 3, day: 9)
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 2_000,
            valuesByDayKey: ["2026-03-09": makeValues(target: 2_400)]
        )

        let target = resolver.target(for: date)

        XCTAssertEqual(target.calories, 2_400)
        XCTAssertFalse(target.isEstimated)
    }

    func testResolverFallsBackAndFlagsLegacyDays() {
        let resolver = HistoryDayTargetResolver(fallbackTarget: 2_000)

        let target = resolver.target(for: makeTestDate(year: 2026, month: 3, day: 9))

        XCTAssertEqual(target.calories, 2_000)
        XCTAssertTrue(target.isEstimated, "Legacy days must be marked, not presented as precise")
    }

    func testChangingTheProfileTargetDoesNotChangeSnapshottedDayStatus() {
        let entries = [
            makeEntry(date: makeTestDate(year: 2026, month: 3, day: 9), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 3, day: 8), calories: 2_000)
        ]
        let snapshots = [
            "2026-03-09": makeValues(target: 2_000),
            "2026-03-08": makeValues(target: 2_000)
        ]

        let beforeChange = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 2_000),
            range: .week,
            endDate: makeTestDate(year: 2026, month: 3, day: 9),
            targetResolver: HistoryDayTargetResolver(fallbackTarget: 2_000, valuesByDayKey: snapshots)
        )
        let afterChange = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 1_500),
            range: .week,
            endDate: makeTestDate(year: 2026, month: 3, day: 9),
            targetResolver: HistoryDayTargetResolver(fallbackTarget: 1_500, valuesByDayKey: snapshots)
        )

        XCTAssertEqual(beforeChange.current.count(for: .onTrack), 2)
        XCTAssertEqual(
            afterChange.current.count(for: .onTrack),
            beforeChange.current.count(for: .onTrack),
            "A later target change must not rewrite history"
        )
        XCTAssertEqual(afterChange.current.count(for: .over), 0)
    }

    func testWithoutSnapshotsAChangedTargetDoesRescoreTheSameDays() {
        let entries = [makeEntry(date: makeTestDate(year: 2026, month: 3, day: 9), calories: 2_000)]

        let strictAnalytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 1_500),
            range: .week,
            endDate: makeTestDate(year: 2026, month: 3, day: 9)
        )

        XCTAssertEqual(
            strictAnalytics.current.count(for: .over), 1,
            "Legacy fallback intentionally still uses the current target"
        )
        XCTAssertTrue(strictAnalytics.current.hasEstimatedTargets)
    }

    func testResolverCarriesTheLastSavedGoalForwardOverDaysWithoutASnapshot() {
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 1_500,
            valuesByDayKey: [
                "2026-03-01": makeValues(target: 2_000),
                "2026-03-05": makeValues(target: 1_900),
                "2026-03-09": makeValues(target: 1_800)
            ]
        )

        let target = { (day: Int) in resolver.target(for: makeTestDate(year: 2026, month: 3, day: day)) }

        XCTAssertEqual(target(3), HistoryDayTarget(calories: 2_000, isEstimated: true))
        XCTAssertEqual(target(5), HistoryDayTarget(calories: 1_900, isEstimated: false))
        XCTAssertEqual(target(7), HistoryDayTarget(calories: 1_900, isEstimated: true))
        XCTAssertEqual(target(12), HistoryDayTarget(calories: 1_800, isEstimated: true))
    }

    func testDaysBeforeTheFirstSavedGoalUseTheEarliestGoalRatherThanTheCurrentOne() {
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 1_500,
            valuesByDayKey: [
                "2026-03-05": makeValues(target: 2_000),
                "2026-03-09": makeValues(target: 1_800)
            ]
        )

        let target = resolver.target(for: makeTestDate(year: 2026, month: 2, day: 20))

        XCTAssertEqual(target, HistoryDayTarget(calories: 2_000, isEstimated: true))
    }

    func testAStepwiseDietScoresEveryDayAgainstTheGoalInEffectThatDay() {
        let end = makeTestDate(year: 2026, month: 3, day: 14)
        let loggedCalories = [2_000, 2_000, 2_000, 1_900, 1_900, 1_900, 1_800, 1_800, 1_800, 1_700]
        let entries = loggedCalories.enumerated().map { offset, calories in
            makeEntry(date: makeTestDate(year: 2026, month: 3, day: 5 + offset), calories: Double(calories))
        }
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 1_700,
            valuesByDayKey: [
                "2026-03-05": makeValues(target: 2_000),
                "2026-03-08": makeValues(target: 1_900),
                "2026-03-11": makeValues(target: 1_800),
                "2026-03-14": makeValues(target: 1_700)
            ]
        )

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 1_700),
            range: .twoWeeks,
            endDate: end,
            targetResolver: resolver
        )
        let logged = analytics.current.days.filter(\.isLogged)

        XCTAssertEqual(logged.map(\.dailyCalorieTarget), loggedCalories)
        XCTAssertEqual(analytics.current.count(for: .onTrack), loggedCalories.count)
        XCTAssertEqual(analytics.current.count(for: .over), 0)
    }

    func testHealthAdjustedDayIsScoredAgainstTheTargetThatApplied() {
        let day = makeTestDate(year: 2026, month: 3, day: 9)
        let entries = [makeEntry(date: day, calories: 2_450)]
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 2_000,
            valuesByDayKey: ["2026-03-09": makeValues(target: 2_500)]
        )

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 2_000),
            range: .week,
            endDate: day,
            targetResolver: resolver
        )
        let daySummary = analytics.current.days.first { $0.isLogged }

        XCTAssertEqual(daySummary?.dailyCalorieTarget, 2_500)
        XCTAssertEqual(daySummary?.status, .onTrack, "Against the static 2,000 target this would read as over")
        XCTAssertEqual(daySummary?.isTargetEstimated, false)
    }

    func testMixedSnapshottedAndLegacyDaysFlagOnlyTheLegacyOnes() {
        let snapshotted = makeTestDate(year: 2026, month: 3, day: 9)
        let legacy = makeTestDate(year: 2026, month: 3, day: 8)
        let analytics = HistoryAnalytics(
            entries: [
                makeEntry(date: snapshotted, calories: 2_000),
                makeEntry(date: legacy, calories: 2_000)
            ],
            profile: makeProfile(dailyCalorieTarget: 2_000),
            range: .week,
            endDate: snapshotted,
            targetResolver: HistoryDayTargetResolver(
                fallbackTarget: 2_000,
                valuesByDayKey: ["2026-03-09": makeValues(target: 2_200)]
            )
        )

        let days = Dictionary(
            uniqueKeysWithValues: analytics.current.days.map {
                (DailyGoalSnapshot.dayKey(for: $0.date), $0)
            }
        )

        XCTAssertEqual(days["2026-03-09"]?.dailyCalorieTarget, 2_200)
        XCTAssertEqual(days["2026-03-09"]?.isTargetEstimated, false)
        XCTAssertEqual(days["2026-03-08"]?.dailyCalorieTarget, 2_200)
        XCTAssertEqual(days["2026-03-08"]?.isTargetEstimated, true)
        XCTAssertTrue(analytics.current.hasEstimatedTargets)
    }

    func testManualDaySnapshotKeepsManualSemanticsThroughHistory() {
        let day = makeTestDate(year: 2026, month: 3, day: 9)
        let manualValues = DailyGoalSnapshotValues(
            calorieTarget: 1_800,
            isManualTarget: true
        )
        let snapshot = DailyGoalSnapshot(
            dayKey: DailyGoalSnapshot.dayKey(for: day),
            values: manualValues,
            profile: makeProfile()
        )

        XCTAssertTrue(snapshot.isManualTarget)
        XCTAssertEqual(snapshot.values, manualValues)

        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: day, calories: 1_800)],
            profile: makeProfile(dailyCalorieTarget: 2_400),
            range: .week,
            endDate: day,
            targetResolver: HistoryDayTargetResolver(
                fallbackTarget: 2_400,
                valuesByDayKey: [snapshot.dayKey: snapshot.values]
            )
        )

        XCTAssertEqual(analytics.current.days.first { $0.isLogged }?.dailyCalorieTarget, 1_800)
    }

    func testUnloggedDaysWithoutSnapshotsDoNotTriggerTheEstimatedNote() {
        let day = makeTestDate(year: 2026, month: 3, day: 9)

        let analytics = HistoryAnalytics(
            entries: [makeEntry(date: day, calories: 2_000)],
            profile: makeProfile(dailyCalorieTarget: 2_000),
            range: .week,
            endDate: day,
            targetResolver: HistoryDayTargetResolver(
                fallbackTarget: 2_000,
                valuesByDayKey: ["2026-03-09": makeValues(target: 2_000)]
            )
        )

        XCTAssertEqual(analytics.current.count(for: .notLogged), 6)
        XCTAssertFalse(
            analytics.current.hasEstimatedTargets,
            "Unlogged days are never compared, so they must not warn about precision"
        )
    }

    func testWeeklyRollupUsesPerDayTargetsRatherThanTheCurrentProfile() {
        let end = makeTestDate(year: 2026, month: 3, day: 9)
        var valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
        var entries: [FoodLogEntry] = []
        for offset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: end)!
            valuesByDayKey[DailyGoalSnapshot.dayKey(for: date)] = makeValues(target: 2_200)
            entries.append(makeEntry(date: date, calories: 2_200))
        }

        let analytics = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 1_500),
            range: .month,
            endDate: end,
            targetResolver: HistoryDayTargetResolver(fallbackTarget: 1_500, valuesByDayKey: valuesByDayKey)
        )

        let loggedWeek = analytics.current.weeklyRollups.first { $0.loggedDays > 0 }
        XCTAssertEqual(loggedWeek?.targetPerLoggedDay, 2_200)
        XCTAssertEqual(loggedWeek?.onTrackDays, loggedWeek?.loggedDays)
        XCTAssertEqual(loggedWeek?.hasEstimatedTargets, false)
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DailyGoalSnapshot.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeValues(target: Int) -> DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            calorieTarget: target,
            isManualTarget: false
        )
    }

    private func makeProfile(dailyCalorieTarget: Int = 2_000) -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: dailyCalorieTarget
        )
    }

    private func makeEntry(date: Date, calories: Double) -> FoodLogEntry {
        makeTestEntry(
            date: date,
            mealType: .breakfast,
            foodItem: makeTestFoodItem(name: "Test Food", caloriesPer100g: calories),
            portionGrams: 100
        )
    }
}
