import SnapshotTesting
import SwiftUI
import XCTest
@testable import Caloryn

/// Pixel snapshots of the app's reusable presentational components.
///
/// These were deliberately held back until the view-logic refactor had landed:
/// a snapshot fails on any visual change, so recording them against a structure
/// still being moved would have meant re-recording rather than reviewing.
///
/// Only components whose entire output is determined by their inputs are
/// covered. Anything reading the clock, the store, or an animation clock is
/// excluded — a snapshot that can change on its own is worse than no snapshot,
/// because it teaches the team to re-record without looking.
///
/// References are recorded on iPhone 17 / iOS 26.5, which is what
/// `.github/actions/select-simulator` pins CI to. The layout is a fixed size
/// rather than a device profile, so the images do not depend on the simulator's
/// screen at all.
final class ComponentSnapshotTests: XCTestCase {
    /// Wide enough for a realistic row, tall enough not to clip.
    private let rowLayout = SwiftUISnapshotLayout.fixed(width: 390, height: 76)

    override func setUp() {
        super.setUp()

        // FoodRowView reads this through @AppStorage, so it would otherwise
        // render differently depending on what the machine happened to have
        // stored. Pinned rather than left to chance.
        UserDefaults.standard.set(true, forKey: "showNutriscore")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "showNutriscore")
        super.tearDown()
    }

    // MARK: - Food row

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

    // MARK: - Nutri-Score day summary

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

    // MARK: - Dark mode

    // The palette declares a light and a dark appearance for every colour, but until
    // these existed only the light one was ever rendered — which is exactly where
    // `pageBackground` and `cardBackground` had been silently falling back to system
    // greys. A dark reference image is the only thing that would have caught that.

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

    // MARK: - Card surface

    // `solidCardSurface` fills with `cardBackground` and strokes with `cardSeparator`.
    // Nothing else in this suite renders either, so before this test the card surface
    // could change colour — as it just did, from pure white to #FAFAF7 — without a
    // single reference image moving.

    func testCardSurfaceOnPageBackgroundAcrossAppearances() {
        let card = VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
            Text("1,840 kcal remaining")
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CalorynTheme.cardPadding)
        .solidCardSurface(cornerRadius: CalorynTheme.cornerRadius)

        assertAppearances(
            of: card
                .padding(CalorynTheme.pagePadding)
                .frame(width: 390, height: 160)
                .background(CalorynTheme.pageBackground),
            layout: .fixed(width: 390, height: 160)
        )
    }

    // MARK: - Nutri-Score badge

    // The Nutri-Score colours are appearance-independent by design: they are the
    // official brand values and must render identically in both modes. Asserting both
    // is what makes that a checked property rather than an intention.

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

    // MARK: - Dynamic Type

    // Text metrics drive row height and truncation. At the largest accessibility size
    // a row that looks fine at .large can clip or collide, and no other test here would
    // notice: every one of them pins `.large`.

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
            .frame(width: 390, height: 220)
            .background(CalorynTheme.pageBackground),
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: 390, height: 220),
                traits: .referenceAccessibility
            )
        )
    }

    // MARK: - Helpers

    /// Renders `view` in both appearances as two separately-named reference images.
    ///
    /// The existing single-appearance tests above are deliberately left alone: their
    /// images are the recorded proof that light mode did not move when the palette
    /// migrated to the asset catalog, and re-recording them would have thrown that away.
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

    /// Every pixel must match. The two knobs are not interchangeable and
    /// getting them the wrong way round makes the whole suite decorative:
    ///
    /// - `precision` is the *fraction of pixels* allowed to differ. At 0.99 a
    ///   single changed digit is roughly 0.1% of the image, so it passes — the
    ///   first version of these tests did not notice 380 kcal becoming 381.
    /// - `perceptualPrecision` is how far each pixel may drift in colour. This
    ///   is the one that should absorb antialiasing.
    ///
    /// So: no pixels may differ, but each may differ slightly.
    private var precision: Float { 1.0 }
    private var perceptualPrecision: Float { 0.98 }

    /// Rows are rendered on the app's own background, since several of their
    /// colours are only legible against it.
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

    /// `reference` in dark mode. Same content size, so a diff between the two
    /// images is purely a colour difference.
    static let referenceDark = UITraitCollection { traits in
        traits.userInterfaceStyle = .dark
        traits.preferredContentSizeCategory = .large
    }

    /// `reference` at the largest accessibility text size, for layout that has
    /// to survive re-flow rather than for colour.
    static let referenceAccessibility = UITraitCollection { traits in
        traits.userInterfaceStyle = .light
        traits.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
    }
}
