import Foundation

nonisolated enum LogLinkNutrient: String, CaseIterable, Sendable {
    case protein
    case carbs
    case fat
    case fiber
    case sugars
    case addedSugars = "added_sugars"
    case sucrose
    case glucose
    case fructose
    case lactose
    case maltose
    case maltodextrins
    case starch
    case polyols
    case saturatedFat = "saturated_fat"
    case transFat = "trans_fat"
    case monounsaturatedFat = "monounsaturated_fat"
    case polyunsaturatedFat = "polyunsaturated_fat"
    case omega3Fat = "omega_3_fat"
    case omega6Fat = "omega_6_fat"
    case omega9Fat = "omega_9_fat"
    case salt
    case sodium = "sodium_mg"
    case cholesterol = "cholesterol_mg"
    case solubleFiber = "soluble_fiber"
    case insolubleFiber = "insoluble_fiber"
    case casein
    case serumProteins = "serum_proteins"
    case alcohol

    enum Unit: Sendable {
        case grams
        case milligrams
    }

    static let core: [LogLinkNutrient] = [.protein, .carbs, .fat]

    var isCore: Bool {
        Self.core.contains(self)
    }

    var unit: Unit {
        switch self {
        case .sodium, .cholesterol: .milligrams
        default: .grams
        }
    }

    var label: String {
        switch self {
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fat"
        case .fiber: "Fiber"
        case .sugars: "Sugars"
        case .addedSugars: "Added sugars"
        case .sucrose: "Sucrose"
        case .glucose: "Glucose"
        case .fructose: "Fructose"
        case .lactose: "Lactose"
        case .maltose: "Maltose"
        case .maltodextrins: "Maltodextrins"
        case .starch: "Starch"
        case .polyols: "Polyols"
        case .saturatedFat: "Saturated fat"
        case .transFat: "Trans fat"
        case .monounsaturatedFat: "Monounsaturated fat"
        case .polyunsaturatedFat: "Polyunsaturated fat"
        case .omega3Fat: "Omega-3 fat"
        case .omega6Fat: "Omega-6 fat"
        case .omega9Fat: "Omega-9 fat"
        case .salt: "Salt"
        case .sodium: "Sodium"
        case .cholesterol: "Cholesterol"
        case .solubleFiber: "Soluble fiber"
        case .insolubleFiber: "Insoluble fiber"
        case .casein: "Casein"
        case .serumProteins: "Serum proteins"
        case .alcohol: "Alcohol"
        }
    }

    func grams(fromLinkValue value: Double) -> Double {
        switch unit {
        case .grams: value
        case .milligrams: value / 1000
        }
    }

    func linkValue(fromGrams grams: Double) -> Double {
        switch unit {
        case .grams: grams
        case .milligrams: grams * 1000
        }
    }

    func store(_ grams: Double, in nutrition: inout NutritionValues) {
        switch self {
        case .protein: nutrition.proteinG = grams
        case .carbs: nutrition.carbsG = grams
        case .fat: nutrition.fatG = grams
        case .fiber: nutrition.fiberG = grams
        case .sugars: nutrition.sugarsG = grams
        case .addedSugars: nutrition.addedSugarsG = grams
        case .sucrose: nutrition.sucroseG = grams
        case .glucose: nutrition.glucoseG = grams
        case .fructose: nutrition.fructoseG = grams
        case .lactose: nutrition.lactoseG = grams
        case .maltose: nutrition.maltoseG = grams
        case .maltodextrins: nutrition.maltodextrinsG = grams
        case .starch: nutrition.starchG = grams
        case .polyols: nutrition.polyolsG = grams
        case .saturatedFat: nutrition.saturatedFatG = grams
        case .transFat: nutrition.transFatG = grams
        case .monounsaturatedFat: nutrition.monounsaturatedFatG = grams
        case .polyunsaturatedFat: nutrition.polyunsaturatedFatG = grams
        case .omega3Fat: nutrition.omega3FatG = grams
        case .omega6Fat: nutrition.omega6FatG = grams
        case .omega9Fat: nutrition.omega9FatG = grams
        case .salt: nutrition.saltG = grams
        case .sodium: nutrition.sodiumG = grams
        case .cholesterol: nutrition.cholesterolG = grams
        case .solubleFiber: nutrition.solubleFiberG = grams
        case .insolubleFiber: nutrition.insolubleFiberG = grams
        case .casein: nutrition.caseinG = grams
        case .serumProteins: nutrition.serumProteinsG = grams
        case .alcohol: nutrition.alcoholG = grams
        }
    }

    static func nutrition(calories: Double, nutrients: [LogLinkNutrient: Double]) -> NutritionValues {
        var nutrition = NutritionValues(calories: calories)
        for (nutrient, grams) in nutrients {
            nutrient.store(grams, in: &nutrition)
        }
        return nutrition
    }
}
