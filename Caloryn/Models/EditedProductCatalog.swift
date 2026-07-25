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

    static func providerResults(
        _ results: [FoodSearchResult],
        excludingProductsOverlaidBy products: [FoodItem]
    ) -> [FoodSearchResult] {
        let overlaidIdentities = Set(
            products.compactMap {
                BarcodeIdentity.normalized($0.providerProductIdentityRaw)
            }
        )

        return results.filter { result in
            guard let identity = BarcodeIdentity.normalized(result.product.code) else {
                return true
            }
            return !overlaidIdentities.contains(identity)
        }
    }

    static func loggingProducts(
        in foods: [FoodItem],
        matching query: String,
        providerResults: [FoodSearchResult]
    ) -> [FoodItem] {
        let directlyMatchingIDs = Set(
            products(in: foods, matching: query).map(\.id)
        )
        let providerIdentities = Set(
            providerResults.compactMap {
                BarcodeIdentity.normalized($0.product.code)
            }
        )

        return foods.filter { food in
            guard food.isEditedCatalogProduct else { return false }
            if directlyMatchingIDs.contains(food.id) {
                return true
            }
            guard let identity = BarcodeIdentity.normalized(
                food.providerProductIdentityRaw
            ) else {
                return false
            }
            return providerIdentities.contains(identity)
        }
    }
}
