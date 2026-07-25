import Foundation

enum EditedProductCatalog {
    static func products(
        in foods: [FoodItem],
        matching query: String
    ) -> [FoodItem] {
        let editedProducts = foods.filter(\.isEditedCatalogProduct)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return editedProducts }

        return editedProducts.filter { food in
            food.name.localizedCaseInsensitiveContains(trimmedQuery)
                || food.brand?.localizedCaseInsensitiveContains(trimmedQuery) == true
                || food.normalizedBarcode?.contains(trimmedQuery) == true
        }
    }
}
