import SwiftUI
import UIKit

enum CalorynTheme {
    // MARK: - Colors

    static let sage = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.588, green: 0.671, blue: 0.514, alpha: 1)   // #96AB83
            : UIColor(red: 0.486, green: 0.557, blue: 0.420, alpha: 1)   // #7C8E6B
    })

    static let stone = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.784, green: 0.733, blue: 0.686, alpha: 1)   // #C8BBAF
            : UIColor(red: 0.710, green: 0.659, blue: 0.596, alpha: 1)   // #B5A898
    })

    static let terracotta = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.831, green: 0.565, blue: 0.435, alpha: 1)   // #D4906F
            : UIColor(red: 0.757, green: 0.471, blue: 0.337, alpha: 1)   // #C17856
    })

    static let warmWhite = Color(red: 0.980, green: 0.980, blue: 0.969)  // #FAFAF7

    static let surface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.153, green: 0.149, blue: 0.141, alpha: 1)   // #272624
            : UIColor(red: 0.953, green: 0.945, blue: 0.925, alpha: 1)   // #F3F1EC
    })

    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.925, green: 0.922, blue: 0.910, alpha: 1)   // #ECEBE8
            : UIColor(red: 0.173, green: 0.173, blue: 0.165, alpha: 1)   // #2C2C2A
    })

    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.678, green: 0.675, blue: 0.659, alpha: 1)   // #ADACA8
            : UIColor(red: 0.541, green: 0.541, blue: 0.522, alpha: 1)   // #8A8A85
    })

    static let proteinColor = sage

    static let carbColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.659, green: 0.769, blue: 0.851, alpha: 1)   // #A8C4D9
            : UIColor(red: 0.588, green: 0.694, blue: 0.776, alpha: 1)   // #96B1C6
    })

    static let fatColor = terracotta

    static let fiberColor = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.612, green: 0.702, blue: 0.655, alpha: 1)   // #9CB3A7
            : UIColor(red: 0.361, green: 0.498, blue: 0.435, alpha: 1)   // #5C7F6F
    })

    // Nutri-Score (A = best, E = worst)
    static let nutriscoreA = Color(red: 0.012, green: 0.506, blue: 0.255)   // #038141
    static let nutriscoreB = Color(red: 0.522, green: 0.733, blue: 0.184)   // #85BB2F
    static let nutriscoreC = Color(red: 0.996, green: 0.796, blue: 0.008)   // #FECB02
    static let nutriscoreD = Color(red: 0.933, green: 0.506, blue: 0)       // #EE8100
    static let nutriscoreE = Color(red: 0.902, green: 0.243, blue: 0.067)   // #E63E11

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
