import Foundation
import OSLog

enum BarcodeIdentity {
    static func normalized(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (4...32).contains(trimmed.utf8.count),
              trimmed.utf8.allSatisfy({ (48...57).contains($0) }) else {
            return nil
        }
        return trimmed
    }
}

enum BarcodeRecoveryAnalyticsPath: String, Sendable {
    case nameSearch = "name_search"
    case manualCreation = "manual_creation"
    case localFallback = "local_fallback"
    case providerReconciliation = "provider_reconciliation"
    case personalEdit = "personal_edit"
}

enum BarcodeRecoveryAnalyticsResult: String, Sendable {
    case started
    case completed
    case reused
    case failed
}

/// Deliberately allowlisted aggregate dimensions. This type cannot carry a
/// barcode, food/provider payload, persistent ID, nutrition value, or context.
struct BarcodeRecoveryAnalyticsEvent: Equatable, Sendable {
    let path: BarcodeRecoveryAnalyticsPath
    let result: BarcodeRecoveryAnalyticsResult
    let filledMissingFields: Bool
    let refreshedProviderFields: Bool

    var payload: [String: String] {
        [
            "path": path.rawValue,
            "result": result.rawValue,
            "filled_missing_fields": String(filledMissingFields),
            "refreshed_provider_fields": String(refreshedProviderFields),
        ]
    }
}

enum BarcodeRecoveryAnalytics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.caloryn",
        category: "BarcodeRecovery"
    )

    static func record(
        path: BarcodeRecoveryAnalyticsPath,
        result: BarcodeRecoveryAnalyticsResult,
        changes: BarcodeReconciliationChanges = .none
    ) {
        let event = BarcodeRecoveryAnalyticsEvent(
            path: path,
            result: result,
            filledMissingFields: changes.filledMissingFields,
            refreshedProviderFields: changes.refreshedProviderFields
        )
        logger.info(
            "recovery path=\(event.path.rawValue, privacy: .public) result=\(event.result.rawValue, privacy: .public) filled_missing=\(event.filledMissingFields, privacy: .public) refreshed_provider=\(event.refreshedProviderFields, privacy: .public)"
        )
    }
}

enum FoodFieldOrigin: String, Codable, Equatable, Sendable {
    case missing
    case provider
    case user
}

enum FoodField: String, CaseIterable, Codable, Hashable, Sendable {
    case name
    case brand
    case calories
    case protein
    case carbohydrates
    case fat
    case fiber
    case sugars
    case addedSugars
    case sucrose
    case glucose
    case fructose
    case lactose
    case maltose
    case maltodextrins
    case starch
    case polyols
    case saturatedFat
    case transFat
    case monounsaturatedFat
    case polyunsaturatedFat
    case omega3Fat
    case omega6Fat
    case omega9Fat
    case salt
    case sodium
    case cholesterol
    case solubleFiber
    case insolubleFiber
    case casein
    case serumProteins
    case alcohol
    case defaultServing
    case servingDescription
    case nutriscore
    case categoryTags
    case produceKind
}

extension FoodItem {
    var normalizedBarcode: String? {
        BarcodeIdentity.normalized(barcode)
    }

    func fieldOrigin(for field: FoodField) -> FoodFieldOrigin {
        decodedFieldOrigins()[field] ?? inferredLegacyOrigin(for: field)
    }

    func setFieldOrigin(_ origin: FoodFieldOrigin, for field: FoodField) {
        var origins = decodedFieldOrigins()
        origins[field] = origin
        storeFieldOrigins(origins)
    }

    func configureProviderMaterialization(from result: FoodSearchResult) {
        let product = result.product
        barcode = BarcodeIdentity.normalized(product.code)
            ?? product.code?.trimmingCharacters(in: .whitespacesAndNewlines)
        providerProductIdentityRaw = BarcodeIdentity.normalized(product.code)

        var origins: [FoodField: FoodFieldOrigin] = [:]
        for field in FoodField.allCases {
            origins[field] = product.hasValue(for: field) ? .provider : .missing
        }
        storeFieldOrigins(origins)
    }

