import SwiftUI

struct LibraryFoodRow: View {
    let summary: LibraryFoodRowSummary
    var nutriscoreGrade: String?
    var showsTypeBadge = false

    @AppStorage("showNutriscore") private var showNutriscore = true

    var body: some View {
        LibraryRowLayout(caloriesText: summary.caloriesText, unit: summary.caloriesCaption) {
            VStack(alignment: .leading, spacing: 2) {
                LibraryRowTitle(name: summary.name) {
                    if showsTypeBadge {
                        LibraryTypeBadge(text: "Yours")
                    }

                    if showNutriscore, let nutriscoreGrade {
                        NutriscoreBadge(grade: nutriscoreGrade)
                    }
                }

                if let detail = summary.detail {
                    Text(detail)
                        .font(LibraryRowStyle.detail)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityLabel(summary.detailAccessibilityLabel ?? detail)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct RecipeLibraryRow: View {
    let recipe: FoodItem
    var showsTypeBadge = false

    var body: some View {
        let summary = RecipeLibraryRowSummary(recipe: recipe)

        LibraryRowLayout(caloriesText: summary.caloriesText, unit: "kcal total") {
            VStack(alignment: .leading, spacing: 2) {
                LibraryRowTitle(name: summary.name) {
                    if showsTypeBadge {
                        LibraryTypeBadge(text: "Recipe")
                    }
                }

                Text(summary.detail)
                    .font(LibraryRowStyle.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct LibraryMealRow: View {
    let template: MealTemplate

    var body: some View {
        let summary = MealTemplateLibraryRowSummary(template: template)

        LibraryRowLayout(caloriesText: summary.caloriesText, unit: "kcal") {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(LibraryRowStyle.name)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(summary.detail)
                    .font(LibraryRowStyle.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityLabel)
        .accessibilityHint("Double tap to open this meal")
    }
}

extension MealTemplateLibraryRowSummary {
    init(template: MealTemplate) {
        let snapshots = (try? MealTemplateCommands.snapshots(for: template)) ?? []
        self.init(
            name: template.name,
            items: snapshots.map { Item(name: $0.foodName, calories: $0.nutrition.calories) }
        )
    }
}
