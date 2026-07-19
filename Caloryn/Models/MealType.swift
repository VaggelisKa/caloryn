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

    var danishName: String {
        switch self {
        case .breakfast: "Morgenmad"
        case .lunch: "Frokost"
        case .dinner: "Aftensmad"
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
