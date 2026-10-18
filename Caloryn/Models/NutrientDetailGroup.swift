import Foundation

struct DetailNutrient: Identifiable, Equatable {
    enum Unit: Equatable {
        case grams
        case milligramsFromGrams
    }

    let id: String
    let label: String
    let value: Double
    let unit: Unit

    init(id: String, label: String, value: Double, unit: Unit = .grams) {
        self.id = id
        self.label = label
        self.value = value
        self.unit = unit
    }

    var spacedFormattedValue: String {
        spacedFormattedValue(locale: .current)
    }

    /// Scaling to milligrams multiplies whatever the product data held by a
    /// thousand, so `Int(_:)` cannot do the rounding: it terminates the process
    /// past `Int.max` rather than throwing, and nothing bounds a nutrient value
    /// on the way in.
    func spacedFormattedValue(locale: Locale) -> String {
        switch unit {
        case .grams:
            value.spacedMacroFormatted(locale: locale)
        case .milligramsFromGrams:
            "\((value * 1000).rounded().truncatedSafely.formatted(.number.locale(locale))) mg"
        }
    }
}

/// Which lines exist is a property of the data, not of the layout: a nutrient
/// with nothing recorded for it is absent rather than shown as zero, because a
/// zero would claim the food genuinely contains none of it. A whole group
/// disappears once every line in it is missing, which is why `populatedGroups`
/// and not the view decides what to draw.
enum NutrientDetailGroup: String, CaseIterable, Identifiable {
    case protein
    case carbs
    case fat
    case salt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein:
            "Protein Details"
        case .carbs:
            "Carb Details"
        case .fat:
            "Fat Details"
        case .salt:
            "Salt"
        }
    }

    var systemImage: String {
        switch self {
        case .protein:
            "dumbbell.fill"
        case .carbs:
            "fork.knife"
        case .fat:
            "drop.fill"
        case .salt:
            "s.circle.fill"
        }
    }

    func items(in nutrition: NutritionValues) -> [DetailNutrient] {
        Self.definitions(for: self).compactMap { definition in
            guard let value = nutrition[keyPath: definition.keyPath] else { return nil }
            return DetailNutrient(
                id: definition.id,
                label: definition.label,
                value: value,
                unit: definition.unit
            )
        }
    }

    static func populatedGroups(in nutrition: NutritionValues) -> [PopulatedNutrientDetailGroup] {
        allCases.compactMap { group in
            let items = group.items(in: nutrition)
            guard !items.isEmpty else { return nil }
            return PopulatedNutrientDetailGroup(group: group, items: items)
        }
    }

    private struct Definition {
        let id: String
        let label: String
        let keyPath: KeyPath<NutritionValues, Double?>
        var unit: DetailNutrient.Unit = .grams
    }

    private static func definitions(for group: NutrientDetailGroup) -> [Definition] {
        switch group {
        case .protein:
            [
                Definition(id: "casein", label: "Casein", keyPath: \.caseinG),
                Definition(id: "serum-proteins", label: "Serum proteins", keyPath: \.serumProteinsG)
            ]
        case .carbs:
            [
                Definition(id: "sucrose", label: "Sucrose", keyPath: \.sucroseG),
                Definition(id: "glucose", label: "Glucose", keyPath: \.glucoseG),
                Definition(id: "fructose", label: "Fructose", keyPath: \.fructoseG),
                Definition(id: "lactose", label: "Lactose", keyPath: \.lactoseG),
                Definition(id: "maltose", label: "Maltose", keyPath: \.maltoseG),
                Definition(id: "maltodextrins", label: "Maltodextrins", keyPath: \.maltodextrinsG),
                Definition(id: "starch", label: "Starch", keyPath: \.starchG),
                Definition(id: "polyols", label: "Polyols", keyPath: \.polyolsG)
            ]
        case .fat:
            [
                Definition(id: "trans-fat", label: "Trans fat", keyPath: \.transFatG),
                Definition(id: "monounsaturated-fat", label: "Monounsaturated", keyPath: \.monounsaturatedFatG),
                Definition(id: "polyunsaturated-fat", label: "Polyunsaturated", keyPath: \.polyunsaturatedFatG),
                Definition(id: "omega-3-fat", label: "Omega-3 fat", keyPath: \.omega3FatG),
                Definition(id: "omega-6-fat", label: "Omega-6 fat", keyPath: \.omega6FatG),
                Definition(id: "omega-9-fat", label: "Omega-9 fat", keyPath: \.omega9FatG)
            ]
        case .salt:
            [
                Definition(id: "salt", label: "Salt", keyPath: \.saltG)
            ]
        }
    }
}

struct PopulatedNutrientDetailGroup: Identifiable, Equatable {
    let group: NutrientDetailGroup
    let items: [DetailNutrient]

    var id: String { group.id }
    var title: String { group.title }
    var systemImage: String { group.systemImage }
}
