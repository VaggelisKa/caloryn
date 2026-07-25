import SwiftData
import XCTest
@testable import Caloryn

@MainActor
final class BarcodeRecoveryTests: XCTestCase {
    func testNormalizedBarcodeIdentityTrimsOuterWhitespaceAndRejectsNonASCIIDigits() {
        XCTAssertEqual(BarcodeIdentity.normalized("  5711953150388\n"), "5711953150388")
        XCTAssertNil(BarcodeIdentity.normalized("5711 9531"))
        XCTAssertNil(BarcodeIdentity.normalized("١٢٣٤٥٦٧٨"))
        XCTAssertNil(BarcodeIdentity.normalized("123"))
    }

    func testProviderMaterializationTracksProviderMissingAndExplicitZeroFields() throws {
        let product = try decodeProduct(
            """
            {
              "code": "5711953150388",
              "product_name": "Partial Skyr",
              "nutriments": {
                "energy-kcal_100g": 62,
                "carbohydrates_100g": 0,
                "fiber_100g": 0
              }
            }
            """
        )
        let result = makeTestSearchResult(product: product)

        let food = FoodSearchService().createFoodItem(from: result)

        XCTAssertEqual(food.normalizedBarcode, "5711953150388")
        XCTAssertEqual(food.providerProductIdentityRaw, "5711953150388")
        XCTAssertEqual(food.fieldOrigin(for: .name), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .calories), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .protein), .missing)
        XCTAssertEqual(food.fieldOrigin(for: .carbohydrates), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .fiber), .provider)
        XCTAssertEqual(food.carbsPer100g, 0)
        XCTAssertEqual(food.fiberPer100g, 0)
    }

    func testMatchingProviderRefreshFillsMissingRefreshesProviderAndPreservesUserZero() throws {
        let service = FoodSearchService()
        let initial = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Provider Name",
                  "nutriments": {
                    "energy-kcal_100g": 62,
                    "carbohydrates_100g": 4
                  }
                }
                """
            )
        )
        let saved = service.createFoodItem(from: initial)
        let originalID = saved.id
        saved.isCustom = true
        saved.name = "My Skyr"
        saved.setFieldOrigin(.user, for: .name)
        saved.fatPer100g = 0
        saved.setFieldOrigin(.user, for: .fat)

        let refreshed = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "New Provider Name",
                  "nutriments": {
                    "energy-kcal_100g": 64,
                    "proteins_100g": 11,
                    "carbohydrates_100g": 5,
                    "fat_100g": 2
                  }
                }
                """
            ),
            provider: .calorynAPI,
            recoveredByFallback: false
        )

        let resolution = BarcodeRecoveryService.reconcile(
            providerResult: refreshed,
            scannedBarcode: "5711953150388",
            localFoods: [saved]
        )

        guard case .local(let reconciled, let changes) = resolution else {
            return XCTFail("Expected the saved personal food to be reused")
        }
        XCTAssertTrue(reconciled === saved)
        XCTAssertEqual(reconciled.id, originalID)
        XCTAssertEqual(reconciled.name, "My Skyr")
        XCTAssertEqual(reconciled.caloriesPer100g, 64)
        XCTAssertEqual(reconciled.proteinPer100g, 11)
        XCTAssertEqual(reconciled.carbsPer100g, 5)
        XCTAssertEqual(reconciled.fatPer100g, 0)
        XCTAssertEqual(reconciled.fieldOrigin(for: .protein), .provider)
        XCTAssertEqual(reconciled.fieldOrigin(for: .fat), .user)
        XCTAssertTrue(changes.filledMissingFields)
        XCTAssertTrue(changes.refreshedProviderFields)
    }

    func testProviderIdentityMismatchPreservesPersonalMaterialization() throws {
        let service = FoodSearchService()
        let original = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Original",
                  "nutriments": { "energy-kcal_100g": 62 }
                }
                """
            )
        )
        let saved = service.createFoodItem(from: original)
        saved.isCustom = true
        saved.name = "My Safe Version"
        saved.providerProductIdentityRaw = "99999999"

        let incoming = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Untrusted Replacement",
                  "nutriments": { "energy-kcal_100g": 900 }
                }
                """
            )
        )

        let resolution = BarcodeRecoveryService.reconcile(
            providerResult: incoming,
            scannedBarcode: "5711953150388",
            localFoods: [saved]
        )

        guard case .local(let preserved, let changes) = resolution else {
            return XCTFail("Expected the personal version to be preserved")
        }
        XCTAssertTrue(preserved === saved)
        XCTAssertEqual(preserved.name, "My Safe Version")
        XCTAssertEqual(preserved.caloriesPer100g, 62)
        XCTAssertEqual(changes, .none)
    }

    func testOfflineFallbackReusesLatestPersonalFoodWithoutCreatingDuplicate() {
        let providerCopy = makeTestFoodItem(name: "Provider Copy")
        providerCopy.barcode = " 5711953150388 "
        providerCopy.lastUsed = Date(timeIntervalSince1970: 300)

        let olderPersonal = makeTestFoodItem(name: "Older Personal", isCustom: true)
        olderPersonal.barcode = "5711953150388"
        olderPersonal.lastUsed = Date(timeIntervalSince1970: 100)

        let latestPersonal = makeTestFoodItem(name: "Latest Personal", isCustom: true)
        latestPersonal.barcode = "5711953150388"
        latestPersonal.lastUsed = Date(timeIntervalSince1970: 200)

        let fallback = BarcodeRecoveryService.localFallback(
            for: "5711953150388",
            localFoods: [providerCopy, olderPersonal, latestPersonal]
        )

        XCTAssertTrue(fallback === latestPersonal)
    }

    func testReconciliationPreservesFoodIdentityFavoriteRelationshipAndHistoricalSnapshot() throws {
        let service = FoodSearchService()
        let original = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Saved Skyr",
                  "nutriments": {
                    "energy-kcal_100g": 60,
                    "proteins_100g": 10,
                    "carbohydrates_100g": 4,
                    "fat_100g": 1
                  }
                }
                """
            )
        )
        let saved = service.createFoodItem(from: original)
        saved.isCustom = true
        saved.setFavorite(true)
        let originalID = saved.id
        let historicalEntry = makeTestEntry(foodItem: saved, portionGrams: 100)
        let historicalNutrition = historicalEntry.nutrition

        let refreshed = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Saved Skyr",
                  "nutriments": {
                    "energy-kcal_100g": 80,
                    "proteins_100g": 12,
                    "carbohydrates_100g": 5,
                    "fat_100g": 2
                  }
                }
                """
            )
        )

        _ = BarcodeRecoveryService.reconcile(
            providerResult: refreshed,
            scannedBarcode: "5711953150388",
            localFoods: [saved]
        )

        XCTAssertEqual(saved.id, originalID)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertTrue(historicalEntry.foodItem === saved)
        XCTAssertEqual(historicalEntry.nutrition, historicalNutrition)
        XCTAssertEqual(historicalEntry.calories, 60)
        XCTAssertEqual(saved.caloriesPer100g, 80)
    }

    func testFieldOriginsAndProviderIdentityPersistAsOptionalSwiftDataScalars() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: FoodItem.self,
            FoodLogEntry.self,
            RecipeIngredient.self,
            configurations: configuration
        )
        let product = try decodeProduct(
            """
            {
              "code": "5711953150388",
              "product_name": "Persisted",
              "nutriments": {
                "energy-kcal_100g": 60,
                "proteins_100g": 0
              }
            }
            """
        )
        let food = FoodSearchService().createFoodItem(
            from: makeTestSearchResult(product: product)
        )
        food.setFieldOrigin(.user, for: .protein)
        container.mainContext.insert(food)
        try container.mainContext.save()

        let fetched = try XCTUnwrap(
            container.mainContext.fetch(FetchDescriptor<FoodItem>()).first
        )
        XCTAssertEqual(fetched.providerProductIdentityRaw, "5711953150388")
        XCTAssertNotNil(fetched.fieldOriginsRaw)
        XCTAssertEqual(fetched.fieldOrigin(for: .protein), .user)
        XCTAssertEqual(fetched.fieldOrigin(for: .fat), .missing)
    }

    func testLegacyPersonalFoodWithoutRecoveryMetadataRemainsReadableAndConservative() throws {
        let legacy = makeTestFoodItem(
            name: "Legacy Personal",
            fatPer100g: 0,
            isCustom: true
        )
        legacy.barcode = "5711953150388"
        legacy.providerProductIdentityRaw = nil
        legacy.fieldOriginsRaw = nil

        XCTAssertEqual(legacy.normalizedBarcode, "5711953150388")
        XCTAssertEqual(legacy.fieldOrigin(for: .fat), .user)
        XCTAssertEqual(legacy.fieldOrigin(for: .sugars), .missing)

        let incoming = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Provider Replacement",
                  "nutriments": {
                    "energy-kcal_100g": 500,
                    "fat_100g": 30
                  }
                }
                """
            )
        )
        let resolution = BarcodeRecoveryService.reconcile(
            providerResult: incoming,
            scannedBarcode: "5711953150388",
            localFoods: [legacy]
        )

        guard case .local(let preserved, let changes) = resolution else {
            return XCTFail("Expected conservative legacy fallback")
        }
        XCTAssertTrue(preserved === legacy)
        XCTAssertEqual(preserved.fatPer100g, 0)
        XCTAssertEqual(changes, .none)
    }

    func testPersonalCorrectionMarksOnlyChangedOrExplicitlySuppliedMissingFieldsAsUser() throws {
        let product = try decodeProduct(
            """
            {
              "code": "5711953150388",
              "product_name": "Provider Skyr",
              "brands": "Dairy",
              "nutriments": {
                "energy-kcal_100g": 62,
                "carbohydrates_100g": 4
              }
            }
            """
        )
        let food = FoodSearchService().createFoodItem(
            from: makeTestSearchResult(product: product)
        )

        BarcodeRecoveryService.applyPersonalEdit(
            FoodPersonalEdit(
                name: "My Skyr",
                brand: "Dairy",
                caloriesPer100g: 62,
                proteinPer100g: nil,
                carbohydratesPer100g: 4,
                fatPer100g: 0,
                fiberPer100g: nil,
                defaultServingG: nil,
                produceKind: .unclassified
            ),
            to: food
        )

        XCTAssertTrue(food.isCustom)
        XCTAssertEqual(food.providerProductIdentityRaw, "5711953150388")
        XCTAssertEqual(food.fieldOrigin(for: .name), .user)
        XCTAssertEqual(food.fieldOrigin(for: .brand), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .calories), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .protein), .missing)
        XCTAssertEqual(food.fieldOrigin(for: .fat), .user)
        XCTAssertEqual(food.fatPer100g, 0)
        XCTAssertEqual(food.provenance.source, .mixed)
        XCTAssertEqual(food.provenance.completeness, .partial)
    }

    func testPersonalEditorUsesActuallyEditedFieldsInsteadOfFormattedRoundTripValues() throws {
        let product = try decodeProduct(
            """
            {
              "code": "5711953150388",
              "product_name": "Provider Skyr",
              "nutriments": {
                "energy-kcal_100g": 62,
                "proteins_100g": 10.25,
                "carbohydrates_100g": 4
              }
            }
            """
        )
        let food = FoodSearchService().createFoodItem(
            from: makeTestSearchResult(product: product)
        )

        BarcodeRecoveryService.applyPersonalEdit(
            FoodPersonalEdit(
                name: "Formatted Provider Skyr",
                brand: nil,
                caloriesPer100g: 61.999,
                proteinPer100g: 10.222,
                carbohydratesPer100g: 4,
                fatPer100g: 0,
                fiberPer100g: nil,
                defaultServingG: nil,
                produceKind: .unclassified,
                userEditedFields: [.fat]
            ),
            to: food
        )

        XCTAssertEqual(food.name, "Provider Skyr")
        XCTAssertEqual(food.caloriesPer100g, 62)
        XCTAssertEqual(food.proteinPer100g, 10.25)
        XCTAssertEqual(food.fieldOrigin(for: .name), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .calories), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .protein), .provider)
        XCTAssertEqual(food.fieldOrigin(for: .fat), .user)
    }

    func testUnknownBarcodeManualRecoveryNormalizesAndReusesExistingPrivateFood() {
        let existing = makeTestFoodItem(name: "Existing", isCustom: true)
        existing.barcode = " 5711953150388 "
        let originalID = existing.id
        let edit = FoodPersonalEdit(
            name: "Recovered",
            brand: nil,
            caloriesPer100g: 100,
            proteinPer100g: 0,
            carbohydratesPer100g: 20,
            fatPer100g: 5,
            fiberPer100g: nil,
            defaultServingG: 100,
            produceKind: .unclassified
        )

        let materialization = BarcodeRecoveryService.materializePersonalFood(
            barcode: "\n5711953150388 ",
            edit: edit,
            localFoods: [existing]
        )

        XCTAssertTrue(materialization.food === existing)
        XCTAssertFalse(materialization.isNew)
        XCTAssertEqual(materialization.food.id, originalID)
        XCTAssertEqual(materialization.food.name, "Recovered")
        XCTAssertEqual(materialization.food.barcode, "5711953150388")
        XCTAssertNil(materialization.food.providerProductIdentityRaw)
    }

    func testNewUnknownManualFoodTracksOmittedFieldsAsMissingAndExplicitZeroAsUser() {
        let materialization = BarcodeRecoveryService.materializePersonalFood(
            barcode: " 5711953150388 ",
            edit: FoodPersonalEdit(
                name: "Recovered",
                brand: nil,
                caloriesPer100g: 100,
                proteinPer100g: nil,
                carbohydratesPer100g: nil,
                fatPer100g: 0,
                fiberPer100g: nil,
                defaultServingG: nil,
                produceKind: .unclassified,
                userEditedFields: [.name, .calories, .fat]
            ),
            localFoods: []
        )

        XCTAssertTrue(materialization.isNew)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .name), .user)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .calories), .user)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .fat), .user)
        XCTAssertEqual(materialization.food.fatPer100g, 0)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .protein), .missing)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .carbohydrates), .missing)
        XCTAssertEqual(materialization.food.fieldOrigin(for: .defaultServing), .missing)
    }

    func testDuplicateManualRecoveryPreservesExistingFieldsOmittedFromTheDraft() {
        let existing = makeTestFoodItem(name: "Recovered", isCustom: true)
        existing.barcode = "5711953150388"
        existing.proteinPer100g = 12
        existing.setFieldOrigin(.user, for: .protein)

        let materialization = BarcodeRecoveryService.materializePersonalFood(
            barcode: "5711953150388",
            edit: FoodPersonalEdit(
                name: "Renamed",
                brand: nil,
                caloriesPer100g: 100,
                proteinPer100g: nil,
                carbohydratesPer100g: nil,
                fatPer100g: nil,
                fiberPer100g: nil,
                defaultServingG: nil,
                produceKind: .unclassified,
                userEditedFields: [.name, .calories]
            ),
            localFoods: [existing]
        )

        XCTAssertTrue(materialization.food === existing)
        XCTAssertFalse(materialization.isNew)
        XCTAssertEqual(existing.proteinPer100g, 12)
        XCTAssertEqual(existing.fieldOrigin(for: .protein), .user)
    }

    func testEditingDuplicateBarcodePreservesTheExplicitlySelectedFood() {
        let selected = makeTestFoodItem(name: "Selected", isCustom: true)
        selected.barcode = "5711953150388"
        selected.lastUsed = makeTestDate(year: 2026, month: 7, day: 20)

        let moreRecentDuplicate = makeTestFoodItem(
            name: "More Recent Duplicate",
            isCustom: true
        )
        moreRecentDuplicate.barcode = selected.barcode
        moreRecentDuplicate.lastUsed = makeTestDate(
            year: 2026,
            month: 7,
            day: 21
        )

        let materialization = BarcodeRecoveryService.materializePersonalFood(
            barcode: "5711953150388",
            edit: FoodPersonalEdit(
                name: "Edited Selected",
                brand: nil,
                caloriesPer100g: 123,
                proteinPer100g: nil,
                carbohydratesPer100g: nil,
                fatPer100g: nil,
                fiberPer100g: nil,
                defaultServingG: nil,
                produceKind: .unclassified,
                userEditedFields: [.name, .calories]
            ),
            localFoods: [moreRecentDuplicate, selected],
            editing: selected
        )

        XCTAssertTrue(materialization.food === selected)
        XCTAssertFalse(materialization.isNew)
        XCTAssertEqual(selected.name, "Edited Selected")
        XCTAssertEqual(selected.caloriesPer100g, 123)
        XCTAssertEqual(moreRecentDuplicate.name, "More Recent Duplicate")
        XCTAssertEqual(moreRecentDuplicate.caloriesPer100g, 100)
    }

    func testOnlineResolutionChecksProviderFirstAndRetryReusesSameFoodIdempotently() async throws {
        let service = FoodSearchService()
        let initial = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Saved",
                  "nutriments": { "energy-kcal_100g": 60 }
                }
                """
            )
        )
        let saved = service.createFoodItem(from: initial)
        saved.isCustom = true
        let originalID = saved.id
        let refreshed = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Saved",
                  "nutriments": {
                    "energy-kcal_100g": 70,
                    "proteins_100g": 10
                  }
                }
                """
            )
        )
        var providerCalls = 0

        for _ in 0..<2 {
            let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
                barcode: "5711953150388",
                localFoods: [saved]
            ) { barcode in
                providerCalls += 1
                XCTAssertEqual(barcode, "5711953150388")
                return refreshed
            }
            guard case .local(let resolved, _) = outcome else {
                return XCTFail("Expected in-place local reconciliation")
            }
            XCTAssertTrue(resolved === saved)
        }

        XCTAssertEqual(providerCalls, 2)
        XCTAssertEqual(saved.id, originalID)
        XCTAssertEqual(saved.caloriesPer100g, 70)
        XCTAssertEqual(saved.proteinPer100g, 10)
    }

    func testTypedProviderFailureUsesSafeLocalFallbackButKeepsUnknownFailureAccurate() async {
        let local = makeTestFoodItem(name: "Offline Safe Copy", isCustom: true)
        local.barcode = "5711953150388"

        let offlineOutcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: "5711953150388",
            localFoods: [local]
        ) { _ in
            throw FoodLookupError.offline
        }
        guard case .local(let fallback, let changes) = offlineOutcome else {
            return XCTFail("Expected offline local fallback")
        }
        XCTAssertTrue(fallback === local)
        XCTAssertEqual(changes, .none)

        let unknownOutcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: "12345678",
            localFoods: []
        ) { _ in
            throw FoodLookupError.notFound
        }
        guard case .failure(let failure) = unknownOutcome else {
            return XCTFail("Expected an authoritative not-found outcome")
        }
        XCTAssertEqual(failure, .notFound)
    }

    func testRecoveryAnalyticsSchemaContainsOnlyAggregateAllowlistedDimensions() {
        let event = BarcodeRecoveryAnalyticsEvent(
            path: .providerReconciliation,
            result: .completed,
            filledMissingFields: true,
            refreshedProviderFields: false
        )

        XCTAssertEqual(
            Set(Mirror(reflecting: event).children.compactMap(\.label)),
            Set([
                "path",
                "result",
                "filledMissingFields",
                "refreshedProviderFields",
            ])
        )
        XCTAssertEqual(
            Set(event.payload.keys),
            Set([
                "path",
                "result",
                "filled_missing_fields",
                "refreshed_provider_fields",
            ])
        )
    }

    func testReconciledFoodRemainsCompatibleWithFoodIngredientMealAndMultiAddDrafts() throws {
        let original = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Reusable Skyr",
                  "nutriments": {
                    "energy-kcal_100g": 60,
                    "proteins_100g": 10,
                    "carbohydrates_100g": 4,
                    "fat_100g": 1
                  }
                }
                """
            )
        )
        let food = FoodSearchService().createFoodItem(from: original)
        food.isCustom = true
        let sourceID = food.id
        let refreshed = makeTestSearchResult(
            product: try decodeProduct(
                """
                {
                  "code": "5711953150388",
                  "product_name": "Reusable Skyr",
                  "nutriments": {
                    "energy-kcal_100g": 80,
                    "proteins_100g": 12,
                    "carbohydrates_100g": 5,
                    "fat_100g": 2
                  }
                }
                """
            )
        )
        _ = BarcodeRecoveryService.reconcile(
            providerResult: refreshed,
            scannedBarcode: "5711953150388",
            localFoods: [food]
        )

        let directSnapshot = FoodLogEntrySnapshot(foodItem: food, portionGrams: 100)
        let ingredient = RecipeIngredient(from: food, portionGrams: 100, sortOrder: 0)
        let mealSnapshot = FoodLogEntrySnapshot(foodItem: food, portionGrams: 150)
        let multiAddGroup = MultiAddSelectionGroup.savedFood(
            food,
            portionGrams: 125,
            meal: .snack,
            snackIndex: 3
        )

        XCTAssertEqual(directSnapshot.sourceFoodID, sourceID)
        XCTAssertEqual(directSnapshot.nutrition.calories, 80)
        XCTAssertEqual(ingredient.caloriesPer100g, 80)
        XCTAssertEqual(mealSnapshot.sourceFoodID, sourceID)
        XCTAssertEqual(mealSnapshot.nutrition.calories, 120)
        XCTAssertEqual(multiAddGroup.id, .food(sourceID))
        XCTAssertEqual(multiAddGroup.items.first?.snapshot.sourceFoodID, sourceID)
        XCTAssertEqual(multiAddGroup.items.first?.snapshot.mealType, .snack)
        XCTAssertEqual(multiAddGroup.items.first?.snapshot.snackIndex, 3)
    }

    private func decodeProduct(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }
}
