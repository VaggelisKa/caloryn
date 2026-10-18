import SwiftUI
import Testing
@testable import Caloryn

/// The decisions the theme layer makes, never the colours it paints: colour is only
/// verified by looking (`scripts/theme-screenshots.sh`, CLAUDE.md rule 6).
@MainActor
@Suite("Theme preference decisions")
struct ThemePreferenceDecisionTests {

    @Test(
        "Each preference resolves to the colour scheme the app forces, System forcing none",
        arguments: [
            (ThemePreference.light, ColorScheme?.some(.light)),
            (ThemePreference.dark, ColorScheme?.some(.dark)),
            (ThemePreference.system, ColorScheme?.none),
        ]
    )
    func preferenceResolvesToColorScheme(preference: ThemePreference, expected: ColorScheme?) {
        #expect(preference.colorScheme == expected)
    }

    /// `@AppStorage("themePreference")` stores the raw value, so renaming a case would
    /// silently reset every user's choice to System on the next launch.
    @Test(
        "The stored raw values are the strings already on users' devices",
        arguments: [
            ("light", ThemePreference.light),
            ("dark", ThemePreference.dark),
            ("system", ThemePreference.system),
        ]
    )
    func rawValuesRoundTrip(raw: String, preference: ThemePreference) {
        #expect(preference.rawValue == raw)
        #expect(ThemePreference(rawValue: raw) == preference)
    }

    @Test(
        "A stored value the enum does not know is not a preference, so the view falls back",
        arguments: ["", "Light", "DARK", "auto", "sepia"]
    )
    func unknownRawValueIsRejected(raw: String) {
        #expect(ThemePreference(rawValue: raw) == nil)
    }

    @Test("Settings lists Light, Dark, System in that order")
    func settingsOrder() {
        #expect(ThemePreference.allCases.map(\.displayName) == ["Light", "Dark", "System"])
    }

    @Test(
        "Each choice carries its own SF Symbol",
        arguments: [
            (ThemePreference.light, "sun.max.fill"),
            (ThemePreference.dark, "moon.fill"),
            (ThemePreference.system, "circle.lefthalf.filled"),
        ]
    )
    func icons(preference: ThemePreference, symbol: String) {
        #expect(preference.icon == symbol)
    }
}

/// `MealType.fill` and friends exist only to save call sites a lookup; what matters is that
/// each one reaches the matching role in `CalorynTheme` for the same meal.
@MainActor
@Suite("Meal theme role mapping")
struct MealThemeMappingTests {

    @Test("Each meal's fill, ink and wash read the same meal's theme roles", arguments: MealType.allCases)
    func rolesMapToTheSameMeal(meal: MealType) {
        #expect(meal.fill == CalorynTheme.mealFill(meal))
        #expect(meal.ink == CalorynTheme.mealInk(meal))
        #expect(meal.wash == CalorynTheme.mealWash(meal))
    }
}

/// The two font rules with a decision in them: which x-axis size a chart takes, and that a
/// fixed display size honours the size it is given.
@MainActor
@Suite("Theme font rules")
struct CalorynThemeFontRuleTests {

    @Test(
        "The trend chart switches to the dense axis label only past a week of points",
        arguments: [(1, false), (6, false), (7, false), (8, true), (14, true), (90, true)]
    )
    func trendAxisDensity(pointCount: Int, isDense: Bool) {
        let expected = isDense ? CalorynTheme.denseChartXAxisLabel : CalorynTheme.chartXAxisLabel
        #expect(CalorynTheme.trendChartXAxisLabel(pointCount: pointCount) == expected)
        #expect(CalorynTheme.weeklyChartXAxisLabel(isDense: isDense) == expected)
    }

    @Test("The dense and regular chart axis labels are different fonts")
    func denseDiffersFromRegular() {
        #expect(CalorynTheme.weeklyChartXAxisLabel(isDense: true) != CalorynTheme.weeklyChartXAxisLabel(isDense: false))
    }

    @Test("Hero numbers take the size they are given")
    func displayNumbersHonourSize() {
        #expect(CalorynTheme.heroNumber(size: 56) == CalorynTheme.heroNumber(size: 56))
        #expect(CalorynTheme.heroNumber(size: 56) != CalorynTheme.heroNumber(size: 28))
    }
}
