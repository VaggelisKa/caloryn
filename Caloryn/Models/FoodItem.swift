import Foundation
import SwiftData

enum ProduceKind: String, Codable, CaseIterable, Hashable, Identifiable {
    case unclassified
    case fruit
    case vegetable

    nonisolated var id: String { rawValue }

    static let manualCases: [ProduceKind] = [.unclassified, .fruit, .vegetable]

    nonisolated var displayName: String {
        switch self {
        case .unclassified:
            "Not counted"
        case .fruit:
            "Fruit"
        case .vegetable:
            "Veg"
        }
    }

    nonisolated var fullDisplayName: String {
        switch self {
        case .unclassified:
            "Not counted"
        case .fruit:
            "Fruit"
        case .vegetable:
            "Vegetable"
        }
    }

    nonisolated var countsTowardVariety: Bool {
        self != .unclassified
    }

    nonisolated static func inferred(fromCategoryTags tags: [String]) -> ProduceKind {
        let normalizedTags = Set(tags.map(normalizedTag(_:)))
        guard !normalizedTags.isEmpty else { return .unclassified }
        guard normalizedTags.isDisjoint(with: excludedProcessedTags) else { return .unclassified }

        let matchesFruit = !normalizedTags.isDisjoint(with: fruitTags)
        let matchesVegetable = !normalizedTags.isDisjoint(with: vegetableTags)

        switch (matchesFruit, matchesVegetable) {
        case (true, false):
            return .fruit
        case (false, true):
            return .vegetable
        default:
            return .unclassified
        }
    }

    nonisolated private static func normalizedTag(_ tag: String) -> String {
        tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    nonisolated private static let excludedProcessedTags: Set<String> = [
        "en:biscuits-and-cakes",
        "en:cakes",
        "en:chips-and-fries",
        "en:crisps",
        "en:desserts",
        "en:french-fries",
        "en:fruit-juices",
        "en:jams",
        "en:juices",
        "en:pies",
        "en:pizzas",
        "en:potato-crisps",
        "en:ready-meals",
        "en:sauces",
        "en:smoothies",
        "en:soups",
        "en:vegetable-juices",
        "en:yogurts"
    ]

    nonisolated private static let fruitTags: Set<String> = [
        "en:apples",
        "en:avocados",
        "en:bananas",
        "en:berries",
        "en:blackberries",
        "en:blueberries",
        "en:citrus-fruits",
        "en:dried-fruits",
        "en:fresh-fruits",
        "en:frozen-fruits",
        "en:fruits",
        "en:grapes",
        "en:kiwifruits",
        "en:lemons",
        "en:limes",
        "en:mangoes",
        "en:melons",
        "en:nectarines",
        "en:oranges",
        "en:peaches",
        "en:pears",
        "en:pineapples",
        "en:plums",
        "en:raspberries",
        "en:strawberries",
        "en:tropical-fruits",
        "en:watermelons"
    ]

    nonisolated private static let vegetableTags: Set<String> = [
        "en:broccoli",
        "en:cabbages",
        "en:carrots",
        "en:cauliflowers",
        "en:cucumbers",
        "en:fresh-vegetables",
        "en:frozen-vegetables",
        "en:garlic",
        "en:leaf-vegetables",
        "en:lettuces",
        "en:mushrooms",
        "en:onions",
        "en:peppers",
        "en:root-vegetables",
        "en:salads",
        "en:spinaches",
        "en:tomatoes",
        "en:vegetables"
    ]
}

@Model
final class FoodItem {
    var id: UUID = UUID()
    var barcode: String?
    var name: String = ""
    var brand: String?

    var caloriesPer100g: Double = 0
    var proteinPer100g: Double = 0
    var carbsPer100g: Double = 0
    var fatPer100g: Double = 0
    var fiberPer100g: Double = 0
    var sugarsPer100g: Double?
    var addedSugarsPer100g: Double?
    var sucrosePer100g: Double?
    var glucosePer100g: Double?
    var fructosePer100g: Double?
    var lactosePer100g: Double?
    var maltosePer100g: Double?
    var maltodextrinsPer100g: Double?
    var starchPer100g: Double?
    var polyolsPer100g: Double?
    var saturatedFatPer100g: Double?
    var transFatPer100g: Double?
    var monounsaturatedFatPer100g: Double?
    var polyunsaturatedFatPer100g: Double?
    var omega3FatPer100g: Double?
    var omega6FatPer100g: Double?
    var omega9FatPer100g: Double?
    var saltPer100g: Double?
    var sodiumPer100g: Double?
    var cholesterolPer100g: Double?
    var solubleFiberPer100g: Double?
    var insolubleFiberPer100g: Double?
    var caseinPer100g: Double?
    var serumProteinsPer100g: Double?
    var alcoholPer100g: Double?

