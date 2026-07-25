#if DEBUG
import SwiftData
import SwiftUI

enum Issue73ScreenshotScenario: String {
    case unknownRecovery = "unknown-recovery"
    case manualDraft = "manual-draft"
    case incompleteCorrection = "incomplete-correction"
    case silentCompletion = "silent-completion"
    case offlineFallback = "offline-fallback"

    static var current: Issue73ScreenshotScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-issue73Screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Issue73ScreenshotScenario(rawValue: arguments[flagIndex + 1])
    }
}

struct Issue73ScreenshotHost: View {
    @Environment(\.modelContext) private var modelContext

    let scenario: Issue73ScreenshotScenario

    @State private var evidenceFood: FoodItem?
    @State private var hasSeeded = false
    @State private var seedError: String?

    var body: some View {
        Group {
            if let seedError {
                ContentUnavailableView(
                    "Fixture Failed",
                    systemImage: "xmark.octagon",
                    description: Text(seedError)
                )
            } else if !hasSeeded {
                ProgressView("Preparing barcode recovery…")
            } else {
                scenarioContent
            }
        }
        .task { await seedIfNeeded() }
    }

    @ViewBuilder
    private var scenarioContent: some View {
        switch scenario {
        case .unknownRecovery:
            FoodSearchView(
                mealType: .lunch,
                logDate: .now,
                automaticallyFocusSearch: false
            )
        case .manualDraft:
            CustomFoodFormView(prefilledBarcode: Self.barcode)
        case .incompleteCorrection, .silentCompletion, .offlineFallback:
            if let evidenceFood {
                NavigationStack {
                    PortionPickerView(
                        foodItem: evidenceFood,
                        mealType: .lunch,
                        logDate: .now,
                        isNewFood: false
                    )
                }
            }
        }
    }

    private func seedIfNeeded() async {
        guard !hasSeeded else { return }

        switch scenario {
        case .unknownRecovery, .manualDraft:
            hasSeeded = true
        case .incompleteCorrection:
            evidenceFood = makeProviderFood(
                name: "Community Oat Bar",
                energy: 389,
                protein: nil,
                carbohydrates: 62,
                fat: nil,
                recoveredByFallback: true
            )
            persistEvidenceFood()
        case .silentCompletion:
            let saved = makeProviderFood(
                name: "Provider Skyr",
                energy: 62,
                protein: nil,
                carbohydrates: 4,
                fat: nil,
                recoveredByFallback: true
            )
            BarcodeRecoveryService.applyPersonalEdit(
                FoodPersonalEdit(
                    name: "My Skyr",
                    brand: "Nordic Dairy",
                    caloriesPer100g: 62,
                    proteinPer100g: nil,
                    carbohydratesPer100g: 4,
                    fatPer100g: 0,
                    fiberPer100g: nil,
                    defaultServingG: 180,
                    produceKind: .unclassified
                ),
                to: saved
            )
            let refreshed = providerResult(
                name: "Provider Skyr Updated",
                energy: 64,
                protein: 11,
                carbohydrates: 5,
                fat: 2,
                recoveredByFallback: false
            )
            _ = BarcodeRecoveryService.reconcile(
                providerResult: refreshed,
                scannedBarcode: Self.barcode,
                localFoods: [saved]
            )
            evidenceFood = saved
            persistEvidenceFood()
        case .offlineFallback:
            let saved = makeProviderFood(
                name: "Offline Safe Skyr",
                energy: 68,
                protein: 10.5,
                carbohydrates: 5.1,
                fat: 0.3,
                recoveredByFallback: false
            )
            BarcodeRecoveryService.applyPersonalEdit(
                FoodPersonalEdit(
                    name: "My Offline Skyr",
                    brand: "Nordic Dairy",
                    caloriesPer100g: 68,
                    proteinPer100g: 10.5,
                    carbohydratesPer100g: 5.1,
                    fatPer100g: 0.3,
                    fiberPer100g: nil,
                    defaultServingG: 180,
                    produceKind: .unclassified
                ),
                to: saved
            )
            let outcome = await BarcodeLookupRecoveryCoordinator.resolve(
                barcode: Self.barcode,
                localFoods: [saved]
            ) { _ in
                throw FoodLookupError.offline
            }
            guard case .local(let fallback, _) = outcome else {
                seedError = "Offline recovery did not return the saved food."
                hasSeeded = true
                return
            }
            evidenceFood = fallback
            persistEvidenceFood()
        }
    }

    private func persistEvidenceFood() {
        guard let evidenceFood else {
            seedError = "No evidence food was created."
            hasSeeded = true
            return
        }
        modelContext.insert(evidenceFood)
        do {
            try modelContext.save()
        } catch {
            seedError = error.localizedDescription
        }
        hasSeeded = true
    }

    private func makeProviderFood(
        name: String,
        energy: Double,
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?,
        recoveredByFallback: Bool
    ) -> FoodItem {
        FoodSearchService().createFoodItem(
            from: providerResult(
                name: name,
                energy: energy,
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat,
                recoveredByFallback: recoveredByFallback
            )
        )
    }

    private func providerResult(
        name: String,
        energy: Double,
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?,
        recoveredByFallback: Bool
    ) -> FoodSearchResult {
        let product = OpenFoodFactsProduct.fixture(
            code: Self.barcode,
            name: name,
            brand: "Nordic Dairy",
            energy: energy,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat,
            fiber: nil
        )
        return FoodSearchResult(
            product: product,
            provenance: FoodProvenance(
                provider: recoveredByFallback ? .openFoodFacts : .calorynAPI,
                source: recoveredByFallback ? .openFoodFactsCommunity : .calorynCatalog,
                completeness: product.nutritionCompleteness,
                recoveredByFallback: recoveredByFallback
            )
        )
    }

    private static let barcode = "5711953150388"
}
#else
enum Issue73ScreenshotScenario {
    static var current: Issue73ScreenshotScenario? { nil }
}
#endif
