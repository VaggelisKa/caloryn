import Testing
@testable import Caloryn

/// Covers the nutrient multi-select on the last onboarding step, whose rules
/// were until now only reachable by tapping tiles.
@MainActor
@Suite("Onboarding nutrient selection")
struct OnboardingNutrientSelectionTests {

    // MARK: - Core macros

    /// Reading a stored value only tops it up to the shared minimum tracked
    /// count, which a single extra plus two macros already meets — so reading
    /// alone does not put every macro back. Normalizing, which the step does as
    /// soon as it appears, is what guarantees all three.
    @Test("Reading a thin stored value tops it up to the minimum but need not restore every macro")
    func readingOnlyTopsUpToTheMinimum() {
        let selection = OnboardingNutrientSelection(rawValue: TrackedNutrient.rawSelection(from: [.fiber]))

        #expect(selection.selected.count == TrackedNutrient.minimumSelectionCount)
        #expect(selection.isSelected(.fiber))
    }

    @Test("Normalizing puts every core macro back, whatever the stored value held")
    func normalizingRestoresEveryCoreMacro() {
        let normalized = OnboardingNutrientSelection(
            rawValue: OnboardingNutrientSelection(rawValue: TrackedNutrient.rawSelection(from: [.fiber]))
                .normalizedRawValue
        )

        for macro in TrackedNutrient.defaultSelection {
            #expect(normalized.isSelected(macro))
        }
        #expect(normalized.isSelected(.fiber))
    }

    @Test("Normalizing puts the core macros back in front of whatever extras were stored")
    func normalizingRestoresTheCoreMacros() {
        let selection = OnboardingNutrientSelection(rawValue: TrackedNutrient.rawSelection(from: [.fiber, .sodium]))

        #expect(
            selection.normalizedRawValue
                == TrackedNutrient.rawSelection(from: TrackedNutrient.defaultSelection + [.fiber, .sodium])
        )
    }

    @Test("Normalizing an empty stored value yields exactly the core macros")
    func normalizingEmptyYieldsTheCoreMacros() {
        let selection = OnboardingNutrientSelection(rawValue: "")

        #expect(selection.normalizedRawValue == TrackedNutrient.defaultSelectionRaw)
    }

    @Test("Normalizing is stable: running it again changes nothing")
    func normalizingIsStable() {
        let once = OnboardingNutrientSelection(rawValue: TrackedNutrient.rawSelection(from: [.sugars]))
            .normalizedRawValue

        #expect(OnboardingNutrientSelection(rawValue: once).normalizedRawValue == once)
    }

    @Test("Unrecognised stored ids are dropped rather than carried forward")
    func unknownIdsAreDropped() {
        let selection = OnboardingNutrientSelection(rawValue: "protein,carbs,fat,unicorn")

        #expect(selection.normalizedRawValue == TrackedNutrient.defaultSelectionRaw)
    }

    // MARK: - Toggling extras

    @Test("Toggling an unselected extra adds it")
    func togglingAddsAnExtra() {
        let selection = OnboardingNutrientSelection(rawValue: TrackedNutrient.defaultSelectionRaw)

        let updated = OnboardingNutrientSelection(rawValue: selection.toggling(.fiber))

        #expect(updated.isSelected(.fiber))
        #expect(updated.extras == [.fiber])
    }

    @Test("Toggling a selected extra removes it")
    func togglingRemovesAnExtra() {
        let selection = OnboardingNutrientSelection(rawValue: TrackedNutrient.defaultSelectionRaw)
        let withFiber = OnboardingNutrientSelection(rawValue: selection.toggling(.fiber))

        let updated = OnboardingNutrientSelection(rawValue: withFiber.toggling(.fiber))

        #expect(!updated.isSelected(.fiber))
        #expect(updated.extras.isEmpty)
    }

    @Test("Toggling an extra twice returns the selection it started from")
    func togglingTwiceIsIdentity() {
        let start = OnboardingNutrientSelection(rawValue: TrackedNutrient.defaultSelectionRaw).normalizedRawValue

        let once = OnboardingNutrientSelection(rawValue: start).toggling(.sodium)
        let twice = OnboardingNutrientSelection(rawValue: once).toggling(.sodium)

        #expect(twice == start)
    }

    @Test("Extras keep the order they were picked in")
    func extrasKeepPickOrder() {
        var raw = TrackedNutrient.defaultSelectionRaw
        for nutrient in [TrackedNutrient.sodium, .fiber, .alcohol] {
            raw = OnboardingNutrientSelection(rawValue: raw).toggling(nutrient)
        }

        #expect(OnboardingNutrientSelection(rawValue: raw).extras == [.sodium, .fiber, .alcohol])
    }

    @Test("Removing one extra leaves the others where they were")
    func removingOneExtraKeepsTheRest() {
        var raw = TrackedNutrient.defaultSelectionRaw
        for nutrient in [TrackedNutrient.sodium, .fiber, .alcohol] {
            raw = OnboardingNutrientSelection(rawValue: raw).toggling(nutrient)
        }

        raw = OnboardingNutrientSelection(rawValue: raw).toggling(.fiber)

        #expect(OnboardingNutrientSelection(rawValue: raw).extras == [.sodium, .alcohol])
    }

    @Test("Toggling never drops a core macro", arguments: TrackedNutrient.editableGoalNutrients)
    func togglingNeverDropsACoreMacro(nutrient: TrackedNutrient) {
        let updated = OnboardingNutrientSelection(
            rawValue: OnboardingNutrientSelection(rawValue: TrackedNutrient.defaultSelectionRaw)
                .toggling(nutrient)
        )

        for macro in TrackedNutrient.defaultSelection {
            #expect(updated.isSelected(macro))
        }
    }

    @Test("Every optional nutrient can be selected and then deselected", arguments: TrackedNutrient.editableGoalNutrients)
    func everyOptionalNutrientRoundTrips(nutrient: TrackedNutrient) {
        let start = TrackedNutrient.defaultSelectionRaw

        let selected = OnboardingNutrientSelection(rawValue: start).toggling(nutrient)
        #expect(OnboardingNutrientSelection(rawValue: selected).isSelected(nutrient))

        let deselected = OnboardingNutrientSelection(rawValue: selected).toggling(nutrient)
        #expect(deselected == start)
    }

    @Test("Selecting every optional nutrient keeps them all")
    func allOptionalNutrientsCanBeSelected() {
        var raw = TrackedNutrient.defaultSelectionRaw
        for nutrient in TrackedNutrient.editableGoalNutrients {
            raw = OnboardingNutrientSelection(rawValue: raw).toggling(nutrient)
        }

        #expect(OnboardingNutrientSelection(rawValue: raw).extras == TrackedNutrient.editableGoalNutrients)
    }
}
