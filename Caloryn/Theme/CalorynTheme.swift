import SwiftUI

extension CalorynTheme {
    static func mealFill(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfast
        case .lunch: mealLunch
        case .dinner: mealDinner
        case .snack: mealSnack
        }
    }

    static func mealInk(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfastInk
        case .lunch: mealLunchInk
        case .dinner: mealDinnerInk
        case .snack: mealSnackInk
        }
    }

    static func mealOnFill(_ meal: MealType) -> Color {
        switch meal {
        case .breakfast: mealBreakfastOnFill
        case .lunch: mealLunchOnFill
        case .dinner: mealDinnerOnFill
        case .snack: mealSnackOnFill
        }
    }

    static func mealWash(_ meal: MealType) -> Color {
        mealFill(meal).opacity(0.16)
    }

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

    static let pagePadding: CGFloat = 20
    static let cardSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cornerRadius: CGFloat = 20
    static let smallCornerRadius: CGFloat = 12
    static let groupCornerRadius: CGFloat = 22
    static let hairlineWidth: CGFloat = 1

    static let screenTitle: Font = CalorynTypeface.text(.largeTitle, weight: .heavy)
    static let brandTitle: Font = CalorynTypeface.text(.largeTitle, weight: .heavy)
    static let compactNumber: Font = CalorynTypeface.text(.title2, weight: .bold).monospacedDigit()
    static func heroNumber(size: CGFloat) -> Font {
        CalorynTypeface.fixed(size: size, weight: .heavy).monospacedDigit()
    }
    static let sectionTitle: Font = CalorynTypeface.text(.title2, weight: .bold)
    static let sectionHeaderTitle: Font = CalorynTypeface.text(.headline, weight: .bold)
    static let sectionHeaderDetail: Font = CalorynTypeface.text(.subheadline, weight: .medium).monospacedDigit()
    static let cardSubtitle: Font = CalorynTypeface.text(.subheadline)
    static let itemTitle: Font = CalorynTypeface.text(.headline)
    static let bodyText: Font = CalorynTypeface.text(.body)
    static let caption: Font = CalorynTypeface.text(.caption, weight: .medium)
    static let legendText: Font = CalorynTypeface.text(.footnote, weight: .medium).monospacedDigit()
    static let chipLabel: Font = CalorynTypeface.text(.footnote, weight: .medium).monospacedDigit()
    static let buttonLabel: Font = CalorynTypeface.text(.headline)
    static let primaryButtonLabel: Font = CalorynTypeface.text(.headline, weight: .bold)
    static let toolbarAction: Font = CalorynTypeface.text(.body, weight: .semibold)
    static let numericBody: Font = CalorynTypeface.text(.body, weight: .medium).monospacedDigit()
    static let numericCaption: Font = CalorynTypeface.text(.caption, weight: .semibold).monospacedDigit()
    static let microCaption: Font = CalorynTypeface.text(.caption2, weight: .medium)
    static let microCaptionEmphasized: Font = CalorynTypeface.text(.caption2, weight: .semibold)
    static let numericMicroCaption: Font = CalorynTypeface.text(.caption2, weight: .medium).monospacedDigit()
    static let chartAxisLabel: Font = CalorynTypeface.text(.caption2, weight: .medium)
    static let chartXAxisLabel: Font = CalorynTypeface.fixed(size: 10, weight: .medium)
    static let denseChartXAxisLabel: Font = CalorynTypeface.fixed(size: 8, weight: .medium)
    static func weeklyChartXAxisLabel(isDense: Bool) -> Font {
        isDense ? denseChartXAxisLabel : chartXAxisLabel
    }
    static func trendChartXAxisLabel(pointCount: Int) -> Font {
        weeklyChartXAxisLabel(isDense: pointCount > 7)
    }
    static let badgeText: Font = CalorynTypeface.text(.caption2, weight: .semibold)
    static let toolbarIcon: Font = .system(.body, weight: .medium)
    static let inlineIcon: Font = .system(.headline, weight: .semibold)
    static let compactIcon: Font = .system(.caption, weight: .semibold)
}
