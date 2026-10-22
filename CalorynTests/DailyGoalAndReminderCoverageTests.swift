import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Caloryn

private func goalCalendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

private func goalDate(
    _ calendar: Calendar,
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int = 12,
    _ minute: Int = 0
) -> Date {
    calendar.date(from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute
    ))!
}

private func goalValues(target: Int) -> DailyGoalSnapshotValues {
    DailyGoalSnapshotValues(
        calorieTarget: target,
        isManualTarget: false
    )
}

@MainActor
@Suite("Daily goal snapshot store: duplicates and time zones")
struct DailyGoalSnapshotStoreCoverageTests {
    private let utc = goalCalendar("UTC")
    private let auckland = goalCalendar("Pacific/Auckland")

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DailyGoalSnapshot.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .female,
            heightCm: 168,
            weightKg: 62,
            activityLevel: .lightlyActive,
            dailyCalorieTarget: 1_900
        )
    }

    @Test("Recording over CloudKit duplicates keeps only the most recently updated one")
    func recordingRemovesDuplicates() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let now = goalDate(utc, 2026, 3, 9, 20)
        let older = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 1_900),
            profile: profile, recordedAt: goalDate(utc, 2026, 3, 9, 8)
        )
        let newer = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 2_050),
            profile: profile, recordedAt: goalDate(utc, 2026, 3, 9, 18)
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let didRecord = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_050),
            for: now, profile: profile, in: context, now: now, calendar: utc
        )

        #expect(didRecord)
        let stored = try context.fetch(FetchDescriptor<DailyGoalSnapshot>())
        #expect(stored.count == 1)
        #expect(stored.first?.id == newer.id)
        #expect(stored.first?.effectiveCalorieTarget == 2_050)
        #expect(stored.first?.updatedAt == goalDate(utc, 2026, 3, 9, 18))
    }

    @Test("Updating a snapshot stamps the new recording time and profile revision")
    func updateStampsRecordingTime() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let morning = goalDate(utc, 2026, 3, 9, 8)
        let evening = goalDate(utc, 2026, 3, 9, 21)

        DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 1_900),
            for: morning, profile: nil, in: context, now: morning, calendar: utc
        )
        let didUpdate = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 1_900),
            for: evening, profile: profile, in: context, now: evening, calendar: utc
        )

        #expect(didUpdate, "A different goal revision is a change even with equal numbers")
        let stored = try #require(try context.fetch(FetchDescriptor<DailyGoalSnapshot>()).first)
        #expect(stored.createdAt == morning)
        #expect(stored.updatedAt == evening)
        #expect(stored.goalRevisionID == profile.id)
        #expect(stored.goalRevisionUpdatedAt == profile.updatedAt)
    }

    @Test("Editing the same profile is a new goal revision even when the numbers match")
    func editedProfileIsANewRevision() throws {
        let context = try makeContext()
        let profile = makeProfile()
        context.insert(profile)
        let firstEdit = goalDate(utc, 2026, 3, 9, 7)
        let secondEdit = goalDate(utc, 2026, 3, 9, 15)
        let morning = goalDate(utc, 2026, 3, 9, 8)
        let evening = goalDate(utc, 2026, 3, 9, 21)
        profile.updatedAt = firstEdit

        DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 1_900),
            for: morning, profile: profile, in: context, now: morning, calendar: utc
        )
        profile.updatedAt = secondEdit
        let didUpdate = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 1_900),
            for: evening, profile: profile, in: context, now: evening, calendar: utc
        )

        #expect(didUpdate)
        let stored = try #require(try context.fetch(FetchDescriptor<DailyGoalSnapshot>()).first)
        #expect(stored.goalRevisionUpdatedAt == secondEdit)
        #expect(stored.updatedAt == evening)
    }

    @Test("Whether a date is today depends on the injected calendar's time zone")
    func todayIsJudgedInTheInjectedTimeZone() throws {
        let context = try makeContext()
        let now = goalDate(utc, 2026, 3, 9, 10)
        let date = goalDate(utc, 2026, 3, 9, 12)

        let recordedInAuckland = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_000),
            for: date, profile: nil, in: context, now: now, calendar: auckland
        )
        let recordedInUTC = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_000),
            for: date, profile: nil, in: context, now: now, calendar: utc
        )

        #expect(!recordedInAuckland)
        #expect(recordedInUTC)
        let keys = try context.fetch(FetchDescriptor<DailyGoalSnapshot>()).map(\.dayKey)
        #expect(keys == ["2026-03-09"])
    }

    @Test("Crossing local midnight moves recording to a new day key")
    func midnightStartsANewKey() throws {
        let context = try makeContext()
        let lateEvening = goalDate(auckland, 2026, 3, 9, 23, 59)
        let justAfterMidnight = goalDate(auckland, 2026, 3, 10, 0, 0)

        DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_000),
            for: lateEvening, profile: nil, in: context, now: lateEvening, calendar: auckland
        )
        DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_000),
            for: justAfterMidnight, profile: nil, in: context, now: justAfterMidnight, calendar: auckland
        )
        let rewroteYesterday = DailyGoalSnapshotStore.recordSnapshot(
            values: goalValues(target: 2_500),
            for: lateEvening, profile: nil, in: context, now: justAfterMidnight, calendar: auckland
        )

        #expect(!rewroteYesterday)
        let stored = try context.fetch(FetchDescriptor<DailyGoalSnapshot>())
        #expect(Set(stored.map(\.dayKey)) == ["2026-03-09", "2026-03-10"])
        #expect(stored.allSatisfy { $0.effectiveCalorieTarget == 2_000 })
    }

    @Test("Collapsing keeps the newer snapshot even when the older one comes later in the list")
    func collapseIsOrderIndependent() {
        let older = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 2_000),
            profile: nil, recordedAt: goalDate(utc, 2026, 3, 9, 8)
        )
        let newer = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 2_300),
            profile: nil, recordedAt: goalDate(utc, 2026, 3, 9, 20)
        )
        let otherDay = DailyGoalSnapshot(
            dayKey: "2026-03-10", values: goalValues(target: 1_800),
            profile: nil, recordedAt: goalDate(utc, 2026, 3, 10, 9)
        )

        let collapsed = DailyGoalSnapshotStore.latestValuesByDayKey([newer, otherDay, older])

        #expect(collapsed.count == 2)
        #expect(collapsed["2026-03-09"]?.calorieTarget == 2_300)
        #expect(collapsed["2026-03-10"]?.calorieTarget == 1_800)
    }

    @Test("When two duplicates share a timestamp the first one seen wins")
    func collapseTieKeepsFirst() {
        let stamp = goalDate(utc, 2026, 3, 9, 8)
        let first = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 2_100),
            profile: nil, recordedAt: stamp
        )
        let second = DailyGoalSnapshot(
            dayKey: "2026-03-09", values: goalValues(target: 2_200),
            profile: nil, recordedAt: stamp
        )

        #expect(DailyGoalSnapshotStore.latestValuesByDayKey([first, second])["2026-03-09"]?.calorieTarget == 2_100)
        #expect(DailyGoalSnapshotStore.latestValuesByDayKey([second, first])["2026-03-09"]?.calorieTarget == 2_200)
    }

    @Test("No snapshots collapse to no values")
    func collapseEmpty() {
        #expect(DailyGoalSnapshotStore.latestValuesByDayKey([]).isEmpty)
    }
}

