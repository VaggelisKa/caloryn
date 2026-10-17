import Foundation
import Testing
@testable import Caloryn

/// What the restyled Today screens print: the hero's number column, the date heading, a
/// meal header's total and its empty row, and how Nutrition Details sorts and words a day.
struct TodayPlateSummaryTests {
    private let us = Locale(identifier: "en_US")
    private let danish = Locale(identifier: "da_DK")

    // MARK: - Hero

    @Test("Under budget the hero counts down what is left, against the target it names")
    func heroUnderBudget() {
        let hero = makeHero(
            mealTotals: [.breakfast: 382, .lunch: 463, .snack: 118],
            isOver: false,
            remaining: 1_037,
            overAmount: 0,
            consumed: 963
        )

        #expect(hero.isOver == false)
        #expect(hero.headline == 1_037)
        #expect(hero.headlineText == "1,037")
        #expect(hero.caption == "kcal left of 2,000")
        #expect(hero.eatenLine == "963 of 2,000 eaten")
    }

    @Test("Over budget the hero counts up the overshoot and says so in the caption")
    func heroOverBudget() {
        let hero = makeHero(
            mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
            isOver: true,
            remaining: 0,
            overAmount: 340,
            consumed: 2_340
        )

        #expect(hero.isOver)
        #expect(hero.headline == 340)
        #expect(hero.caption == "kcal over")
        #expect(hero.eatenLine == "2,340 of 2,000 eaten")
    }

    @Test("Figures are grouped for the reader's locale, so the caption agrees with the number")
    func heroGroupsForTheLocale() {
        let hero = makeHero(
            mealTotals: [.breakfast: 382],
            isOver: false,
            remaining: 1_618,
            overAmount: 0,
            consumed: 382,
            locale: danish
        )

        #expect(hero.headlineText == "1.618")
        #expect(hero.caption == "kcal left of 2.000")
    }

    @Test("A legend row names its meal and its kcal, or 'not yet' when nothing is logged there")
    func heroLegendWording() {
        let hero = makeHero(
            mealTotals: [.breakfast: 0, .dinner: 1_377],
            isOver: false,
            remaining: 623,
            overAmount: 0,
            consumed: 1_377
        )

        let breakfast = CalorieDonutSummary.LegendEntry(meal: .breakfast, kcal: 0, isLogged: true)
        let lunch = CalorieDonutSummary.LegendEntry(meal: .lunch, kcal: 0, isLogged: false)
        let dinner = CalorieDonutSummary.LegendEntry(meal: .dinner, kcal: 1_377, isLogged: true)

        #expect(hero.legendValue(for: breakfast) == "0")
        #expect(hero.legendValue(for: lunch) == "not yet")
        #expect(hero.legendValue(for: dinner) == "1,377")
        #expect(hero.legendName(for: dinner) == "Dinner")
        #expect(hero.legendName(for: .over(kcal: 340)) == "Over")
    }

    @Test("Meal totals add up per meal, and a meal with nothing logged gets no key")
    func heroMealTotals() {
        struct Logged { let meal: MealType; let kcal: Double }
        let totals = TodayHeroSummary.mealTotals(
            [
                Logged(meal: .breakfast, kcal: 300),
                Logged(meal: .breakfast, kcal: 82),
                Logged(meal: .snack, kcal: 0),
                Logged(meal: .snack, kcal: 118),
            ],
            mealType: \.meal,
            calories: \.kcal
        )

        #expect(totals == [.breakfast: 382, .snack: 118])
        #expect(totals[.lunch] == nil)
    }

    // MARK: - Date heading

    @Test("The heading is weekday, day and month")
    func dayTitleText() {
        #expect(DayTitle.text(for: friday17October, in: calendar) == "Friday 17 October")
    }

