import Foundation
import Testing
@testable import Caloryn

@Suite("Library food detail summary")
@MainActor
struct LibraryFoodDetailSummaryTests {
    private static let us = Locale(identifier: "en_US")
    private static let greek = Locale(identifier: "el_GR")

    private static let smoothie = NutritionValues(
        calories: 60,
        proteinG: 3.2,
        carbsG: 11,
        fatG: 1,
        fiberG: 1.6,
        sugarsG: 8.4
    )

    private func summary(
        isRecipe: Bool = false,
        isFavorite: Bool = false,
        nutriscoreGrade: String? = nil,
        grams: Double? = 250,
        servingDescription: String? = nil,
        nutrition: NutritionValues = smoothie,
        locale: Locale = us
    ) -> LibraryFoodDetailSummary {
        LibraryFoodDetailSummary(
            name: "Morning Smoothie",
            isRecipe: isRecipe,
            isFavorite: isFavorite,
            nutriscoreGrade: nutriscoreGrade,
            usualPortionGrams: grams,
            servingDescription: servingDescription,
            nutritionPer100g: nutrition,
            locale: locale
        )
    }

    private func figure(_ id: String, in summary: LibraryFoodDetailSummary) -> String? {
        summary.figures.first { $0.id == id }.map { "\($0.value) \($0.label)" }
    }

    @Test("A food's usual portion sets the four figures")
    func usualPortionFigures() {
        let summary = summary()

        #expect(summary.portionLine == "Usual portion 250 g")
        #expect(figure("kcal", in: summary) == "150 kcal a portion")
        #expect(figure("protein", in: summary) == "8 g protein")
        #expect(figure("carbs", in: summary) == "27.5 g carbs")
        #expect(figure("fat", in: summary) == "2.5 g fat")
    }

    @Test("Figures follow the locale's decimal separator")
    func figuresAreLocalised() {
        #expect(figure("carbs", in: summary(locale: Self.greek)) == "27,5 g carbs")
    }

    @Test("A recipe's usual portion is the whole recipe, counted as a total")
    func recipeIsTheWholeRecipe() {
        let summary = summary(isRecipe: true, grams: 600, servingDescription: "1 bowl (300 g)")

        #expect(summary.portionLine == "Whole recipe 600 g")
        #expect(figure("kcal", in: summary) == "360 kcal total")
        #expect(summary.typeBadge == "Recipe")
    }

    @Test("A serving description names the portion and supplies its grams when none are saved")
    func servingDescriptionNamesPortion() {
        let summary = summary(grams: nil, servingDescription: "1 glass (200 g)")

        #expect(summary.portionLine == "Usual portion 1 glass 200 g")
        #expect(figure("kcal", in: summary) == "120 kcal a portion")
    }

    @Test("Without a usual portion the figures are per 100 g and say so")
    func noPortionFallsBackTo100g() {
        for grams in [nil, 0, -5, .nan, .infinity] as [Double?] {
            let summary = summary(grams: grams)

            #expect(summary.portionLine == "No usual portion, shown per 100 g")
            #expect(figure("kcal", in: summary) == "60 kcal per 100 g")
            #expect(figure("protein", in: summary) == "3.2 g protein")
        }
    }

    @Test("The per-100 g list starts with energy and shows only recorded optional nutrients")
    func per100gLines() {
        let lines = summary().per100gLines

        #expect(lines.map(\.label) == ["Energy", "Protein", "Carbs", "Fat", "Fiber", "Sugars"])
        #expect(lines.map(\.value) == ["60 kcal", "3.2 g", "11 g", "1 g", "1.6 g", "8.4 g"])
    }

    @Test("Your own food is badged Yours, and carries its Nutri-Score grade")
    func badges() {
        let summary = summary(nutriscoreGrade: "b")

        #expect(summary.typeBadge == "Yours")
        #expect(summary.nutriscoreGrade == "b")
    }

    @Test("The favourite control names the action it will take")
    func favoriteActionLabel() {
        #expect(summary(isFavorite: true).favoriteActionLabel == "Remove Favorite")
        #expect(summary(isFavorite: false).favoriteActionLabel == "Favorite")
    }

    @Test("A food item's saved values reach the summary")
    @MainActor
    func fromFoodItem() {
        let food = makeTestFoodItem(
            name: "House Salad",
            caloriesPer100g: 45,
            proteinPer100g: 2,
            carbsPer100g: 6,
            fatPer100g: 1.5,
            defaultServingG: 180,
            nutriscoreGrade: "a",
            isCustom: true
        )
        food.setFavorite(true)
        let summary = LibraryFoodDetailSummary(food: food, locale: Self.us)

        #expect(summary.name == "House Salad")
        #expect(summary.isFavorite)
        #expect(summary.nutriscoreGrade == "a")
        #expect(summary.portionLine == "Usual portion 180 g")
        #expect(figure("kcal", in: summary) == "81 kcal a portion")
    }
}
