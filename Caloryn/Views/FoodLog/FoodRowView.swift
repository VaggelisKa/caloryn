import SwiftUI

/// The fonts of a food row. Shared so every row the Add Food sheet draws — a search
/// result, a suggestion, a saved meal — lines up with the next.
enum FoodRowTypography {
    /// The food's name, 16pt medium.
    static let name: Font = CalorynTypeface.text(.callout, weight: .medium)
    /// Brand and serving under the name, 13pt.
    static let detail: Font = CalorynTypeface.text(.footnote)
    /// The kcal figure, 16pt semibold, tabular.
    static let figure: Font = CalorynTypeface.text(.callout, weight: .semibold).monospacedDigit()
    /// What the figure counts, "kcal", 11pt.
    static let figureCaption: Font = CalorynTypeface.text(.caption2)
}

struct FoodRowView: View {
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    var nutriscoreGrade: String? = nil
    var servingDescription: String? = nil
    /// What the declared serving weighs, so the row can price it.
    var servingGrams: Double? = nil
    /// What the serving adds, when known better than its weight says; a recipe's whole.
    var caloriesPerServing: Double? = nil
    var isCustom: Bool = false
    var isRecipe: Bool = false
    var showsTypeBadge: Bool = true
    /// Replaces the brand-and-serving line, for a row that is not one food (a saved meal).
    var detail: String? = nil
    /// A specific portion the row is about, which it shows and prices instead of the serving.
    var portionGrams: Double? = nil
    /// The calories of that portion, or of the row `detail` describes. Reads "kcal".
    var portionCalories: Double? = nil

    @AppStorage("showNutriscore") private var showNutriscore = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// What the row says, decided in `FoodRowSummary`.
    private var summary: FoodRowSummary {
        FoodRowSummary(
            brand: brand,
            servingDescription: servingDescription,
            servingGrams: servingGrams,
            detail: detail,
            caloriesPer100g: caloriesPer100g,
            caloriesPerServing: caloriesPerServing,
            isRecipe: isRecipe,
            portionGrams: portionGrams,
            portionCalories: portionCalories
        )
    }

    var body: some View {
        let summary = summary

        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Side by side, the figure column and one-line name left "Smørr…" at AX5.
                // Stacked, the name and subtitle may wrap and the figure reads inline.
                VStack(alignment: .leading, spacing: 4) {
                    nameText.lineLimit(3)

                    if hasBadges {
                        HStack(spacing: 8) { badges }
                    }

                    if let subtitle = summary.subtitle {
                        subtitleText(subtitle, spoken: summary.subtitleAccessibilityLabel).lineLimit(3)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(summary.figure)
                            .font(FoodRowTypography.figure)
                            .foregroundStyle(CalorynTheme.textPrimary)
                        Text(summary.figureCaption)
                            .font(FoodRowTypography.figureCaption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            nameText.lineLimit(1)
                            badges
                        }

                        if let subtitle = summary.subtitle {
                            subtitleText(subtitle, spoken: summary.subtitleAccessibilityLabel).lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    FoodRowFigure(figure: summary.figure, caption: summary.figureCaption)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var nameText: some View {
        Text(name)
            .font(FoodRowTypography.name)
            .foregroundStyle(CalorynTheme.textPrimary)
    }

    private func subtitleText(_ subtitle: String, spoken: String?) -> some View {
        Text(subtitle)
            .font(FoodRowTypography.detail)
            .foregroundStyle(CalorynTheme.textSecondary)
            .accessibilityLabel(spoken ?? subtitle)
    }

    private var hasBadges: Bool {
        (showsTypeBadge && (isCustom || isRecipe)) || (showNutriscore && nutriscoreGrade != nil)
    }

    @ViewBuilder
    private var badges: some View {
        if showsTypeBadge && (isCustom || isRecipe) {
            FoodTypeBadge(isRecipe: isRecipe)
        }

        if showNutriscore, let grade = nutriscoreGrade {
            NutriscoreBadge(grade: grade)
        }
    }
}

/// The two-line figure on the right of a row: "152" over "kcal".
struct FoodRowFigure: View {
    let figure: String
    let caption: String

    @ScaledMetric(relativeTo: .callout) private var minimumWidth: CGFloat = 44

    var body: some View {
        // Not fixed-size: at the largest text sizes the caption wraps under the number
        // rather than squeezing the food's name down to its first letters.
        VStack(alignment: .trailing, spacing: 1) {
            Text(figure)
                .font(FoodRowTypography.figure)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
            Text(caption)
                .font(FoodRowTypography.figureCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minWidth: minimumWidth, alignment: .trailing)
    }
}

/// "Recipe" or "Yours": sentence case, bold, and one tint whatever meal the row sits under
/// (`fillBadge` / `textSecondary`). Squared off like the Nutri-Score badge beside it.
struct FoodTypeBadge: View {
    let isRecipe: Bool

    var body: some View {
        Text(isRecipe ? "Recipe" : "Yours")
            .font(CalorynTheme.badgeText)
            .fontWeight(.bold)
            .foregroundStyle(CalorynTheme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                CalorynTheme.fillBadge,
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            // Never squeezed: "Recipe" cut to "Rec…" says nothing. The name gives way.
            .fixedSize()
    }
}

#Preview {
    List {
        FoodRowView(
            name: "Skyr",
            brand: "Arla",
            caloriesPer100g: 63,
            nutriscoreGrade: "a",
            servingDescription: "1 pot (150g)",
            servingGrams: 150
        )
        FoodRowView(
            name: "Dark chocolate 70%",
            brand: "Marabou",
            caloriesPer100g: 590,
            servingDescription: "2 squares (20g)",
            servingGrams: 20
        )
        FoodRowView(name: "Rugbroed", brand: "Schulstad", caloriesPer100g: 210, servingDescription: "1 slice (45g)", servingGrams: 45)
        FoodRowView(name: "Rolled oats", brand: "Quaker", caloriesPer100g: 380, servingDescription: "40 g")
        FoodRowView(name: "Chicken Breast", brand: nil, caloriesPer100g: 165)
        FoodRowView(name: "Nick's Pizza", brand: "Homemade", caloriesPer100g: 267, isCustom: true)
        FoodRowView(name: "Greek Salad", brand: nil, caloriesPer100g: 72, isRecipe: true)
    }
    .calorynPlainListStyle()
}