@Suite("History day target resolution across time zones")
struct HistoryDayTargetResolverCoverageTests {
    @Test("A snapshot keyed in the local day is found only through that day's calendar")
    func lookupUsesTheInjectedCalendar() {
        let utc = goalCalendar("UTC")
        let auckland = goalCalendar("Pacific/Auckland")
        let instant = goalDate(utc, 2026, 3, 9, 12)
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 1_800,
            valuesByDayKey: ["2026-03-10": goalValues(target: 2_250)]
        )

        #expect(resolver.target(for: instant, calendar: auckland) == HistoryDayTarget(calories: 2_250, isEstimated: false))
        #expect(resolver.target(for: instant, calendar: utc) == HistoryDayTarget(calories: 1_800, isEstimated: true))
    }

    @Test("A manual snapshot resolves to its effective target, not the fallback")
    func manualSnapshot() {
        let utc = goalCalendar("UTC")
        let manual = DailyGoalSnapshotValues(
            calorieTarget: 1_500, isManualTarget: true
        )
        let resolver = HistoryDayTargetResolver(fallbackTarget: 2_200, valuesByDayKey: ["2026-01-01": manual])

        #expect(resolver.target(for: goalDate(utc, 2026, 1, 1, 23, 59), calendar: utc).calories == 1_500)
        #expect(resolver.fallbackTarget == 2_200)
    }
}

