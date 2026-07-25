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
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
        )
    }

    func testFoodRowWithoutABrand() {
        assertSnapshot(
            of: row(FoodRowView(name: "Olive Oil", brand: nil, caloriesPer100g: 884)),
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
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
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
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
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
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
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
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
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: rowLayout, traits: .lightMode)
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
                traits: .lightMode
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
                traits: .lightMode
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
                traits: .lightMode
            )
        )
    }

    // MARK: - Helpers

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
    /// Snapshots are recorded in light mode. The theme's colours are dynamic
    /// `UIColor`s, which resolve from the trait collection rather than from
    /// SwiftUI's `colorScheme`, so pinning the style here is what actually
    /// pins it.
    static let lightMode = UITraitCollection(userInterfaceStyle: .light)
}
