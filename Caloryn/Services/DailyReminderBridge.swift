import SwiftData
import SwiftUI

struct DailyReminderBridge: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query(filter: FoodLogEntryWindow.loggedSince(FoodLogEntryWindow.recentStart(now: .now, calendar: .current)))
    private var recentEntries: [FoodLogEntry]
    @AppStorage("dailyReminderEnabled") private var isEnabled = false
    @AppStorage("dailyReminderMinutesFromMidnight") private var reminderMinutes = DailyReminderPlanner.defaultReminderMinutes
    @State private var scheduler = DailyReminderScheduler()

    private var currentPlan: [PlannedReminder] {
        let target = profiles.first?.dailyCalorieTarget
        let consumedToday = DayFoodLogSelection.entries(recentEntries, on: .now, date: \.date)
            .reduce(0) { $0 + $1.calories }

        return DailyReminderPlanner.makePlan(
            isEnabled: isEnabled,
            remainingToday: target.map {
                DailyReminderPlanner.remainingToday(target: $0, consumed: consumedToday)
            },
            fullDayTarget: target,
            reminderMinutesFromMidnight: reminderMinutes
        )
    }

    var body: some View {
        let plan = currentPlan

        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: plan) {
                await scheduler.apply(plan)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await scheduler.apply(currentPlan, force: true)
                }
            }
    }
}
