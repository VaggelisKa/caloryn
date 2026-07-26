import SwiftUI

/// Every colour below resolves to a Color Set in `CalorynShared/SharedColors.xcassets`, which declares its
/// light and dark appearance together. Add colours there, never as literals here — a Color Set
/// makes a missing dark variant visible in Xcode, whereas a `UIColor { traits in … }` closure
/// silently falls back. See CLAUDE.md rule 7.
enum CalorynTheme {
    // MARK: - Colors

    static let sage = Color(.sage)
    static let stone = Color(.stone)
    static let terracotta = Color(.terracotta)
    static let warmWhite = Color(.warmWhite)
    static let surface = Color(.surface)
    static let pageBackground = Color(.pageBackground)
    static let cardBackground = Color(.cardBackground)
    static let cardSeparator = stone.opacity(0.3)

    static let textPrimary = Color(.textPrimary)
    static let textSecondary = Color(.textSecondary)

    // Asset names omit a `Color` suffix: Xcode strips it when generating symbols
    // (`CarbColor` would yield `.carb`), so the asset is named `Carb` to match.
    static let proteinColor = sage
    static let carbColor = Color(.carb)
    static let fatColor = terracotta
    static let fiberColor = Color(.fiber)

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

    // MARK: - Typography

    static let brandTitle: Font = .system(.largeTitle, design: .rounded, weight: .bold)
    static let displayNumber: Font = .system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
    static let compactNumber: Font = .system(.title2, design: .rounded, weight: .bold).monospacedDigit()
    static let largeNumber: Font = displayNumber
    static func ringNumber(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }
    static let sectionTitle: Font = .system(.title2, weight: .semibold)
    static let sectionEyebrow: Font = .system(.caption, weight: .medium)
    static let cardSubtitle: Font = .system(.subheadline)
    static let itemTitle: Font = .system(.headline)
    static let bodyText: Font = .system(.body)
    static let caption: Font = .system(.caption, weight: .medium)
    static let buttonLabel: Font = .system(.headline, design: .rounded)
    static let toolbarAction: Font = .system(.body, weight: .semibold)
    static let numericBody: Font = .system(.body, design: .rounded, weight: .medium).monospacedDigit()
    static let numericCaption: Font = .system(.caption, design: .rounded, weight: .semibold).monospacedDigit()
    static let microCaption: Font = .system(.caption2, design: .rounded, weight: .medium)
    static let microCaptionEmphasized: Font = .system(.caption2, design: .rounded, weight: .semibold)
    static let numericMicroCaption: Font = .system(.caption2, design: .rounded, weight: .medium).monospacedDigit()
    static let numericMicroCaptionEmphasized: Font = .system(.caption2, design: .rounded, weight: .semibold).monospacedDigit()
    static let chartAxisLabel: Font = .system(.caption2, design: .rounded, weight: .medium)
    static let chartXAxisLabel: Font = .system(size: 10, weight: .medium, design: .rounded)
    static let denseChartXAxisLabel: Font = .system(size: 8, weight: .medium, design: .rounded)
    static func weeklyChartXAxisLabel(isDense: Bool) -> Font {
        isDense ? denseChartXAxisLabel : chartXAxisLabel
    }
    static let badgeText: Font = .system(.caption2, design: .rounded, weight: .semibold)
    static let toolbarIcon: Font = .system(.body, weight: .medium)
    static let inlineIcon: Font = .system(.headline, weight: .semibold)
    static let emptyStateIcon: Font = .system(.largeTitle, weight: .medium)
    static let compactIcon: Font = .system(.caption, weight: .semibold)
}