@Suite("Daily reminder planner: time zones, configurable time and the skip threshold")
struct DailyReminderPlannerCoverageTests {
    private let tokyo = goalCalendar("Asia/Tokyo")
    private let honolulu = goalCalendar("Pacific/Honolulu")
    private let newYork = goalCalendar("America/New_York")

    @Test("The same instant plans from a different calendar day in each time zone")
    func timeZoneDecidesToday() {
        let now = goalDate(tokyo, 2026, 7, 15, 12)

        let tokyoPlan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 400, fullDayTarget: 2_000, now: now, calendar: tokyo
        )
        let honoluluPlan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 400, fullDayTarget: 2_000, now: now, calendar: honolulu
        )

        #expect(tokyoPlan.first?.identifier == "daily-reminder-2026-07-15")
        #expect(honoluluPlan.first?.identifier == "daily-reminder-2026-07-14")
        #expect(tokyoPlan.first?.fireDateComponents == DateComponents(year: 2026, month: 7, day: 15, hour: 21, minute: 0))
        #expect(honoluluPlan.first?.fireDateComponents == DateComponents(year: 2026, month: 7, day: 14, hour: 21, minute: 0))
        #expect(tokyoPlan.first?.title == "🔥 400 calories to go")
    }

    @Test("Reminders keep their local wall-clock time across a daylight-saving change")
    func wallClockSurvivesDST() {
        let now = goalDate(newYork, 2026, 3, 7, 12)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 500, fullDayTarget: 2_000,
            reminderMinutesFromMidnight: 20 * 60 + 30, now: now, calendar: newYork
        )

        #expect(plan.count == 7)
        #expect(plan.map(\.fireDateComponents.day) == [7, 8, 9, 10, 11, 12, 13])
        #expect(plan.allSatisfy { $0.fireDateComponents.hour == 20 && $0.fireDateComponents.minute == 30 })
    }

    @Test("A plan made late in the year runs on into the next year")
    func yearRollover() {
        let now = goalDate(tokyo, 2026, 12, 29, 9)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 500, fullDayTarget: 2_000, now: now, calendar: tokyo
        )

        #expect(plan.map(\.identifier) == [
            "daily-reminder-2026-12-29", "daily-reminder-2026-12-30", "daily-reminder-2026-12-31",
            "daily-reminder-2027-01-01", "daily-reminder-2027-01-02", "daily-reminder-2027-01-03",
            "daily-reminder-2027-01-04",
        ])
    }

    @Test(
        "The configured minutes become the fire hour and minute",
        arguments: [
            (0, 0, 0),
            (1, 0, 1),
            (59, 0, 59),
            (60, 1, 0),
            (13 * 60 + 5, 13, 5),
            (23 * 60 + 59, 23, 59),
        ]
    )
    func minutesBecomeHourAndMinute(minutes: Int, hour: Int, minute: Int) {
        let now = goalDate(tokyo, 2026, 7, 15, 0, 0)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 500, fullDayTarget: 2_000,
            reminderMinutesFromMidnight: minutes, now: now, calendar: tokyo
        )

        #expect(plan.allSatisfy { $0.fireDateComponents.hour == hour && $0.fireDateComponents.minute == minute })
        let expectedFirstDay = minutes == 0 ? 16 : 15
        #expect(plan.first?.fireDateComponents.day == expectedFirstDay)
        #expect(plan.count == (minutes == 0 ? 6 : 7))
    }

    @Test(
        "Today's reminder is kept at the threshold and dropped one below it",
        arguments: [(98, false), (99, false), (100, true), (101, true)]
    )
    func todayThreshold(remaining: Int, keepsToday: Bool) {
        let now = goalDate(tokyo, 2026, 7, 15, 12)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: remaining, fullDayTarget: 2_000, now: now, calendar: tokyo
        )

        #expect((plan.first?.identifier == "daily-reminder-2026-07-15") == keepsToday)
        #expect(plan.count == (keepsToday ? 7 : 6))
    }

    @Test("A full-day target below the threshold silences every future day")
    func smallTargetSilencesFutureDays() {
        let now = goalDate(tokyo, 2026, 7, 15, 12)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 150, fullDayTarget: 99, now: now, calendar: tokyo
        )

        #expect(plan.map(\.identifier) == ["daily-reminder-2026-07-15"])
        #expect(plan.first?.title == "🔥 150 calories to go")
    }

    @Test("Without a figure for today, today falls back to the full target", arguments: [2_000, 100])
    func missingRemainingUsesFullTarget(target: Int) {
        let now = goalDate(tokyo, 2026, 7, 15, 12)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: nil, fullDayTarget: target, now: now, calendar: tokyo
        )

        #expect(plan.count == 7)
        #expect(plan.allSatisfy { $0.title == "🔥 \(target) calories to go" })
    }

    @Test("A zero or negative target plans nothing", arguments: [0, -1, -2_000])
    func nonPositiveTarget(target: Int) {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: 500, fullDayTarget: target,
            now: goalDate(tokyo, 2026, 7, 15, 12), calendar: tokyo
        )

        #expect(plan.isEmpty)
    }

    @Test("Identifiers zero-pad the month and day in the given calendar")
    func identifierPadding() {
        #expect(DailyReminderPlanner.identifier(for: goalDate(tokyo, 2026, 1, 5), calendar: tokyo) == "daily-reminder-2026-01-05")
        #expect(
            DailyReminderPlanner.identifier(for: goalDate(tokyo, 2026, 1, 1, 1), calendar: honolulu)
                == "daily-reminder-2025-12-31"
        )
    }

    @Test(
        "Remaining calories round the consumed total and floor at zero",
        arguments: [
            (2_000, 0.0, 2_000),
            (2_000, 1_499.4, 501),
            (2_000, 1_499.5, 500),
            (2_000, 1_999.6, 0),
            (2_000, 2_400.0, 0),
            (0, 0.0, 0),
            (2_000_000_000, 0.0, 1_000_000_000),
        ]
    )
    func remainingToday(target: Int, consumed: Double, expected: Int) {
        #expect(DailyReminderPlanner.remainingToday(target: target, consumed: consumed) == expected)
    }

    @Test("A non-finite consumed total is treated as nothing eaten")
    func nonFiniteConsumed() {
        #expect(DailyReminderPlanner.remainingToday(target: 2_000, consumed: .infinity) == 2_000)
        #expect(DailyReminderPlanner.remainingToday(target: 2_000, consumed: .nan) == 2_000)
    }
}

