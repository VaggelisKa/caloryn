import SwiftUI

/// A tab page's title as the board draws it: 30pt heavy ink with a tight tracking, where
/// the system would draw 34pt bold in its own label colour.
///
/// iOS 26 has a toolbar slot for the large title, so the page keeps the system navigation
/// bar — Liquid Glass, the collapse to an inline title on scroll, the toolbar buttons — and
/// only the words change. Before iOS 26 there is no such slot, so the system large title
/// stays. The inline title it collapses into is UIKit's, set in the app's typeface by
/// `CalorynTypeface.styleCollapsedNavigationTitles()`.
///
/// Settings, My Foods and History use it; it lives with Settings only because a lane may not
/// add to the shared theme folder.
private struct PlateLargeTitleModifier: ViewModifier {
    let title: String

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 30

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .largeTitle) {
                        Text(title)
                            .font(CalorynTypeface.fixed(size: size, weight: .heavy))
                            .tracking(-0.01 * size)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
        } else {
            content
                .navigationTitle(title)
        }
    }
}

extension View {
    /// The page's large title in the Plate style. Use in place of `.navigationTitle(_:)` on a
    /// tab's root screen.
    func calorynLargeTitle(_ title: String) -> some View {
        modifier(PlateLargeTitleModifier(title: title))
    }
}
