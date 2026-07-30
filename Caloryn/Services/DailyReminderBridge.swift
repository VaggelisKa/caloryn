import SwiftData
import SwiftUI

/// Invisible view that keeps pending daily-reminder notifications in sync
/// with today's log and the reminder settings. Notification content is baked
/// in at scheduling time, so every relevant change re-plans the pending
/// requests — the same pattern as WidgetSnapshotBridge. All meal writes
/// happen in this process (the quick-log widget is deep-link only), so no
/// background refresh is needed.
struct DailyReminderBridge: View {
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]
    @AppStorage("dailyReminderEnabled") private var isEnabled = false
    @AppStorage("dailyReminderMinutesFromMidnight") private var reminderMinutes = DailyReminderPlanner.defaultReminderMinutes
    @State private var scheduler = DailyReminderScheduler()

    private var currentPlan: [PlannedReminder] {
        let target = profiles.first?.dailyCalorieTarget
        let consumedToday = allEntries
            .filter { $0.date.isToday }
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
                // Re-plan on foreground: crossing midnight, the reminder time,
                // or a timezone change shifts the plan without any data change.
                // Forcing also re-checks authorization, so permission revoked
                // in iOS Settings clears the pending reminders here.
                guard newPhase == .active else { return }
                Task {
                    await scheduler.apply(currentPlan, force: true)
                }
            }
    }
}
