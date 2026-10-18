import SwiftUI

enum LibraryRowStyle {
    static let name: Font = CalorynTypeface.text(.callout, weight: .medium)
    static let detail: Font = CalorynTypeface.text(.footnote)
    static let kcal: Font = CalorynTypeface.text(.callout, weight: .semibold).monospacedDigit()
    static let unit: Font = CalorynTypeface.text(.caption2)
    static let kcalColumnWidth: CGFloat = 44
    static let rowInsets = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    static let headerPadding = EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16)
}

struct LibraryRowLayout<Content: View>: View {
    let caloriesText: String?
    let unit: String
    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                content()
                    .lineLimit(3)

                if let caloriesText {
                    LibraryRowCalories(caloriesText: caloriesText, unit: unit, isInline: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .center, spacing: 10) {
                content()
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let caloriesText {
                    LibraryRowCalories(caloriesText: caloriesText, unit: unit)
                }
            }
        }
    }
}

struct LibraryRowTitle<Badge: View>: View {
    let name: String
    @ViewBuilder let badge: () -> Badge

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 6))

        layout {
            Text(name)
                .font(LibraryRowStyle.name)
                .foregroundStyle(CalorynTheme.textPrimary)

            badge()
        }
    }
}

struct LibraryRowCalories: View {
    let caloriesText: String
    let unit: String
    var isInline = false

    var body: some View {
        if isInline {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                figure
                unitText
            }
        } else {
            VStack(alignment: .trailing, spacing: 1) {
                figure
                unitText
            }
            .frame(minWidth: LibraryRowStyle.kcalColumnWidth, alignment: .trailing)
        }
    }

    private var figure: some View {
        Text(caloriesText)
            .font(LibraryRowStyle.kcal)
            .foregroundStyle(CalorynTheme.textPrimary)
            .lineLimit(1)
    }

    private var unitText: some View {
        Text(unit)
            .font(LibraryRowStyle.unit)
            .foregroundStyle(CalorynTheme.textSecondary)
            .lineLimit(1)
    }
}

struct LibraryTypeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(CalorynTheme.badgeText)
            .fontWeight(.bold)
            .foregroundStyle(CalorynTheme.typeBadgeText)
            .lineLimit(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(CalorynTheme.typeBadgeFill, in: .capsule)
            .fixedSize()
    }
}

extension View {
    func libraryHairlineSection() -> some View {
        calorynHairlineSeparators()
            .listRowInsets(LibraryRowStyle.rowInsets)
            .listSectionSeparatorTint(CalorynTheme.hairline)
            .listSectionSeparator(.visible, edges: .top)
            .listSectionSeparator(.hidden, edges: .bottom)
    }

    func libraryRowSeparatorInset() -> some View {
        alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions[.trailing]
        }
    }
}