private final class CoverageReminderCenter: ReminderNotificationCenter, @unchecked Sendable {
    var status: UNAuthorizationStatus = .authorized
    var pending: [String] = []
    var addedRequests: [UNNotificationRequest] = []
    var authorizationQueries = 0
    var failingIdentifiers: Set<String> = []

    func authorizationStatus() async -> UNAuthorizationStatus {
        authorizationQueries += 1
        return status
    }

    func pendingReminderIdentifiers() async -> [String] { pending }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        pending.removeAll { identifiers.contains($0) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        if failingIdentifiers.contains(request.identifier) {
            throw CocoaError(.featureUnsupported)
        }
        addedRequests.append(request)
        pending.append(request.identifier)
    }
}

@MainActor
@Suite("Daily reminder scheduler: authorization states and retries")
struct DailyReminderSchedulerCoverageTests {
    private let tokyo = goalCalendar("Asia/Tokyo")

    private func plan(remaining: Int = 450) -> [PlannedReminder] {
        DailyReminderPlanner.makePlan(
            isEnabled: true, remainingToday: remaining, fullDayTarget: 2_000,
            now: goalDate(tokyo, 2026, 7, 15, 12), calendar: tokyo
        )
    }

    @Test(
        "Anything short of full authorization schedules nothing and clears what is pending",
        arguments: [UNAuthorizationStatus.notDetermined, .denied, .provisional, .ephemeral]
    )
    func nonAuthorizedStatuses(status: UNAuthorizationStatus) async {
        let center = CoverageReminderCenter()
        center.status = status
        center.pending = ["daily-reminder-2026-07-14"]
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(plan())

        #expect(center.addedRequests.isEmpty)
        #expect(center.pending.isEmpty)
    }