    func initializeMissingRecoveryOrigins() {
        storeFieldOrigins(
            Dictionary(
                uniqueKeysWithValues: FoodField.allCases.map { ($0, .missing) }
            )
        )
    }

    private func decodedFieldOrigins() -> [FoodField: FoodFieldOrigin] {
        guard let raw = fieldOriginsRaw,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }

        return decoded.reduce(into: [FoodField: FoodFieldOrigin]()) { result, entry in
            guard let field = FoodField(rawValue: entry.key),
                  let origin = FoodFieldOrigin(rawValue: entry.value) else {
                return
            }
            result[field] = origin
        }
    }

    private func storeFieldOrigins(_ origins: [FoodField: FoodFieldOrigin]) {
        let rawOrigins = origins.reduce(into: [String: String]()) { result, entry in
            result[entry.key.rawValue] = entry.value.rawValue
        }
        guard let data = try? JSONEncoder().encode(rawOrigins) else { return }
        fieldOriginsRaw = String(data: data, encoding: .utf8)
    }

    private func inferredLegacyOrigin(for field: FoodField) -> FoodFieldOrigin {
        guard hasStoredValue(for: field) else { return .missing }

        // A legacy personal food cannot distinguish an entered zero from a
        // provider placeholder. Preserving it as user data is the only
        // migration-safe choice that cannot destroy a correction.
        if isCustom {
            return .user
        }

        switch provenance.source {
        case .calorynCatalog, .openFoodFactsCommunity:
            return .provider
        case .userEntered, .mixed, .unknown:
            return .user
        }
    }

    private func hasStoredValue(for field: FoodField) -> Bool {
        switch field {
        case .name:
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .brand:
            brand?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .calories, .protein, .carbohydrates, .fat, .fiber:
            true
        case .sugars: sugarsPer100g != nil
        case .addedSugars: addedSugarsPer100g != nil
        case .sucrose: sucrosePer100g != nil
        case .glucose: glucosePer100g != nil
        case .fructose: fructosePer100g != nil
        case .lactose: lactosePer100g != nil
        case .maltose: maltosePer100g != nil
        case .maltodextrins: maltodextrinsPer100g != nil
        case .starch: starchPer100g != nil
        case .polyols: polyolsPer100g != nil
        case .saturatedFat: saturatedFatPer100g != nil
        case .transFat: transFatPer100g != nil
        case .monounsaturatedFat: monounsaturatedFatPer100g != nil
        case .polyunsaturatedFat: polyunsaturatedFatPer100g != nil
        case .omega3Fat: omega3FatPer100g != nil
        case .omega6Fat: omega6FatPer100g != nil
        case .omega9Fat: omega9FatPer100g != nil
        case .salt: saltPer100g != nil
        case .sodium: sodiumPer100g != nil
        case .cholesterol: cholesterolPer100g != nil
        case .solubleFiber: solubleFiberPer100g != nil
        case .insolubleFiber: insolubleFiberPer100g != nil
        case .casein: caseinPer100g != nil
        case .serumProteins: serumProteinsPer100g != nil
        case .alcohol: alcoholPer100g != nil
        case .defaultServing: defaultServingG != nil
        case .servingDescription:
            servingDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .nutriscore: nutriscoreGrade != nil
        case .categoryTags: !categoryTags.isEmpty
        case .produceKind: produceKind != .unclassified
        }
    }
}

