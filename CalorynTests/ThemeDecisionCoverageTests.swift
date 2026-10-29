import SwiftUI
import Testing
@testable import Caloryn

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

@MainActor
@Suite("Theme font rules")
struct CalorynThemeFontRuleTests {
    @Test("The chart axis label is the dense one exactly when asked for", arguments: [false, true])
    func axisLabelDensity(isDense: Bool) {
        let expected = isDense ? CalorynTheme.denseChartXAxisLabel : CalorynTheme.chartXAxisLabel
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
