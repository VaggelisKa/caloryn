import Foundation

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var id: String { rawValue }

    nonisolated var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .lightlyActive: 1.375
        case .moderatelyActive: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: "Sedentary"
        case .lightlyActive: "Lightly Active"
        case .moderatelyActive: "Moderately Active"
        case .veryActive: "Very Active"
        case .extraActive: "Extra Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: "Little or no exercise, desk job"
        case .lightlyActive: "Light exercise 1–3 days/week"
        case .moderatelyActive: "Moderate exercise 3–5 days/week"
        case .veryActive: "Hard exercise 6–7 days/week"
        case .extraActive: "Very hard exercise, physical job"
        }
    }

    var iconName: String {
        switch self {
        case .sedentary: "figure.seated.side"
        case .lightlyActive: "figure.walk"
        case .moderatelyActive: "figure.run"
        case .veryActive: "figure.highintensity.intervaltraining"
        case .extraActive: "figure.strengthtraining.traditional"
        }
    }
}
