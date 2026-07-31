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

    var detailLabel: String {
        switch self {
        case .calorynCatalog: "Nutrition data from Caloryn"
        case .openFoodFactsCommunity: "Community-provided data from Open Food Facts"
        case .userEntered: "Nutrition data entered by you"
        case .mixed: "Nutrition data combined from multiple sources"
        case .unknown: "The original data source was not recorded"
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

    /// A nil input means the user cleared or did not supply that core field;
    /// zero remains a valid, explicitly supplied nutrition value.
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

    /// Whether this food's nutrition is worth warning the user about.
    ///
    /// `.unknown` completeness means two different things, and the source is
    /// what tells them apart. A food whose source is *also* unknown simply
    /// predates these fields — every food saved before they existed reads that
    /// way, so a notice there is permanent, universal, and describes our schema
    /// rather than the food. But a food from a known provider that still has
    /// unknown completeness got there through `hasMinimumUsableNutrition`
    /// failing or a recipe ingredient of unknown completeness: its numbers
    /// really may be unusable, and that is worth saying.
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
