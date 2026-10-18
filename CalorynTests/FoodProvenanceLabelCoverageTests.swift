import Foundation
import Testing
@testable import Caloryn

@MainActor
struct FoodProvenanceLabelCoverageTests {
    @Test("Each provider names itself for display")
    func providerDisplayNames() {
        #expect(FoodSearchProvider.calorynAPI.displayName == "Caloryn")
        #expect(FoodSearchProvider.openFoodFacts.displayName == "Open Food Facts")
    }

    @Test("Provider raw values stay readable from saved foods")
    func providerRawValues() {
        #expect(FoodSearchProvider(rawValue: "caloryn_api") == .calorynAPI)
        #expect(FoodSearchProvider(rawValue: "open_food_facts") == .openFoodFacts)
        #expect(FoodSearchProvider.allCases.map(\.rawValue) == ["caloryn_api", "open_food_facts"])
    }

    @Test(
        "Each data source has a short badge",
        arguments: [
            (FoodDataSource.calorynCatalog, "Caloryn data"),
            (.openFoodFactsCommunity, "Community data"),
            (.userEntered, "Your data"),
            (.mixed, "Mixed sources"),
            (.unknown, "Source unknown"),
        ] as [(FoodDataSource, String)]
    )
    func dataSourceLabels(source: FoodDataSource, short: String) {
        #expect(source.shortLabel == short)
    }

    @Test("Data source raw values stay readable from saved foods")
    func dataSourceRawValues() {
        #expect(FoodDataSource(rawValue: "caloryn_catalog") == .calorynCatalog)
        #expect(FoodDataSource(rawValue: "open_food_facts_community") == .openFoodFactsCommunity)
        #expect(FoodDataSource(rawValue: "user_entered") == .userEntered)
        #expect(FoodDataSource(rawValue: "mixed") == .mixed)
        #expect(FoodDataSource(rawValue: "unknown") == .unknown)
    }

    @Test("Only incomplete or unknown nutrition carries a warning label")
    func completenessWarningLabels() {
        #expect(NutritionCompleteness.complete.warningLabel == nil)
        #expect(NutritionCompleteness.partial.warningLabel == "Some nutrition missing")
        #expect(NutritionCompleteness.unknown.warningLabel == "Completeness unknown")
    }

    @Test(
        "Core nutrition is complete only when protein, carbs and fat are all supplied",
        arguments: [
            (10, 20, 5, .complete),
            (0, 0, 0, .complete),
            (nil, 20, 5, .partial),
            (10, nil, 5, .partial),
            (10, 20, nil, .partial),
            (nil, nil, nil, .partial),
        ] as [(Double?, Double?, Double?, NutritionCompleteness)]
    )
    func assessingCoreNutrition(
        protein: Double?,
        carbohydrates: Double?,
        fat: Double?,
        expected: NutritionCompleteness
    ) {
        #expect(
            NutritionCompleteness.assessingCoreNutrition(
                protein: protein,
                carbohydrates: carbohydrates,
                fat: fat
            ) == expected
        )
    }

    @Test("A manual entry is attributed to the user with no provider or fallback")
    func manuallyEntered() {
        let provenance = FoodProvenance.manuallyEntered(completeness: .partial)

        #expect(provenance.provider == nil)
        #expect(provenance.source == .userEntered)
        #expect(provenance.completeness == .partial)
        #expect(provenance.recoveredByFallback == false)
        #expect(provenance.warrantsNutritionNotice)
    }

    @Test("The shared presets describe user-entered and legacy foods")
    func presets() {
        #expect(FoodProvenance.userEntered == .manuallyEntered(completeness: .complete))
        #expect(FoodProvenance.userEntered.warrantsNutritionNotice == false)
        #expect(FoodProvenance.unknown.provider == nil)
        #expect(FoodProvenance.unknown.source == .unknown)
        #expect(FoodProvenance.unknown.completeness == .unknown)
        #expect(FoodProvenance.unknown.warrantsNutritionNotice == false)
    }

    @Test("A food's provenance round-trips through its persisted raw fields")
    func foodRoundTrip() {
        let provenance = FoodProvenance(
            provider: .calorynAPI,
            source: .calorynCatalog,
            completeness: .partial,
            recoveredByFallback: true
        )
        let food = makeTestFoodItem(provenance: provenance)

        #expect(food.lookupProviderRaw == "caloryn_api")
        #expect(food.dataSourceRaw == "caloryn_catalog")
        #expect(food.nutritionCompletenessRaw == "partial")
        #expect(food.recoveredByFallbackRaw == true)
        #expect(food.provenance == provenance)
    }

    @Test("Unrecognised persisted provenance reads as unknown rather than failing")
    func unrecognisedRawValues() {
        let food = makeTestFoodItem()
        food.lookupProviderRaw = "some_future_provider"
        food.dataSourceRaw = "some_future_source"
        food.nutritionCompletenessRaw = "some_future_level"
        food.recoveredByFallbackRaw = nil

        #expect(food.provenance == .unknown)
    }
}
