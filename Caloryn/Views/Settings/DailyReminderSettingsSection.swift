import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

/// Settings section for the daily remaining-calories reminder: opt-in toggle
/// (which drives the system permission prompt), reminder-time picker, and a
/// recovery path when permission is denied at the system level.
struct DailyReminderSettingsSection: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("dailyReminderEnabled") private var isEnabled = false
    @AppStorage("dailyReminderMinutesFromMidnight") private var reminderMinutes = DailyReminderPlanner.defaultReminderMinutes
    @State private var isPermissionDenied = false

    var body: some View {
        Section {
            Toggle(isOn: enableBinding) {
                Label("Daily Reminder", systemImage: "bell.badge")
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .tint(CalorynTheme.sage)

            if isEnabled {
                DatePicker(
                    "Remind me at",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .foregroundStyle(CalorynTheme.textPrimary)
                .tint(CalorynTheme.sage)
            }

            if isPermissionDenied {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notifications are turned off for Caloryn in iOS Settings. Allow them there to receive the daily reminder.")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openNotificationSettings()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "gearshape")
                                .font(CalorynTheme.compactIcon)
                                .accessibilityHidden(true)

                            Text("Open App Settings")
                        }
                    }
                    .font(CalorynTheme.caption)
                    .buttonStyle(.borderless)
                    .tint(CalorynTheme.sage)
                    .accessibilityLabel("Open app settings")
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get one reminder a day with how many calories you have left to reach your goal. It skips days when you're within \(DailyReminderPlanner.minimumRemainingKcal) calories of your goal.")
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await refreshPermissionState()
        }
    }

    private var enableBinding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { wantsOn in
                guard wantsOn else {
                    isEnabled = false
                    return
                }

                Task {
                    await enableReminder()
                }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminderMinutes / 60,
                    minute: reminderMinutes % 60,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderMinutes = (components.hour ?? 21) * 60 + (components.minute ?? 0)
            }
        )
    }

    @MainActor
    private func enableReminder() async {
        let center = UNUserNotificationCenter.current()
        // Only prompts the first time; afterwards it resolves immediately
        // from the stored system permission.
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        isEnabled = granted
        isPermissionDenied = !granted
    }

    @MainActor
    private func refreshPermissionState() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        isPermissionDenied = isEnabled && status == .denied
    }

    private func openNotificationSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}
