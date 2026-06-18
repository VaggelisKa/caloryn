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

    private var onboardingTransition: AnyTransition {
        .opacity.animation(.smooth(duration: 0.4))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
                    .transition(onboardingTransition)
            } else {
                OnboardingContainerView()
                    .transition(onboardingTransition)
            }
        }
        .preferredColorScheme(colorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
