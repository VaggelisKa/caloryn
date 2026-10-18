import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue

    private var hasCompletedOnboarding: Bool {
        !profiles.isEmpty
    }

    private var colorScheme: ColorScheme? {
        (ThemePreference(rawValue: themePreferenceRaw) ?? .system).colorScheme
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingContainerView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(colorScheme)
        // Ink, the same value as `AccentColor`. Stock controls read the asset already; a
        // `Toggle` does not — it stays system green unless tinted.
        .tint(CalorynTheme.textPrimary)
        // Switches take `controlTint` instead: ink is near-white in dark mode, and the
        // switch's white knob vanished on an ink track.
        .toggleStyle(CalorynToggleStyle())
        .animation(.smooth(duration: 0.4), value: hasCompletedOnboarding)
        .background {
            WidgetSnapshotBridge()
            DailyReminderBridge()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
        .environment(AppRouter())
}