private extension OpenFoodFactsProduct {
    func hasValue(for field: FoodField) -> Bool {
        switch field {
        case .name:
            productName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .brand:
            brands?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .calories: nutriments?.energyKcal100g != nil
        case .protein: nutriments?.proteins100g != nil
        case .carbohydrates: nutriments?.carbohydrates100g != nil
        case .fat: nutriments?.fat100g != nil
        case .fiber: nutriments?.fiber100g != nil
        case .sugars: nutriments?.sugars100g != nil
        case .addedSugars: nutriments?.addedSugars100g != nil
        case .sucrose: nutriments?.sucrose100g != nil
        case .glucose: nutriments?.glucose100g != nil
        case .fructose: nutriments?.fructose100g != nil
        case .lactose: nutriments?.lactose100g != nil
        case .maltose: nutriments?.maltose100g != nil
        case .maltodextrins: nutriments?.maltodextrins100g != nil
        case .starch: nutriments?.starch100g != nil
        case .polyols: nutriments?.polyols100g != nil
        case .saturatedFat: nutriments?.saturatedFat100g != nil
        case .transFat: nutriments?.transFat100g != nil
        case .monounsaturatedFat: nutriments?.monounsaturatedFat100g != nil
        case .polyunsaturatedFat: nutriments?.polyunsaturatedFat100g != nil
        case .omega3Fat: nutriments?.omega3Fat100g != nil
        case .omega6Fat: nutriments?.omega6Fat100g != nil
        case .omega9Fat: nutriments?.omega9Fat100g != nil
        case .salt: nutriments?.salt100g != nil
        case .sodium: nutriments?.sodium100g != nil
        case .cholesterol: nutriments?.cholesterol100g != nil
        case .solubleFiber: nutriments?.solubleFiber100g != nil
        case .insolubleFiber: nutriments?.insolubleFiber100g != nil
        case .casein: nutriments?.casein100g != nil
        case .serumProteins: nutriments?.serumProteins100g != nil
        case .alcohol: nutriments?.alcohol100g != nil
        case .defaultServing: effectiveServingInfo.defaultServingG != nil
        case .servingDescription: effectiveServingInfo.servingDescription != nil
        case .nutriscore:
            nutritionGrades.map { ["a", "b", "c", "d", "e"].contains($0.lowercased()) } == true
        case .categoryTags:
            categoryTags?.isEmpty == false
        case .produceKind:
            categoryTags?.isEmpty == false
        }
    }
}

struct BarcodeReconciliationChanges: Equatable, Sendable {
    var filledMissingFields = false
    var refreshedProviderFields = false

    static let none = BarcodeReconciliationChanges()
}

struct FoodPersonalEdit: Equatable, Sendable {
    let name: String
    let brand: String?
    let caloriesPer100g: Double
    let proteinPer100g: Double?
    let carbohydratesPer100g: Double?
    let fatPer100g: Double?
    let fiberPer100g: Double?
    let sugarsPer100g: Double?
    let addedSugarsPer100g: Double?
    let saturatedFatPer100g: Double?
    let sodiumPer100g: Double?
    let cholesterolPer100g: Double?
    let alcoholPer100g: Double?
    let defaultServingG: Double?
    let produceKind: ProduceKind
    let userEditedFields: Set<FoodField>?

    init(
        name: String,
        brand: String?,
        caloriesPer100g: Double,
        proteinPer100g: Double?,
        carbohydratesPer100g: Double?,
        fatPer100g: Double?,
        fiberPer100g: Double?,
        sugarsPer100g: Double? = nil,
        addedSugarsPer100g: Double? = nil,
        saturatedFatPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        cholesterolPer100g: Double? = nil,
        alcoholPer100g: Double? = nil,
        defaultServingG: Double?,
        produceKind: ProduceKind,
        userEditedFields: Set<FoodField>? = nil
    ) {
        self.name = name
        self.brand = brand
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbohydratesPer100g = carbohydratesPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarsPer100g = sugarsPer100g
        self.addedSugarsPer100g = addedSugarsPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.sodiumPer100g = sodiumPer100g
        self.cholesterolPer100g = cholesterolPer100g
        self.alcoholPer100g = alcoholPer100g
        self.defaultServingG = defaultServingG
        self.produceKind = produceKind
        self.userEditedFields = userEditedFields
    }
}

