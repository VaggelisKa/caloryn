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
                .background(CalorynTheme.backgroundPrimary),
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
        .background(CalorynTheme.backgroundPrimary)

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
        .background(CalorynTheme.backgroundSecondary)

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
        .background(CalorynTheme.backgroundPrimary)

        assertAppearances(of: donuts, layout: .fixed(width: 390, height: 200))
    }

    func testCalorieMiniDonutOutlinesAcrossAppearances() {
        let plates = HStack(spacing: 12) {
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 2_300], budget: 2_000, isOver: true),
                outline: .over,
                uniformFill: CalorynTheme.dataSecondary
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 1_690], budget: 2_000, isOver: false),
                uniformFill: CalorynTheme.dataSecondary
            )
            CalorieMiniDonutView(
                summary: CalorieDonutSummary(mealTotals: [.dinner: 963], budget: 2_000, isOver: false),
                outline: .today,
                uniformFill: CalorynTheme.dataSecondary
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
        .background(CalorynTheme.backgroundPrimary)

        assertAppearances(of: plates, layout: .fixed(width: 390, height: 72))
    }

    func testHistoryDayPlateGridAtMonthSizeAcrossAppearances() {
        let grid = HistoryDayPlateGrid(strip: dayPlateStrip(dayCount: 30, columnCount: 10, plateSize: 28))
            .padding(CalorynTheme.pagePadding)
            .frame(width: 402, height: 230)
            .background(CalorynTheme.backgroundPrimary)

        assertAppearances(of: grid, layout: .fixed(width: 402, height: 230))
    }

    func testHistoryDayPlateGridAtWeekSizeAcrossAppearances() {
        let grid = HistoryDayPlateGrid(strip: dayPlateStrip(dayCount: 14, columnCount: 7, plateSize: 40))
            .padding(CalorynTheme.pagePadding)
            .frame(width: 402, height: 200)
            .background(CalorynTheme.backgroundPrimary)

        assertAppearances(of: grid, layout: .fixed(width: 402, height: 200))
    }

    func testSettingsGoalPlateAcrossAppearances() {
        let days: [(meals: [MealType: Double], isOver: Bool)] = [
            ([:], false),
            ([.breakfast: 420, .lunch: 610], false),
            ([.breakfast: 300, .dinner: 900], false),
            ([.lunch: 2_000], false),
            ([.breakfast: 500, .lunch: 600, .dinner: 700, .snack: 200], false),
            ([.breakfast: 900, .lunch: 800, .dinner: 700], true),
        ]
        let plates = VStack(spacing: 12) {
            ForEach([CGFloat(40), 43.667], id: \.self) { size in
                HStack(spacing: 12) {
                    ForEach(days.indices, id: \.self) { index in
                        CalorieMiniDonutView(
                            summary: CalorieDonutSummary(
                                mealTotals: days[index].meals,
                                budget: 2_000,
                                isOver: days[index].isOver
                            ),
                            size: size,
                            plateColor: CalorynTheme.backgroundPrimary,
                            fillsPlate: true
                        )
                    }
                }
            }
        }
        .frame(width: 390, height: 130)
        .background(CalorynTheme.backgroundSecondary)

        assertAppearances(of: plates, layout: .fixed(width: 390, height: 130))
    }

    func testNutriscoreBadgeForEveryGradeAcrossAppearances() {
        let badges = HStack(spacing: 8) {
            ForEach(["a", "b", "c", "d", "e"], id: \.self) { grade in
                NutriscoreBadge(grade: grade)
            }
        }
        .padding(16)
        .frame(width: 390, height: 72)
        .background(CalorynTheme.backgroundPrimary)

        assertAppearances(of: badges, layout: .fixed(width: 390, height: 72))
    }

    func testPastedFoodConfirmationAcrossAppearances() {
        let confirmation = PastedFoodConfirmation(
            draft: LogLinkDraft(
                name: "Chicken Caesar salad with croutons, parmesan and extra dressing",
                kcal: 640.5,
                grams: nil,
                proteinG: 38.5,
                carbsG: nil,
                fatG: 42,
                meal: nil
            ),
            locale: Locale(identifier: "en_US")
        )
        let form = PastedFoodConfirmationForm(confirmation: .constant(confirmation), mealType: .lunch)
            .environment(\.locale, Locale(identifier: "en_US"))
            .frame(width: 390, height: 660, alignment: .top)
            .background(CalorynTheme.backgroundSecondary)

        assertAppearances(of: form, layout: .fixed(width: 390, height: 660))
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
            .background(CalorynTheme.backgroundPrimary),
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
            .background(CalorynTheme.backgroundPrimary)
    }

    private func summary(_ view: some View) -> some View {
        view
            .padding(16)
            .frame(width: 390, height: 140)
            .background(CalorynTheme.backgroundPrimary)
    }

    private func dayPlateStrip(dayCount: Int, columnCount: Int, plateSize: CGFloat) -> HistoryDayPlateStrip {
        let calories: [Double] = [
            0, 12, 40, 350, 963, 1_000, 1_500, 1_690, 1_990, 1_999.5, 2_000, 2_300, 1_240, 640, 1_810,
        ]
        let periods = (0..<dayCount).map { offset in
            let kcal = calories[offset % calories.count]
            return HistoryDayPlateStrip.Period(
                start: Date(timeIntervalSinceReferenceDate: Double(offset) * 86_400),
                label: "\(offset + 1)",
                calories: kcal,
                target: 2_000,
                status: kcal == 0 ? .notLogged : (kcal > 2_000 ? .over : .onTrack),
                isCurrent: offset == dayCount - 1
            )
        }
        return HistoryDayPlateStrip(
            periods: periods,
            granularity: .day,
            columnCount: columnCount,
            plateSize: plateSize
        )
    }
}

private extension UITraitCollection {
    /// The environment every reference image is recorded in.
    ///
    /// Both traits have to be named explicitly:
    ///
    /// - **Interface style**, because the theme's colours are Color Sets that
    ///   resolve from the trait collection rather than from SwiftUI's
    ///   `colorScheme` — so this is the only place setting it has any effect.
    /// - **Content size category**, because text metrics change with Dynamic
    ///   Type. A simulator left on a non-default setting would otherwise
    ///   re-flow every label and fail images whose components had not changed
    ///   at all.
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
