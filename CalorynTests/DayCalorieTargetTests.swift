import Foundation
import Testing
@testable import Caloryn

@Suite("The calorie target a day on the Today screen is measured against")
@MainActor
struct DayCalorieTargetTests {
    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func date(_ day: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private static let saved = HistoryDayTargetResolver(
        fallbackTarget: 1_800,
        valuesByDayKey: [
            "2026-03-01": DailyGoalSnapshotValues(calorieTarget: 2_000, isManualTarget: false),
            "2026-03-05": DailyGoalSnapshotValues(calorieTarget: 1_900, isManualTarget: false),
            "2026-03-10": DailyGoalSnapshotValues(calorieTarget: 1_850, isManualTarget: false)
        ]
    )

    private func target(for day: Int, today: Int = 10, savedTargets: HistoryDayTargetResolver = saved) -> Int {
        DayCalorieTarget.calories(
            for: Self.date(day),
            today: Self.date(today, hour: 8),
            currentTarget: 1_800,
            savedTargets: savedTargets,
            calendar: Self.utc
        )
    }

    @Test("given a past day with a saved goal, when the goal has since been lowered, then the day keeps the goal it had")
    func pastDayKeepsItsSavedGoal() {
        #expect(target(for: 1) == 2_000)
        #expect(target(for: 5) == 1_900)
    }

    @Test("given a past day without a saved goal, when showing it, then it uses the goal in effect at the time")
    func pastDayWithoutASavedGoalUsesTheGoalInEffect() {
        #expect(target(for: 3) == 2_000)
        #expect(target(for: 8) == 1_900)
    }

    @Test("given the goal was changed today, when showing today, then today uses the new goal rather than the one saved earlier today")
    func todayUsesTheCurrentGoal() {
        #expect(target(for: 10) == 1_800)
    }

    @Test("given a future day, when showing it, then it uses the current goal")
    func futureDayUsesTheCurrentGoal() {
        #expect(target(for: 12) == 1_800)
    }

    @Test("given no goal was ever saved, when showing a past day, then it uses the current goal")
    func noSavedGoalsFallsBackToTheCurrentGoal() {
        #expect(target(for: 3, savedTargets: HistoryDayTargetResolver(fallbackTarget: 1_800)) == 1_800)
    }
}
