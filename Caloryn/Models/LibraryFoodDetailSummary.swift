import Foundation

struct LibraryFoodDetailSummary: Equatable {
    struct Figure: Identifiable, Equatable {
        let id: String
        let value: String
        let label: String
    }

    struct NutrientLine: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    let name: String
    let typeBadge: String
    let nutriscoreGrade: String?
    let isFavorite: Bool
    let portionLine: String
    let figures: [Figure]
    let per100gLines: [NutrientLine]

    init(
        name: String,
        isRecipe: Bool,
        isFavorite: Bool,
        nutriscoreGrade: String?,
        usualPortionGrams: Double?,
        servingDescription: String?,
        nutritionPer100g: NutritionValues,
        locale: Locale = .current
    ) {
        self.name = name
        typeBadge = isRecipe ? "Recipe" : "Yours"
        self.nutriscoreGrade = nutriscoreGrade
        self.isFavorite = isFavorite

        let description = isRecipe ? nil : Self.nonEmpty(servingDescription)
        let portionGrams = usualPortionGrams.flatMap(Self.positive)
            ?? description.flatMap(FoodLogSheetCopy.servingGrams)

        let figureGrams: Double
        let kcalLabel: String
        if let portionGrams {
            let amount = description.map(FoodLogSheetCopy.serving)
                ?? portionGrams.rounded().spacedMacroFormatted(locale: locale)
            portionLine = isRecipe ? "Whole recipe \(amount)" : "Usual portion \(amount)"
            figureGrams = portionGrams
            kcalLabel = isRecipe ? "kcal total" : "kcal a portion"
        } else {
            portionLine = "No usual portion, shown per 100 g"
            figureGrams = 100
            kcalLabel = "kcal per 100 g"
        }

        let portion = nutritionPer100g.scaled(by: figureGrams / 100)
        figures = [
            Figure(id: "kcal", value: Self.kcal(portion.calories, locale: locale), label: kcalLabel),
            Figure(id: "protein", value: portion.proteinG.spacedMacroFormatted(locale: locale), label: "protein"),
            Figure(id: "carbs", value: portion.carbsG.spacedMacroFormatted(locale: locale), label: "carbs"),
            Figure(id: "fat", value: portion.fatG.spacedMacroFormatted(locale: locale), label: "fat")
        ]

        let energy = NutrientLine(
            id: "energy",
            label: "Energy",
            value: "\(Self.kcal(nutritionPer100g.calories, locale: locale)) kcal"
        )
        per100gLines = [energy] + PortionNutrientBreakdown(nutrition: nutritionPer100g).items.map { nutrient in
            NutrientLine(
                id: nutrient.id,
                label: nutrient.label,
                value: nutrient.spacedFormattedValue(locale: locale)
            )
        }
    }

    var favoriteActionLabel: String {
        isFavorite ? "Remove Favorite" : "Favorite"
    }

    private static func kcal(_ calories: Double, locale: Locale) -> String {
        calories.roundedCalories.formatted(.number.locale(locale))
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func positive(_ grams: Double) -> Double? {
        grams.isFinite && grams > 0 ? grams : nil
    }
}

extension LibraryFoodDetailSummary {
    init(food: FoodItem, locale: Locale = .current) {
        self.init(
            name: food.name,
            isRecipe: food.isRecipe,
            isFavorite: food.isFavorite,
            nutriscoreGrade: food.nutriscoreGrade,
            usualPortionGrams: food.defaultServingG,
            servingDescription: food.servingDescription,
            nutritionPer100g: food.nutritionPer100g,
            locale: locale
        )
    }
}
