import Foundation

enum FoodSearchProvider: String, Codable, CaseIterable, Sendable {
    case calorynAPI = "caloryn_api"
    case openFoodFacts = "open_food_facts"

    var displayName: String {
        switch self {
        case .calorynAPI: "Caloryn"
        case .openFoodFacts: "Open Food Facts"
        }
    }
}

enum FoodDataSource: String, Codable, Sendable {
    case calorynCatalog = "caloryn_catalog"
    case openFoodFactsCommunity = "open_food_facts_community"
    case userEntered = "user_entered"
    case mixed
    case unknown

    var shortLabel: String {
        switch self {
        case .calorynCatalog: "Caloryn data"
        case .openFoodFactsCommunity: "Community data"
        case .userEntered: "Your data"
        case .mixed: "Mixed sources"
        case .unknown: "Source unknown"
        }
    }
}

enum NutritionCompleteness: String, Codable, Sendable {
    case complete
    case partial
    case unknown

    var warningLabel: String? {
        switch self {
        case .complete: nil
        case .partial: "Some nutrition missing"
        case .unknown: "Completeness unknown"
        }
    }

    static func assessingCoreNutrition(
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?
    ) -> NutritionCompleteness {
        protein != nil && carbohydrates != nil && fat != nil ? .complete : .partial
    }
}

struct FoodProvenance: Hashable, Sendable {
    let provider: FoodSearchProvider?
    let source: FoodDataSource
    let completeness: NutritionCompleteness
    let recoveredByFallback: Bool

    static let userEntered = FoodProvenance(
        provider: nil,
        source: .userEntered,
        completeness: .complete,
        recoveredByFallback: false
    )

    static let unknown = FoodProvenance(
        provider: nil,
        source: .unknown,
        completeness: .unknown,
        recoveredByFallback: false
    )

    var warrantsNutritionNotice: Bool {
        switch completeness {
        case .complete: false
        case .partial: true
        case .unknown: source != .unknown
        }
    }

    static func manuallyEntered(completeness: NutritionCompleteness) -> FoodProvenance {
        FoodProvenance(
            provider: nil,
            source: .userEntered,
            completeness: completeness,
            recoveredByFallback: false
        )
    }
}
