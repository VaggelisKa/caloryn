import Foundation

enum WidgetMeal: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast:
            "Breakfast"
        case .lunch:
            "Lunch"
        case .dinner:
            "Dinner"
        case .snack:
            "Snack"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast:
            "sunrise.fill"
        case .lunch:
            "sun.max.fill"
        case .dinner:
            "moon.fill"
        case .snack:
            "leaf.fill"
        }
    }
}

enum AppRoute: Hashable, Sendable {
    static let urlScheme = "caloryn"

    case today
    case nutritionDetails
    case addFood(meal: WidgetMeal)
    case scanFood(meal: WidgetMeal)

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.urlScheme

        switch self {
        case .today:
            components.host = "today"
        case .nutritionDetails:
            components.host = "nutrition-details"
        case .addFood(let meal):
            components.host = "add-food"
            components.queryItems = [
                URLQueryItem(name: "meal", value: meal.rawValue)
            ]
        case .scanFood(let meal):
            components.host = "scan-food"
            components.queryItems = [
                URLQueryItem(name: "meal", value: meal.rawValue)
            ]
        }

        guard let url = components.url else {
            preconditionFailure("AppRoute must always produce a valid URL")
        }
        return url
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.urlScheme else { return nil }

        switch url.host?.lowercased() {
        case "today":
            self = .today
        case "nutrition-details":
            self = .nutritionDetails
        case "add-food":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let mealValue = components.queryItems?.first(where: { $0.name == "meal" })?.value,
                  let meal = WidgetMeal(rawValue: mealValue) else {
                return nil
            }
            self = .addFood(meal: meal)
        case "scan-food":
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let mealValue = components.queryItems?.first(where: { $0.name == "meal" })?.value,
                  let meal = WidgetMeal(rawValue: mealValue) else {
                return nil
            }
            self = .scanFood(meal: meal)
        default:
            return nil
        }
    }
}
