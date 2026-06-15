import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", image: "CalorieRingTabIcon", value: 0) {
                TodayView()
            }

            Tab("My Foods", systemImage: "fork.knife.circle.fill", value: 1) {
                MyFoodsView()
            }

            Tab("History", systemImage: "chart.bar.fill", value: 2) {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 3) {
                SettingsView()
            }
        }
        .tint(CalorynTheme.sage)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self], inMemory: true)
}
