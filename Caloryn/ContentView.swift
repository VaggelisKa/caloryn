import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @Environment(CloudSyncActivity.self) private var cloudSync
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @State private var waitExpired = false

    private var phase: FirstLaunchSyncGate.Phase {
        FirstLaunchSyncGate.phase(
            hasLocalProfile: !profiles.isEmpty,
            syncsWithCloud: cloudSync.syncsWithCloud,
            initialImportSettled: cloudSync.initialImportSettled,
            waitExpired: waitExpired
        )
    }

    private var colorScheme: ColorScheme? {
        (ThemePreference(rawValue: themePreferenceRaw) ?? .system).colorScheme
    }

    var body: some View {
        Group {
            switch phase {
            case .main:
                MainTabView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingContainerView()
                    .transition(.opacity)
            case .awaitingCloudImport:
                CloudSyncWaitView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
        // `accent` is also the build's global accent colour, so stock controls read it already;
        // a `Toggle` does not — it stays system green unless tinted.
        .tint(CalorynTheme.accent)
        // Switches take `accentControl` instead: ink is near-white in dark mode, and the
        // switch's white knob vanished on an ink track.
        .toggleStyle(CalorynToggleStyle())
        .animation(.smooth(duration: 0.4), value: phase)
        .task(id: phase) {
            guard phase == .awaitingCloudImport, let ceiling = cloudSync.waitCeiling else { return }
            try? await Task.sleep(for: ceiling)
            guard !Task.isCancelled else { return }
            waitExpired = true
        }
        .background {
            WidgetSnapshotBridge()
            DailyReminderBridge()
            ChatbotPasteBridge()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
        .environment(AppRouter())
        .environment(CloudSyncActivity.disabled)
}