enum BarcodeRecoveryResolution {
    case remote(FoodSearchResult)
    case local(FoodItem, BarcodeReconciliationChanges)
    case invalidProviderData
}

enum BarcodeLookupRecoveryOutcome {
    case remote(FoodSearchResult)
    case local(FoodItem, BarcodeReconciliationChanges)
    case failure(FoodLookupError)
}

struct FoodPersonalMaterialization {
    let food: FoodItem
    let isNew: Bool
}

@MainActor
enum BarcodeLookupRecoveryCoordinator {
    static func resolve(
        barcode: String,
        localFoods: [FoodItem],
        providerLookup: (String) async throws -> FoodSearchResult
    ) async -> BarcodeLookupRecoveryOutcome {
        guard let normalizedBarcode = BarcodeIdentity.normalized(barcode) else {
            return .failure(.invalidRequest)
        }

        do {
            let providerResult = try await providerLookup(normalizedBarcode)
            switch BarcodeRecoveryService.reconcile(
                providerResult: providerResult,
                scannedBarcode: normalizedBarcode,
                localFoods: localFoods
            ) {
            case .remote(let result):
                return .remote(result)
            case .local(let food, let changes):
                BarcodeRecoveryAnalytics.record(
                    path: .providerReconciliation,
                    result: .completed,
                    changes: changes
                )
                return .local(food, changes)
            case .invalidProviderData:
                if let fallback = BarcodeRecoveryService.localFallback(
                    for: normalizedBarcode,
                    localFoods: localFoods
                ) {
                    BarcodeRecoveryAnalytics.record(path: .localFallback, result: .completed)
                    return .local(fallback, .none)
                }
                return .failure(.invalidData)
            }
        } catch let error as FoodLookupError {
            guard error != .cancelled, error != .invalidRequest,
                  let fallback = BarcodeRecoveryService.localFallback(
                    for: normalizedBarcode,
                    localFoods: localFoods
                  ) else {
                return .failure(error)
            }
            BarcodeRecoveryAnalytics.record(path: .localFallback, result: .completed)
            return .local(fallback, .none)
        } catch {
            if let fallback = BarcodeRecoveryService.localFallback(
                for: normalizedBarcode,
                localFoods: localFoods
            ) {
                BarcodeRecoveryAnalytics.record(path: .localFallback, result: .completed)
                return .local(fallback, .none)
            }
            return .failure(.unavailable)
        }
    }
}

@MainActor
enum BarcodeRecoveryService {
    static func materializePersonalFood(
        barcode: String,
        edit: FoodPersonalEdit,
        localFoods: [FoodItem]
    ) -> FoodPersonalMaterialization {
        guard let normalizedBarcode = BarcodeIdentity.normalized(barcode) else {
            preconditionFailure("Personal barcode recovery requires a normalized barcode")
        }

        if let existing = preferredLocalFood(for: normalizedBarcode, in: localFoods) {
            existing.barcode = normalizedBarcode
            applyPersonalEdit(edit, to: existing)
            return FoodPersonalMaterialization(food: existing, isNew: false)
        }

        let food = FoodItem(
            name: edit.name,
            brand: edit.brand,
            barcode: normalizedBarcode,
            caloriesPer100g: edit.caloriesPer100g,
            proteinPer100g: edit.proteinPer100g ?? 0,
            carbsPer100g: edit.carbohydratesPer100g ?? 0,
            fatPer100g: edit.fatPer100g ?? 0,
            fiberPer100g: edit.fiberPer100g ?? 0,
            sugarsPer100g: edit.sugarsPer100g,
            addedSugarsPer100g: edit.addedSugarsPer100g,
            saturatedFatPer100g: edit.saturatedFatPer100g,
            sodiumPer100g: edit.sodiumPer100g,
            cholesterolPer100g: edit.cholesterolPer100g,
            alcoholPer100g: edit.alcoholPer100g,
            defaultServingG: edit.defaultServingG,
            produceKind: edit.produceKind,
            isCustom: true,
            provenance: .manuallyEntered(completeness: .partial)
        )
        food.initializeMissingRecoveryOrigins()
        applyPersonalEdit(edit, to: food)
        return FoodPersonalMaterialization(food: food, isNew: true)
    }