    var nutriscoreGrade: String?
    var categoryTagsRaw: String?
    var produceKindRaw: String?

    var defaultServingG: Double?
    var servingDescription: String?

    var isCustom: Bool = false
    var isRecipe: Bool = false

    var lastUsed: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \FoodLogEntry.foodItem)
    var logEntries: [FoodLogEntry]?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var recipeIngredients: [RecipeIngredient]?

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        caloriesPer100g: Double,
        proteinPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double = 0,
        sugarsPer100g: Double? = nil,
        addedSugarsPer100g: Double? = nil,
        sucrosePer100g: Double? = nil,
        glucosePer100g: Double? = nil,
        fructosePer100g: Double? = nil,
        lactosePer100g: Double? = nil,
        maltosePer100g: Double? = nil,
        maltodextrinsPer100g: Double? = nil,
        starchPer100g: Double? = nil,
        polyolsPer100g: Double? = nil,
        saturatedFatPer100g: Double? = nil,
        transFatPer100g: Double? = nil,
        monounsaturatedFatPer100g: Double? = nil,
        polyunsaturatedFatPer100g: Double? = nil,
        omega3FatPer100g: Double? = nil,
        omega6FatPer100g: Double? = nil,
        omega9FatPer100g: Double? = nil,
        saltPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        cholesterolPer100g: Double? = nil,
        solubleFiberPer100g: Double? = nil,
        insolubleFiberPer100g: Double? = nil,
        caseinPer100g: Double? = nil,
        serumProteinsPer100g: Double? = nil,
        alcoholPer100g: Double? = nil,
        defaultServingG: Double? = nil,
        servingDescription: String? = nil,
        nutriscoreGrade: String? = nil,
        categoryTags: [String] = [],
        produceKind: ProduceKind? = nil,
        isCustom: Bool = false,
        isRecipe: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarsPer100g = sugarsPer100g
        self.addedSugarsPer100g = addedSugarsPer100g
        self.sucrosePer100g = sucrosePer100g
        self.glucosePer100g = glucosePer100g
        self.fructosePer100g = fructosePer100g
        self.lactosePer100g = lactosePer100g
        self.maltosePer100g = maltosePer100g
        self.maltodextrinsPer100g = maltodextrinsPer100g
        self.starchPer100g = starchPer100g
        self.polyolsPer100g = polyolsPer100g
        self.saturatedFatPer100g = saturatedFatPer100g
        self.transFatPer100g = transFatPer100g
        self.monounsaturatedFatPer100g = monounsaturatedFatPer100g
        self.polyunsaturatedFatPer100g = polyunsaturatedFatPer100g
        self.omega3FatPer100g = omega3FatPer100g
        self.omega6FatPer100g = omega6FatPer100g
        self.omega9FatPer100g = omega9FatPer100g
        self.saltPer100g = saltPer100g
        self.sodiumPer100g = sodiumPer100g
        self.cholesterolPer100g = cholesterolPer100g
        self.solubleFiberPer100g = solubleFiberPer100g
        self.insolubleFiberPer100g = insolubleFiberPer100g
        self.caseinPer100g = caseinPer100g
        self.serumProteinsPer100g = serumProteinsPer100g
        self.alcoholPer100g = alcoholPer100g
        self.defaultServingG = defaultServingG
        self.servingDescription = servingDescription
        self.nutriscoreGrade = nutriscoreGrade
        self.categoryTagsRaw = Self.rawCategoryTags(from: categoryTags)
        self.produceKindRaw = (produceKind ?? ProduceKind.inferred(fromCategoryTags: categoryTags)).rawValue
        self.isCustom = isCustom
        self.isRecipe = isRecipe
        self.lastUsed = Date()
    }

    var categoryTags: [String] {
        get {
            Self.categoryTags(fromRaw: categoryTagsRaw)
        }
        set {
            categoryTagsRaw = Self.rawCategoryTags(from: newValue)
        }
    }

    var produceKind: ProduceKind {
        get {
            ProduceKind(rawValue: produceKindRaw ?? "") ?? .unclassified
        }
        set {
            produceKindRaw = newValue.rawValue
        }
    }

    func calories(forGrams grams: Double) -> Double {
        nutrition(forGrams: grams).calories
    }

    func protein(forGrams grams: Double) -> Double {
        nutrition(forGrams: grams).proteinG
    }

    func carbs(forGrams grams: Double) -> Double {
        nutrition(forGrams: grams).carbsG
    }

    func fat(forGrams grams: Double) -> Double {
        nutrition(forGrams: grams).fatG
    }

    func fiber(forGrams grams: Double) -> Double {
        nutrition(forGrams: grams).fiberG
    }

    func sugars(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).sugarsG }
    func addedSugars(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).addedSugarsG }
    func sucrose(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).sucroseG }
    func glucose(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).glucoseG }
    func fructose(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).fructoseG }
    func lactose(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).lactoseG }
    func maltose(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).maltoseG }
    func maltodextrins(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).maltodextrinsG }
    func starch(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).starchG }
    func polyols(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).polyolsG }
    func saturatedFat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).saturatedFatG }
    func transFat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).transFatG }
    func monounsaturatedFat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).monounsaturatedFatG }
    func polyunsaturatedFat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).polyunsaturatedFatG }
    func omega3Fat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).omega3FatG }
    func omega6Fat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).omega6FatG }
    func omega9Fat(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).omega9FatG }
    func salt(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).saltG }
    func sodium(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).sodiumG }
    func cholesterol(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).cholesterolG }
    func solubleFiber(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).solubleFiberG }
    func insolubleFiber(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).insolubleFiberG }
    func casein(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).caseinG }
    func serumProteins(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).serumProteinsG }
    func alcohol(forGrams grams: Double) -> Double? { nutrition(forGrams: grams).alcoholG }

    func updateRecipeNutritionFromIngredients() {
        let ingredients = recipeIngredients ?? []
        let totalGrams = ingredients.reduce(0) { $0 + $1.portionGrams }

        guard totalGrams > 0 else {
            nutritionPer100g = .zero
            defaultServingG = nil
            servingDescription = nil
            categoryTagsRaw = nil
            produceKind = .unclassified
            return
        }

        nutritionPer100g = NutritionValues.per100g(
            fromPortions: ingredients.map(\.nutrition),
            totalGrams: totalGrams
        )
        defaultServingG = totalGrams
        servingDescription = nil
        isRecipe = true
        isCustom = false
        nutriscoreGrade = nil
        categoryTagsRaw = nil
        produceKind = .unclassified
    }

    private static func categoryTags(fromRaw rawValue: String?) -> [String] {
        rawValue?
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty } ?? []
    }

    private static func rawCategoryTags(from tags: [String]) -> String? {
        let normalizedTags = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !normalizedTags.isEmpty else { return nil }
        return normalizedTags.joined(separator: ",")
    }

    var servingInfo: ServingInfo? {
        guard let description = servingDescription,
              let gramsTotal = defaultServingG,
              gramsTotal > 0 else { return nil }

        let excludedUnits: Set<String> = [
            "g", "gr", "gram", "grams", "gramos",
            "ml", "milliliter", "milliliters", "millilitres",
            "kg", "kilogram", "kilograms",
            "l", "liter", "liters", "litre", "litres",
            "oz", "ounce", "ounces", "fl",
            "lb", "pound", "pounds",
            "cl", "dl", "serving", "portion"
        ]

        guard let match = description.wholeMatch(
            of: /^\s*(\d+(?:[.,]\d+)?)\s+(.+?)(?:\s*\(.*\))?\s*$/
        ) else { return nil }

        let countStr = String(match.1).replacingOccurrences(of: ",", with: ".")
        guard let count = Double(countStr), count > 0 else { return nil }

        let unit = String(match.2).trimmingCharacters(in: .whitespaces).lowercased()
        guard !unit.isEmpty, !excludedUnits.contains(unit) else { return nil }

        let gramsPerUnit = gramsTotal / count
        guard gramsPerUnit >= 1 else { return nil }

        let singular: String
        let plural: String
        if unit.hasSuffix("ies") {
            singular = String(unit.dropLast(3)) + "y"
            plural = unit
        } else if unit.hasSuffix("ches") || unit.hasSuffix("shes")
                    || unit.hasSuffix("ses") || unit.hasSuffix("xes")
                    || unit.hasSuffix("zes") {
            singular = String(unit.dropLast(2))
            plural = unit
        } else if unit.hasSuffix("s") && !unit.hasSuffix("ss") {
            singular = String(unit.dropLast())
            plural = unit
        } else {
            singular = unit
            plural = unit + "s"
        }

        return ServingInfo(unitName: singular, gramsPerUnit: gramsPerUnit, pluralName: plural)
    }
}

struct ServingInfo {
    let unitName: String
    let gramsPerUnit: Double
    let pluralName: String

    func label(for count: Int) -> String {
        count == 1 ? "1 \(unitName)" : "\(count) \(pluralName)"
    }
}
