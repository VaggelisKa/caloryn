import XCTest
@testable import Caloryn

final class DailyReminderPlannerTests: XCTestCase {
    // makeTestDate defaults to 12:00 local time.
    private let noon = makeTestDate(year: 2026, month: 7, day: 15)

    func testDisabledProducesEmptyPlan() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: false,
            remainingToday: 500,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertTrue(plan.isEmpty)
    }

    func testMissingTargetProducesEmptyPlan() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: nil,
            fullDayTarget: nil,
            now: noon
        )

        XCTAssertTrue(plan.isEmpty)
    }

    func testPlanCoversSevenDaysWhenBeforeReminderTime() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.identifier, "daily-reminder-2026-07-15")
        XCTAssertEqual(plan.first?.title, "🔥 450 calories to go")
        XCTAssertEqual(plan.first?.body, "There's still time to log a meal and reach today's goal.")
        XCTAssertEqual(plan.last?.identifier, "daily-reminder-2026-07-21")
        XCTAssertEqual(plan.last?.title, "🔥 2000 calories to go")
    }

    func testFutureDaysAssumeFullTargetRemaining() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            now: noon
        )

        for reminder in plan.dropFirst() {
            XCTAssertEqual(reminder.title, "🔥 2000 calories to go")
        }
    }

    func testFireTimeMatchesConfiguredMinutes() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            reminderMinutesFromMidnight: 19 * 60 + 30,
            now: noon
        )

        XCTAssertEqual(plan.first?.fireDateComponents.day, 15)
        XCTAssertEqual(plan.first?.fireDateComponents.hour, 19)
        XCTAssertEqual(plan.first?.fireDateComponents.minute, 30)
    }

    func testDefaultReminderTimeIsNineInTheEvening() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertEqual(plan.first?.fireDateComponents.hour, 21)
        XCTAssertEqual(plan.first?.fireDateComponents.minute, 0)
    }

    func testTodaySkippedWhenPastReminderTime() {
        let evening = makeTestDate(year: 2026, month: 7, day: 15, hour: 21, minute: 30)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            now: evening
        )

        XCTAssertEqual(plan.count, 6)
        XCTAssertEqual(plan.first?.identifier, "daily-reminder-2026-07-16")
    }

    func testTodaySkippedAtExactReminderTime() {
        let nine = makeTestDate(year: 2026, month: 7, day: 15, hour: 21, minute: 0)

        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 450,
            fullDayTarget: 2_000,
            now: nine
        )

        XCTAssertEqual(plan.first?.identifier, "daily-reminder-2026-07-16")
    }

    func testTodaySkippedWhenRemainingBelowThreshold() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 99,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertEqual(plan.count, 6)
        XCTAssertEqual(plan.first?.identifier, "daily-reminder-2026-07-16")
    }

    func testTodayIncludedAtExactThreshold() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 100,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertEqual(plan.count, 7)
        XCTAssertEqual(plan.first?.title, "🔥 100 calories to go")
    }

    func testGoalReachedSkipsToday() {
        let plan = DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: 0,
            fullDayTarget: 2_000,
            now: noon
        )

        XCTAssertEqual(plan.count, 6)
        XCTAssertEqual(plan.first?.identifier, "daily-reminder-2026-07-16")
    }
}