    @Test("VoiceOver keeps the relative day the old 'Today' heading carried")
    func dayTitleAccessibilityLabel() {
        let now = friday17October.addingTimeInterval(9 * 3_600)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: friday17October)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: friday17October)!
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: friday17October)!

        #expect(DayTitle.accessibilityLabel(for: friday17October, now: now, in: calendar) == "Today, Friday 17 October")
        #expect(DayTitle.accessibilityLabel(for: yesterday, now: now, in: calendar) == "Yesterday, Thursday 16 October")
        #expect(DayTitle.accessibilityLabel(for: tomorrow, now: now, in: calendar) == "Tomorrow, Saturday 18 October")
        #expect(DayTitle.accessibilityLabel(for: lastWeek, now: now, in: calendar) == "Friday 10 October")
    }

    // MARK: - Meal header and empty row

    @Test("A meal header totals its kcal rounded and grouped, and an empty meal says 'nothing yet'")
    func mealHeaderTotal() {
        let dinner = MealSectionSummary(mealType: .dinner, entries: [entry(640.4), entry(736.7)])
        let empty = MealSectionSummary(mealType: .dinner, entries: [])

        #expect(dinner.headerTotalText(locale: us) == "1,377 kcal")
        #expect(dinner.isEmpty == false)
        #expect(empty.headerTotalText(locale: us) == "nothing yet")
        #expect(empty.isEmpty)
    }

    @Test("A zero-calorie entry still counts as logged")
    func mealHeaderWithAZeroCalorieEntry() {
        let coffee = MealSectionSummary(mealType: .breakfast, entries: [entry(0)])

        #expect(coffee.isEmpty == false)
        #expect(coffee.headerTotalText(locale: us) == "0 kcal")
    }

    @Test("The empty row offers copying yesterday only while that control is on screen")
    func emptyRowText() {
        let dinner = MealSectionSummary(mealType: .dinner, entries: [])
        let snack = MealSectionSummary(mealType: .snack, snackIndex: 1, titleOverride: "Snacks", entries: [])

        #expect(dinner.emptyRowText(canCopyYesterday: true) == "Add dinner, or copy yesterday's.")
        #expect(dinner.emptyRowText(canCopyYesterday: false) == "Add dinner.")
        #expect(snack.emptyRowText(canCopyYesterday: false) == "Add a snack.")
    }

    // MARK: - Nutrition Details

    @Test("Nutrients with a target become bars; the rest become amounts, in nutrient order")
    func detailsSortsTargetsFromAmounts() {
        let protein = TrackedNutrientMetric(nutrient: .protein, value: 46, target: 150, goalKind: .minimum)
        let fiber = TrackedNutrientMetric(nutrient: .fiber, value: 14, target: nil, goalKind: nil)
        let saturated = TrackedNutrientMetric(nutrient: .saturatedFat, value: 9, target: 0, goalKind: .maximum)

        let sections = NutritionDetailsSections(metrics: [protein, fiber, saturated], details: [])

        #expect(sections.targets.map(\.nutrient) == [.protein])
        #expect(sections.targets.first?.valueText == protein.formattedValue)
        #expect(sections.targets.first?.targetText == "of \(protein.formattedTarget ?? "")")
        #expect(abs((sections.targets.first?.progress ?? 0) - 46.0 / 150.0) < 0.000_1)
        #expect(sections.amounts.map(\.label) == ["Fiber", "Saturated fat"])
        #expect(sections.breakdowns.isEmpty)
    }

    @Test("A target row says how far past a maximum it is; minimums and goals never read as over")
    func detailsTargetRowOverMaximum() {
        let saturated = TrackedNutrientMetric(nutrient: .saturatedFat, value: 34.8, target: 20, goalKind: .maximum)
        let sugars = TrackedNutrientMetric(nutrient: .sugars, value: 38, target: 50, goalKind: .maximum)
        let protein = TrackedNutrientMetric(nutrient: .protein, value: 180, target: 150, goalKind: .minimum)
        let carbs = TrackedNutrientMetric(nutrient: .carbs, value: 274.6, target: 200, goalKind: .target)
        let sodium = TrackedNutrientMetric(nutrient: .sodium, value: 2.4, target: 2.3, goalKind: .maximum)

        let rows = NutritionDetailsSections(
            metrics: [saturated, sugars, protein, carbs, sodium],
            details: [],
            locale: us
        ).targets
        let byNutrient = Dictionary(uniqueKeysWithValues: rows.map { ($0.nutrient, $0) })

        #expect(byNutrient[.saturatedFat]?.isOverMaximum == true)
        #expect(byNutrient[.saturatedFat]?.overText == "14.8 g over")
        #expect(byNutrient[.saturatedFat]?.targetText == "of 20 g max")
        #expect(byNutrient[.saturatedFat]?.progress == 1)
        #expect(byNutrient[.saturatedFat]?.accessibilityLabel == "\(saturated.accessibilityLabel), 14.8 g over")
        #expect(byNutrient[.sodium]?.overText == "100 mg over")

        #expect(byNutrient[.sugars]?.isOverMaximum == false)
        #expect(byNutrient[.sugars]?.accessibilityLabel == sugars.accessibilityLabel)
        #expect(byNutrient[.protein]?.isOverMaximum == false)
        #expect(byNutrient[.carbs]?.isOverMaximum == false)
    }

    @Test("Past a maximum by less than the figures show is not called over")
    func detailsOverMaximumBelowDisplayPrecision() {
        #expect(NutritionDetailsSections.overMaximumText(value: 20.04, target: 20, goalKind: .maximum, unit: .grams) == nil)
        #expect(
            NutritionDetailsSections.overMaximumText(value: 20.06, target: 20, goalKind: .maximum, unit: .grams, locale: us)
                == "0.1 g over"
        )
        #expect(NutritionDetailsSections.overMaximumText(value: 20, target: 20, goalKind: .maximum, unit: .grams) == nil)
        #expect(NutritionDetailsSections.overMaximumText(value: 30, target: 20, goalKind: nil, unit: .grams) == nil)
    }

    @Test("The line beside the big number names the target, and the overshoot once past it")
    func detailsCalorieTargetText() {
        #expect(
            NutritionDetailsSections.calorieTargetText(adjustedTarget: 2_000, isOver: false, overAmount: 0, locale: us)
                == "of 2,000 kcal"
        )
        #expect(
            NutritionDetailsSections.calorieTargetText(adjustedTarget: 2_000, isOver: true, overAmount: 337, locale: danish)
                == "of 2.000 kcal, 337 over"
        )
    }

    @Test("The food line counts items and weighs them as every weight is written, grouped for the locale")
    func detailsFoodAmountText() {
        let summary = NutritionDetailsSummary(entries: [
            NutritionDetailsSummary.Entry(nutrition: NutritionValues(calories: 900), portionGrams: 1_000),
            NutritionDetailsSummary.Entry(nutrition: NutritionValues(calories: 500), portionGrams: 450),
        ])

        #expect(NutritionDetailsSections.foodAmountText(summary: summary, locale: danish) == "2 items, 1.450 g of food")
        #expect(NutritionDetailsSections.foodAmountText(summary: summary, locale: us) == "2 items, 1,450 g of food")
    }

    @Test("Fruit and veg counts kinds and counts down to five without ever going negative")
    func detailsProduceWording() {
        #expect(NutritionDetailsSections.produceCountText(0) == "none yet")
        #expect(NutritionDetailsSections.produceCountText(1) == "1 kind today")
        #expect(NutritionDetailsSections.produceCountText(3) == "3 kinds today")
        #expect(NutritionDetailsSections.produceRemainingText(0) == "5 more for variety")
        #expect(NutritionDetailsSections.produceRemainingText(3) == "2 more for variety")
        #expect(NutritionDetailsSections.produceRemainingText(5) == nil)
        #expect(NutritionDetailsSections.produceRemainingText(8) == nil)
    }

    @Test("Nutri-Score coverage and sentence-cased nutrient names")
    func detailsCopy() {
        #expect(NutritionDetailsSections.nutriscoreGradedText(graded: 6, total: 7) == "6 of 7 items graded")
        #expect(NutritionDetailsSections.nutriscoreGradedText(graded: 1, total: 1) == "1 of 1 item graded")
        #expect("Saturated Fat".sentenceCased == "Saturated fat")
        #expect("Auto-adjust Calories".sentenceCased == "Auto-adjust calories")
        #expect("".sentenceCased == "")
    }

    // MARK: - Helpers

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// Friday 17 October 2025, midnight UTC.
    private var friday17October: Date {
        calendar.date(from: DateComponents(year: 2025, month: 10, day: 17))!
    }

    private func entry(_ calories: Double) -> MealSectionSummary.Entry {
        MealSectionSummary.Entry(calories: calories, proteinG: 0, carbsG: 0, fatG: 0)
    }

    private func makeHero(
        mealTotals: [MealType: Double],
        isOver: Bool,
        remaining: Int,
        overAmount: Int,
        consumed: Int,
        locale: Locale? = nil
    ) -> TodayHeroSummary {
        TodayHeroSummary(
            ring: CalorieRingSummary(
                isOver: isOver,
                remaining: remaining,
                overAmount: overAmount,
                roundedConsumed: consumed,
                adjustedTarget: 2_000
            ),
            donut: CalorieDonutSummary(mealTotals: mealTotals, budget: 2_000, isOver: isOver),
            locale: locale ?? us
        )
    }
}
