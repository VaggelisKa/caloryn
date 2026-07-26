import SwiftUI

/// Widget-side names for the shared palette.
///
/// The colours themselves live in `CalorynShared/SharedColors.xcassets`, which is a member of
/// both the app and the widget target — so these resolve to the same Color Sets the app uses
/// and cannot drift from it. Add colours there, never as literals here.
enum WidgetTheme {
    static let sage = Color(.sage)
    static let terracotta = Color(.terracotta)

    /// Widgets sit on the home screen rather than on a page canvas, so this deliberately
    /// tracks the card surface rather than `pageBackground`.
    static let background = Color(.cardBackground)

    static let ringTrack = Color.secondary.opacity(0.16)
}
