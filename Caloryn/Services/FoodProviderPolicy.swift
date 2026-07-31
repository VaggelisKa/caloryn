import Foundation

struct FoodProviderPolicy: Equatable, Sendable {
    let primary: FoodSearchProvider
    let secondary: FoodSearchProvider?

    static let automatic = FoodProviderPolicy(
        primary: .calorynAPI,
        secondary: .openFoodFacts
    )

    init(primary: FoodSearchProvider, secondary: FoodSearchProvider?) {
        self.primary = primary
        self.secondary = secondary == primary ? nil : secondary
    }

    static func only(_ provider: FoodSearchProvider) -> FoodProviderPolicy {
        FoodProviderPolicy(primary: provider, secondary: nil)
    }

    var orderedProviders: [FoodSearchProvider] {
        if let secondary {
            [primary, secondary]
        } else {
            [primary]
        }
    }
}