    static func applyPersonalEdit(_ edit: FoodPersonalEdit, to food: FoodItem) {
        let providerProvenance = food.provenance

        applyRequired(
            edit.name,
            to: &food.name,
            field: .name,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.brand,
            to: &food.brand,
            field: .brand,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyRequired(
            edit.caloriesPer100g,
            to: &food.caloriesPer100g,
            field: .calories,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptionalCore(
            edit.proteinPer100g,
            to: &food.proteinPer100g,
            field: .protein,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptionalCore(
            edit.carbohydratesPer100g,
            to: &food.carbsPer100g,
            field: .carbohydrates,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptionalCore(
            edit.fatPer100g,
            to: &food.fatPer100g,
            field: .fat,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptionalCore(
            edit.fiberPer100g,
            to: &food.fiberPer100g,
            field: .fiber,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.sugarsPer100g,
            to: &food.sugarsPer100g,
            field: .sugars,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.addedSugarsPer100g,
            to: &food.addedSugarsPer100g,
            field: .addedSugars,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.saturatedFatPer100g,
            to: &food.saturatedFatPer100g,
            field: .saturatedFat,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.sodiumPer100g,
            to: &food.sodiumPer100g,
            field: .sodium,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.cholesterolPer100g,
            to: &food.cholesterolPer100g,
            field: .cholesterol,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.alcoholPer100g,
            to: &food.alcoholPer100g,
            field: .alcohol,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )
        applyOptional(
            edit.defaultServingG,
            to: &food.defaultServingG,
            field: .defaultServing,
            on: food,
            explicitlyEditedFields: edit.userEditedFields
        )

        let produceWasExplicitlyEdited = edit.userEditedFields?.contains(.produceKind)
            ?? (food.produceKind != edit.produceKind)
        if produceWasExplicitlyEdited {
            food.produceKind = edit.produceKind
            food.setFieldOrigin(.user, for: .produceKind)
            food.categoryTags = []
            food.setFieldOrigin(.missing, for: .categoryTags)
        }
        if food.fieldOrigin(for: .defaultServing) == .user {
            food.servingDescription = nil
            food.setFieldOrigin(.missing, for: .servingDescription)
        }

        food.isCustom = true
        food.refreshOverlayProvenance(from: providerProvenance)
    }

    static func reconcile(
        providerResult: FoodSearchResult,
        scannedBarcode: String,
        localFoods: [FoodItem]
    ) -> BarcodeRecoveryResolution {
        guard let scannedIdentity = BarcodeIdentity.normalized(scannedBarcode),
              let providerIdentity = BarcodeIdentity.normalized(providerResult.product.code),
              scannedIdentity == providerIdentity else {
            if let local = preferredLocalFood(for: scannedBarcode, in: localFoods) {
                return .local(local, .none)
            }
            return .invalidProviderData
        }

        guard let local = preferredLocalFood(for: scannedIdentity, in: localFoods) else {
            return .remote(providerResult)
        }

        if let existingIdentity = BarcodeIdentity.normalized(local.providerProductIdentityRaw) {
            guard existingIdentity == providerIdentity else {
                return .local(local, .none)
            }
        } else if local.isCustom {
            // A migrated personal version without stable provider identity is
            // intentionally preserved rather than attached by barcode alone.
            return .local(local, .none)
        }

        let incoming = FoodSearchService().createFoodItem(from: providerResult)
        var changes = BarcodeReconciliationChanges()

        for field in FoodField.allCases
        where incoming.fieldOrigin(for: field) == .provider {
            switch local.fieldOrigin(for: field) {
            case .user:
                continue
            case .missing:
                _ = local.copyField(field, from: incoming)
                local.setFieldOrigin(.provider, for: field)
                changes.filledMissingFields = true
            case .provider:
                if local.copyField(field, from: incoming) {
                    changes.refreshedProviderFields = true
                }
            }
        }

        local.barcode = scannedIdentity
        local.providerProductIdentityRaw = providerIdentity
        local.refreshOverlayProvenance(from: providerResult.provenance)
        return .local(local, changes)
    }

    static func localFallback(
        for barcode: String,
        localFoods: [FoodItem]
    ) -> FoodItem? {
        preferredLocalFood(for: barcode, in: localFoods)
    }

    static func preferredLocalFood(
        for barcode: String,
        in foods: [FoodItem]
    ) -> FoodItem? {
        guard let normalized = BarcodeIdentity.normalized(barcode) else { return nil }
        return foods
            .filter { $0.normalizedBarcode == normalized }
            .sorted {
                if $0.isCustom != $1.isCustom {
                    return $0.isCustom
                }
                return $0.lastUsed > $1.lastUsed
            }
            .first
    }

    private static func applyRequired<Value: Equatable>(
        _ value: Value,
        to storedValue: inout Value,
        field: FoodField,
        on food: FoodItem,
        explicitlyEditedFields: Set<FoodField>?
    ) {
        if let explicitlyEditedFields {
            guard explicitlyEditedFields.contains(field) else { return }
            storedValue = value
            food.setFieldOrigin(.user, for: field)
        } else if storedValue != value || food.fieldOrigin(for: field) == .missing {
            storedValue = value
            food.setFieldOrigin(.user, for: field)
        }
    }

    private static func applyOptional<Value: Equatable>(
        _ value: Value?,
        to storedValue: inout Value?,
        field: FoodField,
        on food: FoodItem,
        explicitlyEditedFields: Set<FoodField>?
    ) {
        if let explicitlyEditedFields,
           !explicitlyEditedFields.contains(field) {
            return
        }
        guard let value else {
            storedValue = nil
            food.setFieldOrigin(.missing, for: field)
            return
        }
        if explicitlyEditedFields != nil
            || storedValue != value
            || food.fieldOrigin(for: field) == .missing {
            storedValue = value
            food.setFieldOrigin(.user, for: field)
        }
    }

    private static func applyOptionalCore(
        _ value: Double?,
        to storedValue: inout Double,
        field: FoodField,
        on food: FoodItem,
        explicitlyEditedFields: Set<FoodField>?
    ) {
        if let explicitlyEditedFields,
           !explicitlyEditedFields.contains(field) {
            return
        }
        guard let value else {
            storedValue = 0
            food.setFieldOrigin(.missing, for: field)
            return
        }
        if explicitlyEditedFields != nil
            || storedValue != value
            || food.fieldOrigin(for: field) == .missing {
            storedValue = value
            food.setFieldOrigin(.user, for: field)
        }
    }
}

private extension FoodItem {
    func refreshOverlayProvenance(from providerProvenance: FoodProvenance) {
        let origins = FoodField.allCases.map(fieldOrigin(for:))
        let hasUserFields = origins.contains(.user)
        let hasProviderFields = origins.contains(.provider)
        let source: FoodDataSource
        if hasUserFields && hasProviderFields {
            source = .mixed
        } else if hasUserFields {
            source = .userEntered
        } else {
            source = providerProvenance.source
        }

        let completeness: NutritionCompleteness = [
            FoodField.protein,
            .carbohydrates,
            .fat,
        ].allSatisfy { fieldOrigin(for: $0) != .missing } ? .complete : .partial

        provenance = FoodProvenance(
            provider: hasProviderFields ? providerProvenance.provider : nil,
            source: source,
            completeness: completeness,
            recoveredByFallback: providerProvenance.recoveredByFallback
        )
    }

    @discardableResult
    func copyField(_ field: FoodField, from incoming: FoodItem) -> Bool {
        switch field {
        case .name: replace(&name, with: incoming.name)
        case .brand: replace(&brand, with: incoming.brand)
        case .calories: replace(&caloriesPer100g, with: incoming.caloriesPer100g)
        case .protein: replace(&proteinPer100g, with: incoming.proteinPer100g)
        case .carbohydrates: replace(&carbsPer100g, with: incoming.carbsPer100g)
        case .fat: replace(&fatPer100g, with: incoming.fatPer100g)
        case .fiber: replace(&fiberPer100g, with: incoming.fiberPer100g)
        case .sugars: replace(&sugarsPer100g, with: incoming.sugarsPer100g)
        case .addedSugars: replace(&addedSugarsPer100g, with: incoming.addedSugarsPer100g)
        case .sucrose: replace(&sucrosePer100g, with: incoming.sucrosePer100g)
        case .glucose: replace(&glucosePer100g, with: incoming.glucosePer100g)
        case .fructose: replace(&fructosePer100g, with: incoming.fructosePer100g)
        case .lactose: replace(&lactosePer100g, with: incoming.lactosePer100g)
        case .maltose: replace(&maltosePer100g, with: incoming.maltosePer100g)
        case .maltodextrins: replace(&maltodextrinsPer100g, with: incoming.maltodextrinsPer100g)
        case .starch: replace(&starchPer100g, with: incoming.starchPer100g)
        case .polyols: replace(&polyolsPer100g, with: incoming.polyolsPer100g)
        case .saturatedFat: replace(&saturatedFatPer100g, with: incoming.saturatedFatPer100g)
        case .transFat: replace(&transFatPer100g, with: incoming.transFatPer100g)
        case .monounsaturatedFat:
            replace(&monounsaturatedFatPer100g, with: incoming.monounsaturatedFatPer100g)
        case .polyunsaturatedFat:
            replace(&polyunsaturatedFatPer100g, with: incoming.polyunsaturatedFatPer100g)
        case .omega3Fat: replace(&omega3FatPer100g, with: incoming.omega3FatPer100g)
        case .omega6Fat: replace(&omega6FatPer100g, with: incoming.omega6FatPer100g)
        case .omega9Fat: replace(&omega9FatPer100g, with: incoming.omega9FatPer100g)
        case .salt: replace(&saltPer100g, with: incoming.saltPer100g)
        case .sodium: replace(&sodiumPer100g, with: incoming.sodiumPer100g)
        case .cholesterol: replace(&cholesterolPer100g, with: incoming.cholesterolPer100g)
        case .solubleFiber: replace(&solubleFiberPer100g, with: incoming.solubleFiberPer100g)
        case .insolubleFiber: replace(&insolubleFiberPer100g, with: incoming.insolubleFiberPer100g)
        case .casein: replace(&caseinPer100g, with: incoming.caseinPer100g)
        case .serumProteins: replace(&serumProteinsPer100g, with: incoming.serumProteinsPer100g)
        case .alcohol: replace(&alcoholPer100g, with: incoming.alcoholPer100g)
        case .defaultServing: replace(&defaultServingG, with: incoming.defaultServingG)
        case .servingDescription: replace(&servingDescription, with: incoming.servingDescription)
        case .nutriscore: replace(&nutriscoreGrade, with: incoming.nutriscoreGrade)
        case .categoryTags: replace(&categoryTagsRaw, with: incoming.categoryTagsRaw)
        case .produceKind: replace(&produceKindRaw, with: incoming.produceKindRaw)
        }
    }

    func replace<Value: Equatable>(_ current: inout Value, with incoming: Value) -> Bool {
        guard current != incoming else { return false }
        current = incoming
        return true
    }
}
