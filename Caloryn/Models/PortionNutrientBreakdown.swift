import Foundation

/// The flat nutrient list the portion picker previews under its wheels.
///
/// Same domain as `NutrientDetailGroup`, different presentation: the portion
/// picker shows one flat list — the four core macros always, then every
/// optional nutrient the food records — rather than the grouped cards of the
/// Nutrition Details sheet. The rows reuse `DetailNutrient`, so the grams and
/// milligram formatting rules exist exactly once.
///
/// As with the grouped view, which optional lines exist is a property of the
/// data, not the layout: a nutrient with nothing recorded is absent rather
/// than shown as zero, because a zero would claim the food genuinely contains
/// none of it. The core macros are the exception — they are always recorded,
/// and a zero there is a real zero.
///
/// One deliberate wording difference from the grouped view: the flat list
/// labels `saltG` "Salt", while the Salt card calls its line "Salt equivalent"
/// under a card already titled "Salt". The parity test pins both so neither
/// drifts unnoticed.
struct PortionNutrientBreakdown {
    /// The rows the picker shows for this nutrition, in display order.
    let items: [DetailNutrient]

    init(nutrition: NutritionValues) {
        let core = Self.coreDefinitions.map { definition in
            DetailNutrient(
                id: definition.id,
                label: definition.label,
                value: nutrition[keyPath: definition.keyPath]
            )
        }
        let optional = Self.optionalDefinitions.compactMap { definition -> DetailNutrient? in
            guard let value = nutrition[keyPath: definition.keyPath] else { return nil }
            return DetailNutrient(
                id: definition.id,
                label: definition.label,
                value: value,
                unit: definition.unit
            )
        }
        items = core + optional
    }

    // MARK: - Definitions

    private struct CoreDefinition {
        let id: String
        let label: String
        let keyPath: KeyPath<NutritionValues, Double>
    }

    private struct OptionalDefinition {
        let id: String
        let label: String
        let keyPath: KeyPath<NutritionValues, Double?>
        var unit: DetailNutrient.Unit = .grams
    }

    private static let coreDefinitions: [CoreDefinition] = [
        CoreDefinition(id: "protein", label: "Protein", keyPath: \.proteinG),
        CoreDefinition(id: "carbs", label: "Carbs", keyPath: \.carbsG),
        CoreDefinition(id: "fat", label: "Fat", keyPath: \.fatG),
        CoreDefinition(id: "fiber", label: "Fiber", keyPath: \.fiberG)
    ]

    private static let optionalDefinitions: [OptionalDefinition] = [
        OptionalDefinition(id: "sugars", label: "Sugars", keyPath: \.sugarsG),
        OptionalDefinition(id: "added-sugars", label: "Added sugars", keyPath: \.addedSugarsG),
        OptionalDefinition(id: "sucrose", label: "Sucrose", keyPath: \.sucroseG),
        OptionalDefinition(id: "glucose", label: "Glucose", keyPath: \.glucoseG),
        OptionalDefinition(id: "fructose", label: "Fructose", keyPath: \.fructoseG),
        OptionalDefinition(id: "lactose", label: "Lactose", keyPath: \.lactoseG),
        OptionalDefinition(id: "maltose", label: "Maltose", keyPath: \.maltoseG),
        OptionalDefinition(id: "maltodextrins", label: "Maltodextrins", keyPath: \.maltodextrinsG),
        OptionalDefinition(id: "starch", label: "Starch", keyPath: \.starchG),
        OptionalDefinition(id: "polyols", label: "Polyols", keyPath: \.polyolsG),
        OptionalDefinition(id: "saturated-fat", label: "Saturated fat", keyPath: \.saturatedFatG),
        OptionalDefinition(id: "trans-fat", label: "Trans fat", keyPath: \.transFatG),
        OptionalDefinition(id: "monounsaturated-fat", label: "Monounsaturated", keyPath: \.monounsaturatedFatG),
        OptionalDefinition(id: "polyunsaturated-fat", label: "Polyunsaturated", keyPath: \.polyunsaturatedFatG),
        OptionalDefinition(id: "omega-3-fat", label: "Omega-3 fat", keyPath: \.omega3FatG),
        OptionalDefinition(id: "omega-6-fat", label: "Omega-6 fat", keyPath: \.omega6FatG),
        OptionalDefinition(id: "omega-9-fat", label: "Omega-9 fat", keyPath: \.omega9FatG),
        OptionalDefinition(id: "salt", label: "Salt", keyPath: \.saltG),
        OptionalDefinition(id: "sodium", label: "Sodium", keyPath: \.sodiumG, unit: .milligramsFromGrams),
        OptionalDefinition(id: "cholesterol", label: "Cholesterol", keyPath: \.cholesterolG, unit: .milligramsFromGrams),
        OptionalDefinition(id: "soluble-fiber", label: "Soluble fiber", keyPath: \.solubleFiberG),
        OptionalDefinition(id: "insoluble-fiber", label: "Insoluble fiber", keyPath: \.insolubleFiberG),
        OptionalDefinition(id: "casein", label: "Casein", keyPath: \.caseinG),
        OptionalDefinition(id: "serum-proteins", label: "Serum proteins", keyPath: \.serumProteinsG),
        OptionalDefinition(id: "alcohol", label: "Alcohol", keyPath: \.alcoholG)
    ]
}
