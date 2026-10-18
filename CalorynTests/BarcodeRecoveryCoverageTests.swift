import Foundation
import Testing
@testable import Caloryn

@MainActor
struct BarcodeRecoveryCoverageTests {
    private static let barcode = "5711953150388"

    private static func product(_ json: String) throws -> OpenFoodFactsProduct {
        try JSONDecoder().decode(OpenFoodFactsProduct.self, from: Data(json.utf8))
    }

    private static func providerResult(
        code: String? = barcode,
        name: String = "Provider Skyr",
        nutriments: String = #""energy-kcal_100g": 64, "proteins_100g": 11, "carbohydrates_100g": 5, "fat_100g": 2"#
    ) throws -> FoodSearchResult {
        let codeField = code.map { #""code": ""# + $0 + #"", "# } ?? ""
        return makeTestSearchResult(
            product: try product(
                "{" + codeField + #""product_name": ""# + name + #"", "nutriments": {"# + nutriments + "}}"
            )
        )
    }

    private static func personalFood(name: String = "My Skyr") -> FoodItem {
        let food = makeTestFoodItem(name: name, caloriesPer100g: 60, isCustom: true)
        food.barcode = barcode
        return food
    }

    private struct UnrelatedFailure: Error {}

    @Test("An unreadable barcode fails before the provider is asked", arguments: ["12", "abc123456", "", "١٢٣٤٥٦٧٨"])
    func invalidBarcode(_ barcode: String) async {
        var providerCalls = 0

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: barcode,
            localFoods: [Self.personalFood()]
        ) { _ in
            providerCalls += 1
            return try Self.providerResult()
        }

        guard case .failure(let error) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(error == .invalidRequest)
        #expect(providerCalls == 0)
    }

    @Test("The provider is asked with the trimmed barcode and its product is returned when nothing is saved")
    func remoteResultWithoutLocalFood() async throws {
        let incoming = try Self.providerResult()
        var askedFor: [String] = []

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: "  \(Self.barcode)\n",
            localFoods: []
        ) { barcode in
            askedFor.append(barcode)
            return incoming
        }

