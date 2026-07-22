import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class DailyGoalSnapshotTests: XCTestCase {

    // MARK: Day identity

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

    // MARK: Shared effective-target definition

    func testSnapshotValuesMatchTheBudgetTodayDisplays() {
        let budget = makeBudget(staticTarget: 2_000, mode: .lifestyleEstimate)
        let values = budget.goalSnapshotValues

        XCTAssertEqual(values.effectiveCalorieTarget, budget.adjustedTarget)
        XCTAssertEqual(values.baseCalorieTarget, budget.baseTarget)
        XCTAssertEqual(values.healthAdjustment, 0)
        XCTAssertFalse(values.isManualTarget)
    }

    func testHealthAdjustedSnapshotAlwaysReconstructsTheEffectiveTarget() {
        let budget = makeBudget(
            staticTarget: 2_000,
            mode: .dynamicHealth,
            activeEnergyKcal: 700,
            samples: makeReadySamples(baseline: 400)
        )
        let values = budget.goalSnapshotValues

        XCTAssertEqual(values.effectiveCalorieTarget, budget.adjustedTarget)
        XCTAssertEqual(
            values.baseCalorieTarget + values.healthAdjustment,
            values.effectiveCalorieTarget
        )
        XCTAssertNotEqual(values.healthAdjustment, 0, "A ready dynamic day should carry an adjustment")
    }

    func testManualBudgetSnapshotPreservesManualSemantics() {
        let budget = makeBudget(staticTarget: 1_800, mode: .lifestyleEstimate, isManualOverride: true)
        let values = budget.goalSnapshotValues

        XCTAssertTrue(values.isManualTarget)
        XCTAssertEqual(values.baseCalorieTarget, 1_800)
        XCTAssertEqual(values.effectiveCalorieTarget, 1_800)
        XCTAssertEqual(values.healthAdjustment, 0, "Manual days never take a Health adjustment")
    }

    // MARK: Store upsert behavior

    func testRecordingCreatesOneSnapshotForTheCurrentDay() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)

        let didRecord = DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(base: 2_000, adjustment: 0),
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
            values: makeValues(base: 2_000, adjustment: 0),
            for: today,
            profile: profile,
            in: context,
            now: today
        )
        DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(base: 2_000, adjustment: 250),
            for: today,
            profile: profile,
            in: context,
            now: today
        )

        let stored = try context.fetch(FetchDescriptor<DailyGoalSnapshot>())
        XCTAssertEqual(stored.count, 1, "One canonical snapshot per calendar day")
        XCTAssertEqual(stored.first?.effectiveCalorieTarget, 2_250)
        XCTAssertEqual(stored.first?.healthAdjustment, 250)
    }

    func testRecordingUnchangedValuesDoesNotRewriteTheSnapshot() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let today = makeTestDate(year: 2026, month: 3, day: 9)
        let values = makeValues(base: 2_000, adjustment: 0)

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
            values: makeValues(base: 2_000, adjustment: 0),
            for: yesterday, profile: profile, in: context, now: today
        )
        let recordedFuture = DailyGoalSnapshotStore.recordSnapshot(
            values: makeValues(base: 2_000, adjustment: 0),
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
            values: makeValues(base: 2_000, adjustment: 0),
            profile: profile,
            recordedAt: makeTestDate(year: 2026, month: 3, day: 9, hour: 8)
        )
        let newer = DailyGoalSnapshot(
            dayKey: "2026-03-09",
            values: makeValues(base: 2_000, adjustment: 300),
            profile: profile,
            recordedAt: makeTestDate(year: 2026, month: 3, day: 9, hour: 20)
        )

        let collapsed = DailyGoalSnapshotStore.latestValuesByDayKey([older, newer])

        XCTAssertEqual(collapsed.count, 1)
        XCTAssertEqual(collapsed["2026-03-09"]?.effectiveCalorieTarget, 2_300)
    }

    // MARK: Target resolution

    func testResolverUsesTheSnapshotWhenOneExists() {
        let date = makeTestDate(year: 2026, month: 3, day: 9)
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 2_000,
            valuesByDayKey: ["2026-03-09": makeValues(base: 2_000, adjustment: 400)]
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

    // MARK: History date accuracy

    func testChangingTheProfileTargetDoesNotChangeSnapshottedDayStatus() {
        let entries = [
            makeEntry(date: makeTestDate(year: 2026, month: 3, day: 9), calories: 2_000),
            makeEntry(date: makeTestDate(year: 2026, month: 3, day: 8), calories: 2_000)
        ]
        let snapshots = [
            "2026-03-09": makeValues(base: 2_000, adjustment: 0),
            "2026-03-08": makeValues(base: 2_000, adjustment: 0)
        ]

        let beforeChange = HistoryAnalytics(
            entries: entries,
            profile: makeProfile(dailyCalorieTarget: 2_000),
            range: .week,
            endDate: makeTestDate(year: 2026, month: 3, day: 9),
            targetResolver: HistoryDayTargetResolver(fallbackTarget: 2_000, valuesByDayKey: snapshots)
        )
        // The user later drops their target to 1,500. The same past days must
        // keep the status they were given when they were lived.
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

    func testHealthAdjustedDayIsScoredAgainstTheTargetThatApplied() {
        let day = makeTestDate(year: 2026, month: 3, day: 9)
        // 2,450 kcal eaten on a day whose target was raised to 2,500 by Health.
        let entries = [makeEntry(date: day, calories: 2_450)]
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 2_000,
            valuesByDayKey: ["2026-03-09": makeValues(base: 2_000, adjustment: 500)]
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
                valuesByDayKey: ["2026-03-09": makeValues(base: 2_200, adjustment: 0)]
            )
        )

        let days = Dictionary(
            uniqueKeysWithValues: analytics.current.days.map {
                (DailyGoalSnapshot.dayKey(for: $0.date), $0)
            }
        )

        XCTAssertEqual(days["2026-03-09"]?.dailyCalorieTarget, 2_200)
        XCTAssertEqual(days["2026-03-09"]?.isTargetEstimated, false)
        XCTAssertEqual(days["2026-03-08"]?.dailyCalorieTarget, 2_000)
        XCTAssertEqual(days["2026-03-08"]?.isTargetEstimated, true)
        XCTAssertTrue(analytics.current.hasEstimatedTargets)
    }

    func testManualDaySnapshotKeepsManualSemanticsThroughHistory() {
        let day = makeTestDate(year: 2026, month: 3, day: 9)
        let manualValues = DailyGoalSnapshotValues(
            baseCalorieTarget: 1_800,
            healthAdjustment: 0,
            effectiveCalorieTarget: 1_800,
            calculationMode: .lifestyleEstimate,
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
                valuesByDayKey: ["2026-03-09": makeValues(base: 2_000, adjustment: 0)]
            )
        )

        XCTAssertEqual(analytics.current.count(for: .notLogged), 6)
        XCTAssertFalse(
            analytics.current.hasEstimatedTargets,
            "Unlogged days are never compared, so they must not warn about precision"
        )
    }

    // MARK: Weekly rollups

    func testWeeklyRollupUsesPerDayTargetsRatherThanTheCurrentProfile() {
        let end = makeTestDate(year: 2026, month: 3, day: 9)
        var valuesByDayKey: [String: DailyGoalSnapshotValues] = [:]
        var entries: [FoodLogEntry] = []
        for offset in 0..<7 {
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: end)!
            valuesByDayKey[DailyGoalSnapshot.dayKey(for: date)] = makeValues(base: 2_000, adjustment: 200)
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

    // MARK: Helpers

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DailyGoalSnapshot.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeValues(base: Int, adjustment: Int) -> DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            baseCalorieTarget: base,
            healthAdjustment: adjustment,
            effectiveCalorieTarget: base + adjustment,
            calculationMode: adjustment == 0 ? .lifestyleEstimate : .dynamicHealth,
            isManualTarget: false
        )
    }

    private func makeReadySamples(baseline: Double) -> [DailyActiveEnergySample] {
        (1...ActivityCalorieBudget.requiredDynamicActivityDays).map { offset in
            DailyActiveEnergySample(
                date: makeTestDate(year: 2026, month: 3, day: 9 - offset),
                activeEnergyKcal: baseline
            )
        }
    }

    private func makeBudget(
        staticTarget: Int,
        mode: EnergyCalculationMode,
        isManualOverride: Bool = false,
        activeEnergyKcal: Double = 0,
        samples: [DailyActiveEnergySample] = []
    ) -> ActivityCalorieBudget {
        ActivityCalorieBudget(
            consumed: 0,
            staticTarget: staticTarget,
            bmr: 1_700,
            calorieDeficit: 500,
            activeEnergyKcal: activeEnergyKcal,
            recentActiveEnergySamples: samples,
            calculationMode: mode,
            isManualOverride: isManualOverride,
            isActivityLoading: false,
            activityMessage: nil,
            date: makeTestDate(year: 2026, month: 3, day: 9)
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
