import SwiftUI

// The rows of the My Foods library, all drawn with `LibraryRowStyle` so a list that mixes
// foods, recipes and meals (Favorites does) reads as one list. Each renders a summary from
// `Caloryn/Models/` and decides nothing.

/// One food — a manual entry, a favorite, an edited catalog product: its name with its
/// Nutri-Score, brand and serving underneath, and the kcal figure with what it counts
/// ("kcal" for the serving shown, "kcal per 100 g"), worded as Add Food words the same food.
///
/// `showsTypeBadge` adds "Yours" for a food listed among other kinds of food (Favorites),
/// as `RecipeLibraryRow` adds "Recipe"; under "Your own entries" the title already says it.
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

/// One saved recipe: its name, how many ingredients and how much it makes, and the whole
/// recipe's kcal. Renders `RecipeLibraryRowSummary`.
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

/// One saved meal: its name, its items by name, and the meal's total. Renders
/// `MealTemplateLibraryRowSummary`.
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
    /// A template whose items cannot all be read is listed as unavailable, the same rule
    /// `MealTemplateCommands` applies before logging one.
    init(template: MealTemplate) {
        let snapshots = (try? MealTemplateCommands.snapshots(for: template)) ?? []
        self.init(
            name: template.name,
            items: snapshots.map { Item(name: $0.foodName, calories: $0.nutrition.calories) }
        )
    }
}
