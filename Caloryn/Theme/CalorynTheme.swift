import SwiftUI

/// The app-only half of the theme: meal and Nutri-Score lookups, spacing and type. The colour
/// tokens themselves are in `CalorynShared/CalorynThemeColors.swift`, shared with the widget.
extension CalorynTheme {
    // MARK: - Meal palette

    /// The meal's colour for shapes: donut sectors, a selected meal chip.
    static func mealFill(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfast
        case .lunch: mealLunch
        case .dinner: mealDinner
        case .snack: mealSnack
        }
    }

    /// The meal's colour for text: dark enough for 4.5:1 on the page in light mode. In dark
    /// mode fill and ink are the same value.
    static func mealInk(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfastInk
        case .lunch: mealLunchInk
        case .dinner: mealDinnerInk
        case .snack: mealSnackInk
        }
    }

    /// What is drawn *on* the meal's fill: a selected meal chip's label, the "Log to <meal>"
    /// button's label. White on lunch and dinner and ink on breakfast and
    /// snack in light — white on the yellow fill is 1.8:1 — and the dark card colour on every
    /// fill in dark.
    static func mealOnFill(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfastOnFill
        case .lunch: mealLunchOnFill
        case .dinner: mealDinnerOnFill
        case .snack: mealSnackOnFill
        }
    }

    /// A soft wash of the meal's fill, the meal's ink drawn on it: the meal header's add
    /// button. The same 16% for all four meals, so no meal's button is louder than another's;
    /// on the page it stays light enough that the ink plus keeps its contrast.
    static func mealWash(_ meal: MealType) -> Color {
        mealFill(meal).opacity(0.16)
    }

    // MARK: - Nutri-Score

    static func nutriscoreColor(for grade: String) -> Color? {
        switch grade.lowercased() {
        case "a": return nutriscoreA
        case "b": return nutriscoreB
        case "c": return nutriscoreC
        case "d": return nutriscoreD
        case "e": return nutriscoreE
        default: return nil
        }
    }

    // MARK: - Spacing

    static let pagePadding: CGFloat = 20
    static let cardSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    /// A grouped surface (Settings groups, the History insight): see `calorynGroupSurface()`.
    static let groupCornerRadius: CGFloat = 22
    static let hairlineWidth: CGFloat = 1

    // MARK: - Typography

    // Bricolage Grotesque throughout (see `CalorynTypeface`): weight carries the feel. Heavy
    // for display numbers and screen titles, bold for section titles, tabular digits on every
    // number. Text-style-relative wherever there is a text style, so Dynamic Type scales it;
    // the fixed-size display fonts take a size the caller scales with `@ScaledMetric`.

    static let screenTitle: Font = CalorynTypeface.text(.largeTitle, weight: .heavy)
    static let brandTitle: Font = CalorynTypeface.text(.largeTitle, weight: .heavy)
    static let compactNumber: Font = CalorynTypeface.text(.title2, weight: .bold).monospacedDigit()
    /// The hero figure beside the donut, the Portion sheet's kcal preview, History's daily
    /// average. Pass a size from `@ScaledMetric` so it still follows Dynamic Type, and pair it
    /// with a tight negative `tracking` as the mocks do.
    static func heroNumber(size: CGFloat) -> Font {
        CalorynTypeface.fixed(size: size, weight: .heavy).monospacedDigit()
    }
    static let sectionTitle: Font = CalorynTypeface.text(.title2, weight: .bold)
    /// A 17pt bold section header: the meal name over its rows, or a non-meal section.
    static let sectionHeaderTitle: Font = CalorynTypeface.text(.headline, weight: .bold)
    /// The trailing total on a section header ("382 kcal"), tabular.
    static let sectionHeaderDetail: Font = CalorynTypeface.text(.subheadline, weight: .medium).monospacedDigit()
    static let cardSubtitle: Font = CalorynTypeface.text(.subheadline)
    static let itemTitle: Font = CalorynTypeface.text(.headline)
    static let bodyText: Font = CalorynTypeface.text(.body)
    static let caption: Font = CalorynTypeface.text(.caption, weight: .medium)
    /// The donut legend: meal name and its kcal, 13pt medium, tabular.
    static let legendText: Font = CalorynTypeface.text(.footnote, weight: .medium).monospacedDigit()
    /// A chip's label, 13pt. `calorynChip(isSelected:)` adds the bold of a selected chip.
    static let chipLabel: Font = CalorynTypeface.text(.footnote, weight: .medium).monospacedDigit()
    static let buttonLabel: Font = CalorynTypeface.text(.headline)
    /// A primary button's label, 17pt bold. Applied by `calorynPrimaryButton()`.
    static let primaryButtonLabel: Font = CalorynTypeface.text(.headline, weight: .bold)
    static let toolbarAction: Font = CalorynTypeface.text(.body, weight: .semibold)
    static let numericBody: Font = CalorynTypeface.text(.body, weight: .medium).monospacedDigit()
    static let numericCaption: Font = CalorynTypeface.text(.caption, weight: .semibold).monospacedDigit()
    static let microCaption: Font = CalorynTypeface.text(.caption2, weight: .medium)
    static let microCaptionEmphasized: Font = CalorynTypeface.text(.caption2, weight: .semibold)
    static let numericMicroCaption: Font = CalorynTypeface.text(.caption2, weight: .medium).monospacedDigit()
    static let numericMicroCaptionEmphasized: Font = CalorynTypeface.text(.caption2, weight: .semibold).monospacedDigit()
    static let chartAxisLabel: Font = CalorynTypeface.text(.caption2, weight: .medium)
    static let chartXAxisLabel: Font = CalorynTypeface.fixed(size: 10, weight: .medium)
    static let denseChartXAxisLabel: Font = CalorynTypeface.fixed(size: 8, weight: .medium)
    static func weeklyChartXAxisLabel(isDense: Bool) -> Font {
        isDense ? denseChartXAxisLabel : chartXAxisLabel
    }
    /// The calorie trend's x-axis labels, on the weekly chart's fixed sizes. They are drawn
    /// at fixed points under the plot and cannot wrap or move apart, so a size that followed
    /// Dynamic Type ran the 90-day week labels together at the default size and onto the
    /// plot at larger ones. Dense past a week of points. Each point's accessibility label
    /// carries its date.
    static func trendChartXAxisLabel(pointCount: Int) -> Font {
        weeklyChartXAxisLabel(isDense: pointCount > 7)
    }
    static let badgeText: Font = CalorynTypeface.text(.caption2, weight: .semibold)
    static let toolbarIcon: Font = .system(.body, weight: .medium)
    static let inlineIcon: Font = .system(.headline, weight: .semibold)
    static let compactIcon: Font = .system(.caption, weight: .semibold)
}
