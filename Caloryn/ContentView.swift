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
        .animation(.smooth(duration: 0.4), value: hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
