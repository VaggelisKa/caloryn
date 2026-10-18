import SwiftUI

/// Every colour below resolves to a Color Set in `CalorynShared/SharedColors.xcassets`, which declares its
/// light and dark appearance together. Add colours there, never as literals here — a Color Set
/// makes a missing dark variant visible in Xcode, whereas a `UIColor { traits in … }` closure
/// silently falls back. See CLAUDE.md rule 6 and `docs/design/plate-market.md`.
enum CalorynTheme {
    // MARK: - Colors

    // Paper and ink. Pages are paper, `cardBackground` is the white of a sheet or a grouped
    // surface, `surface` is an input well inside a sheet, and `textPrimary` is the ink that
    // text, controls and primary buttons are drawn in.
    static let surface = Color(.surface)
    static let pageBackground = Color(.pageBackground)
    static let cardBackground = Color(.cardBackground)

    /// Skeleton loaders: the hairline's ink at two weights, so a placeholder reads as
    /// part of the page it sits on rather than a grey block dropped onto it. `skeletonShine`
    /// is the band that sweeps over `skeletonBase`, so the two add up at its peak.
    static let skeletonBase = Color(.skeletonBase)
    static let skeletonShine = Color(.skeletonShine)

    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)
    /// The quietest text: the legend's "not yet", a disabled chevron. Below 4.5:1 on the
    /// page (2.8:1 light), so only for a placeholder whose meaning is also carried some other
    /// way — never for a figure or anything the reader must be able to make out.
    static let textTertiary = Color(.textTertiary)

    /// Row separators, surface borders and the unfilled part of a donut. Carries its own
    /// alpha in the Color Set, so it reads the same on paper and on a white surface.
    static let hairline = Color(.hairline)

    /// The neutral "eaten" fill of History's day plates and bars. History is about totals,
    /// not meals, so it does not borrow a meal colour.
    static let historyEaten = Color(.historyEaten)
    /// An under-goal day in History: a lighter step of `historyEaten`, so under, on track and
    /// over read as three weights (light, mid, ink) rather than two near-identical greys.
    static let historyEatenLight = Color(.historyEatenLight)

    /// The "Recipe" / "Yours" type badge on a food row: secondary text on an 18% tint of
    /// itself in both appearances (4.7:1 light, 5.7:1 dark on the page). Neutral, because a
    /// lunch-red badge read as a lunch marker once meals owned colour. Alpha is baked into
    /// the fill.
    static let typeBadgeFill = Color(.typeBadgeFill)
    static let typeBadgeText = Color(.typeBadgeText)

    /// The "on" colour of a stock control that draws white on it: a switch's track under its
    /// white knob, the selected day of a graphical date picker. Ink in light, as the spec has
    /// it; in dark, where ink is near-white, a mid grey the white knob still shows on
    /// (3:1, and 3.8:1 against the system's off track). `ContentView` applies it to every
    /// `Toggle` through `CalorynToggleStyle`.
    static let controlTint = Color(.controlTint)

    /// A swipe action's background under the system's white label and glyph: dark in both
    /// appearances (6.6:1 light, 8:1 dark), where `historyEaten` fell to 3:1 in dark.
    static let swipeActionTint = Color(.swipeActionTint)

    // Retired from new code: the meal palette owns colour now. Kept so the call sites that
    // still read them compile, and because widgets and a few unchanged screens use them.
    static let sage = Color(.sage)
    static let stone = Color(.stone)
    static let terracotta = Color(.terracotta)
    static let warmWhite = Color(.warmWhite)
    static let cardSeparator = stone.opacity(0.3)

    // Macros are told apart by their label, never by colour: sage was both "protein" and
    // "lunch" once meals took the palette. All four resolve to ink.
    static let proteinColor = textPrimary
    static let carbColor = textPrimary
    static let fatColor = textPrimary
    static let fiberColor = textPrimary

    // MARK: - Meal palette

    // Asset names omit a `Color` suffix: Xcode strips it when generating symbols, so an
    // asset called `MealLunchColor` would yield `.mealLunch` anyway.
    static let mealBreakfast = Color(.mealBreakfast)
    static let mealBreakfastInk = Color(.mealBreakfastInk)
    static let mealLunch = Color(.mealLunch)
    static let mealLunchInk = Color(.mealLunchInk)
    static let mealDinner = Color(.mealDinner)
    static let mealDinnerInk = Color(.mealDinnerInk)
    static let mealSnack = Color(.mealSnack)
    static let mealSnackInk = Color(.mealSnackInk)
    static let mealBreakfastOnFill = Color(.mealBreakfastOnFill)
    static let mealLunchOnFill = Color(.mealLunchOnFill)
    static let mealDinnerOnFill = Color(.mealDinnerOnFill)
    static let mealSnackOnFill = Color(.mealSnackOnFill)

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

    // Nutri-Score (A = best, E = worst). Appearance-independent by design: these are
    // the official Nutri-Score brand colours and must not shift with the interface style.
    static let nutriscoreA = Color(.nutriscoreA)
    static let nutriscoreB = Color(.nutriscoreB)
    static let nutriscoreC = Color(.nutriscoreC)
    static let nutriscoreD = Color(.nutriscoreD)
    static let nutriscoreE = Color(.nutriscoreE)

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
    static let displayNumber: Font = CalorynTypeface.text(.largeTitle, weight: .heavy).monospacedDigit()
    static let compactNumber: Font = CalorynTypeface.text(.title2, weight: .bold).monospacedDigit()
    static let largeNumber: Font = displayNumber
    static func ringNumber(size: CGFloat) -> Font {
        CalorynTypeface.fixed(size: size, weight: .heavy).monospacedDigit()
    }
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
    static let sectionEyebrow: Font = CalorynTypeface.text(.caption, weight: .medium)
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
    static let emptyStateIcon: Font = .system(.largeTitle, weight: .medium)
    static let compactIcon: Font = .system(.caption, weight: .semibold)
}