        guard case .remote(let result) = outcome else {
            Issue.record("Expected the provider result, got \(outcome)")
            return
        }
        #expect(askedFor == [Self.barcode])
        #expect(result == incoming)
    }

    @Test("A provider product for a different barcode is treated as invalid data")
    func mismatchedProviderProductWithoutLocalFood() async throws {
        let wrongProduct = try Self.providerResult(code: "4000000000001")

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: []
        ) { _ in wrongProduct }

        guard case .failure(let error) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(error == .invalidData)
    }

    @Test("A provider product for a different barcode falls back to the saved food untouched")
    func mismatchedProviderProductWithLocalFood() async throws {
        let saved = Self.personalFood()
        let wrongProduct = try Self.providerResult(code: "4000000000001", name: "Wrong Product")

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: [saved]
        ) { _ in wrongProduct }

        guard case .local(let food, let changes) = outcome else {
            Issue.record("Expected the saved food, got \(outcome)")
            return
        }
        #expect(food === saved)
        #expect(changes == .none)
        #expect(saved.name == "My Skyr")
        #expect(saved.caloriesPer100g == 60)
        #expect(saved.providerProductIdentityRaw == nil)
    }

    @Test(
        "Cancellation and invalid requests are reported even when a saved food exists",
        arguments: [FoodLookupError.cancelled, .invalidRequest]
    )
    func failuresThatSkipLocalFallback(_ failure: FoodLookupError) async {
        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: [Self.personalFood()]
        ) { _ in throw failure }

        guard case .failure(let error) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(error == failure)
    }

    @Test(
        "Provider outages fall back to the saved food",
        arguments: [FoodLookupError.offline, .unavailable, .notFound, .invalidData, .rateLimited, .unauthorized]
    )
    func failuresThatUseLocalFallback(_ failure: FoodLookupError) async {
        let saved = Self.personalFood()

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: [saved]
        ) { _ in throw failure }

        guard case .local(let food, let changes) = outcome else {
            Issue.record("Expected the saved food, got \(outcome)")
            return
        }
        #expect(food === saved)
        #expect(changes == .none)
    }

    @Test("An unrecognised provider error falls back to the saved food")
    func unrecognisedErrorWithLocalFood() async {
        let saved = Self.personalFood()

        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: [saved]
        ) { _ in throw UnrelatedFailure() }

        guard case .local(let food, let changes) = outcome else {
            Issue.record("Expected the saved food, got \(outcome)")
            return
        }
        #expect(food === saved)
        #expect(changes == .none)
    }

    @Test("An unrecognised provider error with nothing saved is reported as unavailable")
    func unrecognisedErrorWithoutLocalFood() async {
        let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
            barcode: Self.barcode,
            localFoods: []
        ) { _ in throw UnrelatedFailure() }

        guard case .failure(let error) = outcome else {
            Issue.record("Expected a failure, got \(outcome)")
            return
        }
        #expect(error == .unavailable)
    }

    @Test("Reconciling needs a readable scanned barcode and a provider code")
    func reconcileRejectsUnreadableIdentities() throws {
        let saved = Self.personalFood()

        let unreadableScan = BarcodeRecoveryService.reconcile(
            providerResult: try Self.providerResult(),
            scannedBarcode: "not-a-barcode",
            localFoods: [saved]
        )
        let codelessProduct = BarcodeRecoveryService.reconcile(
            providerResult: try Self.providerResult(code: nil),
            scannedBarcode: Self.barcode,
            localFoods: []
        )

        guard case .invalidProviderData = unreadableScan else {
            Issue.record("Expected invalid provider data, got \(unreadableScan)")
            return
        }
        guard case .invalidProviderData = codelessProduct else {
            Issue.record("Expected invalid provider data, got \(codelessProduct)")
            return
        }
    }

    @Test("A legacy provider copy is refreshed in place and its gaps are filled")
    func legacyProviderCopyIsRefreshed() throws {
        let legacyProvenance = FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .complete,
            recoveredByFallback: false
        )
        let legacy = FoodItem(
            name: "Old Provider Name",
            barcode: Self.barcode,
            caloriesPer100g: 60,
            proteinPer100g: 10,
            carbsPer100g: 4,
            fatPer100g: 0,
            provenance: legacyProvenance
        )
        let originalID = legacy.id
        let incoming = try Self.providerResult(
            name: "New Provider Name",
            nutriments: """
            "energy-kcal_100g": 64, "proteins_100g": 11, "carbohydrates_100g": 5, "fat_100g": 2,
            "sugars_100g": 4.5, "monounsaturated-fat_100g": 0.5, "polyunsaturated-fat_100g": 0.3
            """
        )

        let resolution = BarcodeRecoveryService.reconcile(
            providerResult: incoming,
            scannedBarcode: Self.barcode,
            localFoods: [legacy]
        )

        guard case .local(let food, let changes) = resolution else {
            Issue.record("Expected an in-place reconciliation, got \(resolution)")
            return
        }
        #expect(food === legacy)
        #expect(food.id == originalID)
        #expect(changes == BarcodeReconciliationChanges(filledMissingFields: true, refreshedProviderFields: true))
        #expect(food.name == "New Provider Name")
        #expect(food.caloriesPer100g == 64)
        #expect(food.proteinPer100g == 11)
        #expect(food.carbsPer100g == 5)
        #expect(food.fatPer100g == 2)
        #expect(food.sugarsPer100g == 4.5)
        #expect(food.monounsaturatedFatPer100g == 0.5)
        #expect(food.polyunsaturatedFatPer100g == 0.3)
        #expect(food.fieldOrigin(for: .sugars) == .provider)
        #expect(food.fieldOrigin(for: .monounsaturatedFat) == .provider)
        #expect(food.fieldOrigin(for: .polyunsaturatedFat) == .provider)
        #expect(food.providerProductIdentityRaw == Self.barcode)
        #expect(food.isEditedCatalogProduct == false)
        #expect(food.provenance == FoodProvenance(
            provider: .openFoodFacts,
            source: .openFoodFactsCommunity,
            completeness: .complete,
            recoveredByFallback: true
        ))
    }

    @Test("Reconciling an unchanged provider copy reports no changes")
    func unchangedProviderCopy() throws {
        let incoming = try Self.providerResult()
        let saved = FoodSearchService().createFoodItem(from: incoming)

        let resolution = BarcodeRecoveryService.reconcile(
            providerResult: incoming,
            scannedBarcode: Self.barcode,
            localFoods: [saved]
        )

        guard case .local(let food, let changes) = resolution else {
            Issue.record("Expected an in-place reconciliation, got \(resolution)")
            return
        }
        #expect(food === saved)
        #expect(changes == .none)
    }

    @Test("Unknown persisted origin entries are ignored and the rest still apply")
    func unknownPersistedOriginEntries() {
        let food = makeTestFoodItem(
            name: "Community Food",
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        food.fieldOriginsRaw = #"{"name": "user", "notAField": "provider", "fat": "guessed"}"#

        #expect(food.fieldOrigin(for: .name) == .user)
        #expect(food.fieldOrigin(for: .fat) == .provider)
        #expect(food.fieldOrigin(for: .sugars) == .missing)

        food.setFieldOrigin(.user, for: .sugars)

        #expect(food.fieldOrigin(for: .name) == .user)
        #expect(food.fieldOrigin(for: .sugars) == .user)
        #expect(food.fieldOriginsRaw?.contains("notAField") == false)
    }

    @Test("Unreadable persisted origins fall back to the legacy inference")
    func unreadablePersistedOrigins() {
        let food = makeTestFoodItem(
            name: "Community Food",
            brand: "  ",
            provenance: FoodProvenance(
                provider: .calorynAPI,
                source: .calorynCatalog,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        food.fieldOriginsRaw = "not json"

        #expect(food.fieldOrigin(for: .name) == .provider)
        #expect(food.fieldOrigin(for: .calories) == .provider)
        #expect(food.fieldOrigin(for: .brand) == .missing)
        #expect(food.fieldOrigin(for: .sodium) == .missing)
    }

    @Test("A legacy food with a blank name reads its name as missing")
    func blankLegacyName() {
        let food = makeTestFoodItem(name: "  ")

        #expect(food.fieldOrigin(for: .name) == .missing)
    }

    private static func edit(
        produceKind: ProduceKind,
        userEditedFields: Set<FoodField>? = nil
    ) -> FoodPersonalEdit {
        FoodPersonalEdit(
            name: "Apples",
            brand: nil,
            caloriesPer100g: 52,
            proteinPer100g: 0.3,
            carbohydratesPer100g: 14,
            fatPer100g: 0.2,
            fiberPer100g: 2.4,
            defaultServingG: nil,
            produceKind: produceKind,
            userEditedFields: userEditedFields
        )
    }

    private static func appleProduct() throws -> FoodItem {
        let result = makeTestSearchResult(
            product: try product(
                """
                {
                  "code": "\(barcode)",
                  "product_name": "Apples",
                  "categories_tags": ["en:apples"],
                  "nutriments": {
                    "energy-kcal_100g": 52,
                    "proteins_100g": 0.3,
                    "carbohydrates_100g": 14,
                    "fat_100g": 0.2,
                    "fiber_100g": 2.4
                  }
                }
                """
            )
        )
        return FoodSearchService().createFoodItem(from: result)
    }

    @Test("Editing a legacy provider copy claims every stored value as the user's")
    func legacyCopyEditBecomesUserData() {
        let legacy = makeTestFoodItem(
            name: "Apples",
            categoryTags: ["en:apples"],
            provenance: FoodProvenance(
                provider: .openFoodFacts,
                source: .openFoodFactsCommunity,
                completeness: .complete,
                recoveredByFallback: false
            )
        )
        legacy.barcode = Self.barcode
        #expect(legacy.fieldOrigin(for: .name) == .provider)

        BarcodeRecoveryService.applyPersonalEdit(Self.edit(produceKind: .vegetable), to: legacy)

        #expect(legacy.isCustom)
        #expect(legacy.produceKind == .vegetable)
        #expect(legacy.fieldOrigin(for: .name) == .user)
        #expect(legacy.provenance.source == .userEntered)
        #expect(legacy.provenance.provider == nil)
    }

    @Test("Changing a food's produce kind replaces its category tags")
    func changedProduceKind() throws {
        let food = try Self.appleProduct()
        #expect(food.produceKind == .fruit)

        BarcodeRecoveryService.applyPersonalEdit(Self.edit(produceKind: .vegetable), to: food)

        #expect(food.produceKind == .vegetable)
        #expect(food.fieldOrigin(for: .produceKind) == .user)
        #expect(food.categoryTags.isEmpty)
        #expect(food.fieldOrigin(for: .categoryTags) == .missing)
        #expect(food.isCustom)
        #expect(food.provenance.source == .mixed)
        #expect(food.provenance.provider == .openFoodFacts)
    }

    @Test("An explicitly confirmed produce kind is recorded as the user's even when unchanged")
    func explicitlyConfirmedProduceKind() throws {
        let food = try Self.appleProduct()

        BarcodeRecoveryService.applyPersonalEdit(
            Self.edit(produceKind: .fruit, userEditedFields: [.produceKind]),
            to: food
        )

        #expect(food.produceKind == .fruit)
        #expect(food.fieldOrigin(for: .produceKind) == .user)
        #expect(food.categoryTags.isEmpty)
        #expect(food.name == "Apples")
        #expect(food.fieldOrigin(for: .name) == .provider)
    }

    @Test("A produce kind outside the explicitly edited fields is left alone")
    func produceKindNotEdited() throws {
        let food = try Self.appleProduct()

        BarcodeRecoveryService.applyPersonalEdit(
            Self.edit(produceKind: .vegetable, userEditedFields: [.name]),
            to: food
        )

        #expect(food.produceKind == .fruit)
        #expect(food.categoryTags == ["en:apples"])
        #expect(food.fieldOrigin(for: .name) == .user)
    }

    @Test("A provider result without a barcode is never hidden by an edited product")
    func codelessProviderResultsStayVisible() throws {
        let edited = Self.personalFood()
        edited.providerProductIdentityRaw = Self.barcode
        let codeless = try Self.providerResult(code: nil, name: "Loose Apples")
        let nonNumeric = try Self.providerResult(code: "bakery-7", name: "Bakery Loaf")
        let overlaid = try Self.providerResult(name: "Provider Skyr")

        let visible = EditedProductCatalog.providerResults(
            [codeless, nonNumeric, overlaid],
            excludingProductsOverlaidBy: [edited]
        )

        #expect(visible.map(\.product.productName) == ["Loose Apples", "Bakery Loaf"])
    }
}
