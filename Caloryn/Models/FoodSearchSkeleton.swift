import CoreGraphics

struct FoodSearchSkeleton {
    struct Row: Identifiable, Equatable {
        let id: Int
        let titleWidth: CGFloat
        let subtitleWidth: CGFloat
        let calorieWidth: CGFloat
    }

    static let fullScreenRowCount = 7

    static let trailingRowCount = 3

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
