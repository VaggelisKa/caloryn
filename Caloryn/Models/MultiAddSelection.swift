import Foundation

struct MultiAddDraftItem: Identifiable, Equatable {
    enum Source: Hashable {
        case local
        case remote(foodID: UUID, result: FoodSearchResult)
    }

    let id: UUID
    let source: Source
    let originMealID: UUID?
    let originMealName: String?
    var snapshot: FoodLogEntrySnapshot

    init(
        id: UUID = UUID(),
        source: Source,
        originMealID: UUID? = nil,
        originMealName: String? = nil,
        snapshot: FoodLogEntrySnapshot
    ) {
        self.id = id
        self.source = source
        self.originMealID = originMealID
        self.originMealName = originMealName
        self.snapshot = snapshot
    }
}

struct MultiAddSelectionGroup: Identifiable, Equatable {
    enum ID: Hashable {
        case food(UUID)
        case remoteProduct(String)
        case meal(UUID)
    }

    let id: ID
    let title: String
    let items: [MultiAddDraftItem]

    @MainActor
    static func savedFood(
        _ food: FoodItem,
        portionGrams: Double,
        meal: MealType,
        snackIndex: Int
    ) -> MultiAddSelectionGroup {
        MultiAddSelectionGroup(
            id: .food(food.id),
            title: food.name,
            items: [
                MultiAddDraftItem(
                    source: .local,
                    snapshot: FoodLogEntrySnapshot(
                        foodItem: food,
                        portionGrams: portionGrams,
                        mealType: meal,
                        snackIndex: snackIndex
                    )
                )
            ]
        )
    }

    @MainActor
    static func remoteProduct(
        _ result: FoodSearchResult,
        searchService: FoodSearchService,
        meal: MealType,
        snackIndex: Int
    ) -> MultiAddSelectionGroup {
        let product = result.product
        let food = searchService.createFoodItem(from: result)
        let stableFoodID = UUID()
        food.id = stableFoodID
        let portion = ContextualFoodSuggestionAdapter.fallbackPortion(for: food)
        return MultiAddSelectionGroup(
            id: .remoteProduct(product.id),
            title: food.name,
            items: [
                MultiAddDraftItem(
                    source: .remote(foodID: stableFoodID, result: result),
                    snapshot: FoodLogEntrySnapshot(
                        foodItem: food,
                        portionGrams: portion,
                        mealType: meal,
                        snackIndex: snackIndex
                    )
                )
            ]
        )
    }

    static func meal(
        _ meal: MealTemplate,
        snapshots: [FoodLogEntrySnapshot]
    ) -> MultiAddSelectionGroup {
        MultiAddSelectionGroup(
            id: .meal(meal.id),
            title: meal.name,
            items: snapshots.map {
                MultiAddDraftItem(
                    source: .local,
                    originMealID: meal.id,
                    originMealName: meal.name,
                    snapshot: $0
                )
            }
        )
    }
}

struct MultiAddSelectionState: Equatable {
    private(set) var groups: [MultiAddSelectionGroup] = []

    var itemCount: Int {
        groups.reduce(0) { $0 + $1.items.count }
    }

    func contains(_ id: MultiAddSelectionGroup.ID) -> Bool {
        groups.contains { $0.id == id }
    }

    mutating func toggle(_ group: MultiAddSelectionGroup) {
        if contains(group.id) {
            remove(group.id)
        } else {
            groups.append(group)
        }
    }

    mutating func remove(_ id: MultiAddSelectionGroup.ID) {
        groups.removeAll { $0.id == id }
    }

    mutating func removeAll() {
        groups.removeAll()
    }
}
