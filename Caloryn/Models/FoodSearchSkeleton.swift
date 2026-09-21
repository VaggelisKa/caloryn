import CoreGraphics

/// The placeholder rows the food search shows while a query is in flight.
///
/// The bar widths are a fixed cycle rather than random numbers. A random width
/// is re-drawn every time SwiftUI re-evaluates the body, so the bars twitch
/// while the shimmer runs and the placeholder reads as content arriving rather
/// than content loading — and it is not a thing a test can hold still.
struct FoodSearchSkeleton {

    /// Widths are points rather than fractions of the row, so a row needs no
    /// geometry reading to lay itself out.
    struct Row: Identifiable, Equatable {
        let id: Int
        let titleWidth: CGFloat
        let subtitleWidth: CGFloat
        let calorieWidth: CGFloat
    }

    /// Deliberately more than fit, so the block runs off the bottom edge the
    /// way a real list does.
    static let fullScreenRowCount = 7

    static let trailingRowCount = 3

    /// The widest bar in the cycle. The text column is at least ~250pt on the
    /// narrowest supported iPhone, so nothing here has to compress at default
    /// Dynamic Type.
    static let maxTitleWidth: CGFloat = 214

    private static let widths: [(title: CGFloat, subtitle: CGFloat, calories: CGFloat)] = [
        (186, 104, 30),
        (132, 78, 34),
        (214, 126, 26),
        (158, 92, 30),
        (196, 68, 34),
        (144, 118, 28),
        (172, 84, 32)
    ]

    /// `offset` continues the cycle rather than restarting it, so the rows that
    /// trail a results list do not repeat the widths of the rows above them.
    static func rows(count: Int, startingAt offset: Int = 0) -> [Row] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let position = offset + index
            let step = ((position % widths.count) + widths.count) % widths.count
            let width = widths[step]
            return Row(
                id: position,
                titleWidth: width.title,
                subtitleWidth: width.subtitle,
                calorieWidth: width.calories
            )
        }
    }
}
