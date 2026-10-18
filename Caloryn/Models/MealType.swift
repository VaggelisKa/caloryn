import Foundation

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    var iconName: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.fill"
        case .snack: "leaf.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }

    func displayName(snackIndex: Int) -> String {
        guard self == .snack else { return displayName }
        return "Snack \(snackIndex)"
    }

    /// The widget's name for this meal: the two enums share raw values, but the mapping is
    /// spelled out so a renamed case cannot silently drop a meal from the widget's plate.
    var widgetMeal: WidgetMeal {
        switch self {
        case .breakfast: .breakfast
        case .lunch: .lunch
        case .dinner: .dinner
        case .snack: .snack
        }
    }

    init(widgetMeal: WidgetMeal) {
        switch widgetMeal {
        case .breakfast:
            self = .breakfast
        case .lunch:
            self = .lunch
        case .dinner:
            self = .dinner
        case .snack:
            self = .snack
        }
    }
}