    @Test("After a refused apply, granting permission lets the same plan through without forcing")
    func refusedApplyDoesNotCacheThePlan() async {
        let center = CoverageReminderCenter()
        center.status = .denied
        let scheduler = DailyReminderScheduler(center: center)
        let reminders = plan()

        await scheduler.apply(reminders)
        center.status = .authorized
        await scheduler.apply(reminders)

        #expect(center.addedRequests.map(\.identifier) == reminders.map(\.identifier))
    }

    @Test("Scheduled requests carry the plan's copy, a sound and a one-shot calendar trigger")
    func requestContent() async throws {
        let center = CoverageReminderCenter()
        let scheduler = DailyReminderScheduler(center: center)
        let reminders = plan(remaining: 320)

        await scheduler.apply(reminders)

        let first = try #require(center.addedRequests.first)
        #expect(first.content.title == "🔥 320 calories to go")
        #expect(first.content.body == "There's still time to log a meal and reach today's goal.")
        #expect(first.content.sound == .default)
        let trigger = try #require(first.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats == false)
        #expect(trigger.dateComponents == DateComponents(year: 2026, month: 7, day: 15, hour: 21, minute: 0))
    }

    @Test("One failed day does not stop the rest, and the next apply retries the whole plan")
    func partialFailureRetries() async {
        let center = CoverageReminderCenter()
        let reminders = plan()
        center.failingIdentifiers = [reminders[2].identifier]
        let scheduler = DailyReminderScheduler(center: center)

        await scheduler.apply(reminders)
        #expect(center.addedRequests.count == reminders.count - 1)

        center.failingIdentifiers = []
        await scheduler.apply(reminders)

        #expect(Set(center.pending) == Set(reminders.map(\.identifier)))
        #expect(center.pending.count == reminders.count)
    }

    @Test("Forcing an unchanged plan re-checks permission and re-schedules it")
    func forceReapplies() async {
        let center = CoverageReminderCenter()
        let scheduler = DailyReminderScheduler(center: center)
        let reminders = plan()

        await scheduler.apply(reminders)
        await scheduler.apply(reminders)
        #expect(center.authorizationQueries == 1)

        await scheduler.apply(reminders, force: true)

        #expect(center.authorizationQueries == 2)
        #expect(center.addedRequests.count == reminders.count * 2)
        #expect(center.pending.count == reminders.count)
    }
}
