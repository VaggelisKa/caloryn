import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            Tab("Today", image: "CalorieRingTabIcon", value: AppTab.today) {
                TodayView()
            }

            Tab("My Foods", systemImage: "fork.knife.circle.fill", value: AppTab.myFoods) {
                MyFoodsView()
            }

            Tab("History", systemImage: "chart.bar.fill", value: AppTab.history) {
                HistoryView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
        .calorynPageCanvas()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, MealTemplate.self, MealTemplateItem.self], inMemory: true)
        .environment(AppRouter())
}
