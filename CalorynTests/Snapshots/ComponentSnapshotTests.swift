import SnapshotTesting
import SwiftUI
import XCTest
@testable import Caloryn

final class ComponentSnapshotTests: XCTestCase {
    private let rowLayout = SwiftUISnapshotLayout.fixed(width: 390, height: 76)

    override func setUp() {
        super.setUp()

        UserDefaults.standard.set(true, forKey: "showNutriscore")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "showNutriscore")
        super.tearDown()
    }

    func testFoodRowWithBrandAndServing() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "Rolled Oats",
                    brand: "Quaker",
                    caloriesPer100g: 380,
                    servingDescription: "40 g"
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowWithoutABrand() {
        assertSnapshot(
            of: row(FoodRowView(name: "Olive Oil", brand: nil, caloriesPer100g: 884)),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowShowsTheCustomBadge() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "House Salad",
                    brand: nil,
                    caloriesPer100g: 120,
                    isCustom: true
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowShowsTheRecipeBadge() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "Sunday Chilli",
                    brand: "ignored for recipes",
                    caloriesPer100g: 145,
                    isRecipe: true
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowWithANutriScore() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "Greek Yogurt",
                    brand: "Fage",
                    caloriesPer100g: 97,
                    nutriscoreGrade: "b"
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowWithALongNameTruncatesRatherThanWrapping() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "Organic Sprouted Whole Grain Sourdough Sandwich Bread with Flax and Sunflower Seeds",
                    brand: "A Very Long Bakery Name Indeed",
                    caloriesPer100g: 247,
                    servingDescription: "1 slice (45 g)"
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testFoodRowWithACountableServing() {
        assertSnapshot(
            of: row(
                FoodRowView(
                    name: "Skyr",
                    brand: "Arla",
                    caloriesPer100g: 63,
                    nutriscoreGrade: "a",
                    servingDescription: "1 pot (150g)",
                    caloriesPerServing: 94.5
                )
            ),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .reference)
        )
    }

    func testNutriScoreSummaryWithAMixedDay() {
        assertSnapshot(
            of: summary(
                NutriscoreDaySummary(distribution: [("a", 3), ("b", 2), ("c", 1), ("e", 1)])
            ),
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: 390, height: 140),
                traits: .reference
            )
        )
    }

    func testNutriScoreSummaryWithASingleGrade() {
        assertSnapshot(
            of: summary(NutriscoreDaySummary(distribution: [("a", 4)])),
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: 390, height: 140),
                traits: .reference
            )
        )
    }

    func testNutriScoreSummaryWithNothingLogged() {
        assertSnapshot(
            of: summary(NutriscoreDaySummary(distribution: [])),
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: 390, height: 140),
                traits: .reference
            )
        )
    }

    func testFoodRowAcrossAppearances() {
        assertAppearances(
            of: row(
                FoodRowView(
                    name: "Rolled Oats",
                    brand: "Quaker",
                    caloriesPer100g: 380,
                    servingDescription: "40 g"
                )
            ),
            layout: rowLayout
        )
    }

    func testFoodRowWithANutriScoreAcrossAppearances() {
        assertAppearances(
            of: row(
                FoodRowView(
                    name: "Greek Yogurt",
                    brand: "Fage",
                    caloriesPer100g: 97,
                    nutriscoreGrade: "b"
                )
            ),
            layout: rowLayout
        )
    }

    func testNutriScoreSummaryAcrossAppearances() {
        assertAppearances(
            of: summary(
                NutriscoreDaySummary(distribution: [("a", 3), ("b", 2), ("c", 1), ("e", 1)])
            ),
            layout: .fixed(width: 390, height: 140)
        )
    }

    func testGroupSurfaceOnPageBackgroundAcrossAppearances() {
        let card = VStack(alignment: .leading, spacing: 6) {
            Text("Lunch runs heavy on weekdays")
                .font(CalorynTheme.sectionHeaderTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
            Text("1.840 kcal remaining")
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CalorynTheme.cardPadding)
        .calorynGroupSurface()

        assertAppearances(
            of: card
                .padding(CalorynTheme.pagePadding)
                .frame(width: 390, height: 160)
                .background(CalorynTheme.pageBackground),
            layout: .fixed(width: 390, height: 160)
        )
    }

    func testMealSectionHeadersAcrossAppearances() {
        let headers = VStack(spacing: 14) {
            ForEach(MealType.allCases) { meal in
                CalorynMealSectionHeader(
                    meal: meal,
                    totalText: meal == .dinner ? "nothing yet" : "382 kcal",
                    addAccessibilityIdentifier: "snapshot.\(meal.rawValue)",
                    addAccessibilityLabel: "Add to \(meal.displayName)",
                    onAdd: {}
                )
            }
        }
        .padding(CalorynTheme.pagePadding)
        .frame(width: 390, height: 230)
        .background(CalorynTheme.pageBackground)

        assertAppearances(of: headers, layout: .fixed(width: 390, height: 230))
    }

    func testMealChipsSelectedAndUnselectedAcrossAppearances() {
        let chips = VStack(alignment: .leading, spacing: 10) {
            ForEach([true, false], id: \.self) { isSelected in
                HStack(spacing: 6) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName)
                            .calorynChip(isSelected: isSelected, meal: meal)
                            .fixedSize()
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(CalorynTheme.pagePadding)
        .frame(width: 440, height: 130)
        .background(CalorynTheme.cardBackground)

        assertAppearances(of: chips, layout: .fixed(width: 440, height: 130))
    }

    func testCalorieDonutUnderAndOverAcrossAppearances() {
        let donuts = HStack(spacing: 22) {
            CalorieDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 382, .lunch: 463, .snack: 118],
                    budget: 2_000,
                    isOver: false
                ),
                animated: false
            )
            CalorieDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 118],
                    budget: 2_000,
                    isOver: true
                ),
                animated: false
            )
        }
        .frame(width: 390, height: 200)
        .background(CalorynTheme.pageBackground)

        assertAppearances(of: donuts, layout: .fixed(width: 390, height: 200))
    }

    func testCalorieMiniDonutOutlinesAcrossAppearances() {
        let plates = HStack(spacing: 12) {
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 2_300], budget: 2_000, isOver: true),
                outline: .over,
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 1_690], budget: 2_000, isOver: false),
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 963], budget: 2_000, isOver: false),
                outline: .today,
                uniformFill: CalorynTheme.historyEaten
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(
                    mealTotals: [.breakfast: 500, .lunch: 600, .dinner: 700, .snack: 200],
                    budget: 2_000,
                    isOver: false
                )
            )
        }
        .frame(width: 390, height: 72)
        .background(CalorynTheme.pageBackground)

        assertAppearances(of: plates, layout: .fixed(width: 390, height: 72))
    }

    func testNutriscoreBadgeForEveryGradeAcrossAppearances() {
        let badges = HStack(spacing: 8) {
            ForEach(["a", "b", "c", "d", "e"], id: \.self) { grade in
                NutriscoreBadge(grade: grade)
            }
        }
        .padding(16)
        .frame(width: 390, height: 72)
        .background(CalorynTheme.pageBackground)

        assertAppearances(of: badges, layout: .fixed(width: 390, height: 72))
    }

    func testFoodRowAtLargestAccessibilitySize() {
        assertSnapshot(
            of: FoodRowView(
                name: "Greek Yogurt",
                brand: "Fage",
                caloriesPer100g: 97,
                nutriscoreGrade: "b",
                servingDescription: "170 g"
            )
            .padding(.horizontal, 16)
            .frame(width: 390, height: 300)
            .background(CalorynTheme.pageBackground),
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: 390, height: 300),
                traits: .referenceAccessibility
            )
        )
    }

    private func assertAppearances(
        of view: some View,
        layout: SwiftUISnapshotLayout,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        assertSnapshots(
            of: view,
            as: [
                "light": .image(
                    precision: precision,
                    perceptualPrecision: perceptualPrecision,
                    layout: layout,
                    traits: .reference
                ),
                "dark": .image(
                    precision: precision,
                    perceptualPrecision: perceptualPrecision,
                    layout: layout,
                    traits: .referenceDark
                ),
            ],
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }

    private var precision: Float { 1.0 }
    private var perceptualPrecision: Float { 0.98 }

    private func row(_ view: some View) -> some View {
        view
            .padding(.horizontal, 16)
            .frame(width: 390, height: 76)
            .background(CalorynTheme.pageBackground)
    }

    private func summary(_ view: some View) -> some View {
        view
            .padding(16)
            .frame(width: 390, height: 140)
            .background(CalorynTheme.pageBackground)
    }
}

private extension UITraitCollection {
    static let reference = UITraitCollection { traits in
        traits.userInterfaceStyle = .light
        traits.preferredContentSizeCategory = .large
    }

    static let referenceDark = UITraitCollection { traits in
        traits.userInterfaceStyle = .dark
        traits.preferredContentSizeCategory = .large
    }

    static let referenceAccessibility = UITraitCollection { traits in
        traits.userInterfaceStyle = .light
        traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    }
}
