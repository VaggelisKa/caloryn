import Foundation
import Testing
@testable import Caloryn

/// The full policy matrix of `FoodSearchMode`.
///
/// These flags gate what the food search screen lets a user do — whether
/// recipes are offered, whether several rows can be ticked, whether a manual
/// entry can be created — so each mode's answer to each of them is pinned here
/// rather than inferred from the view.
@MainActor
struct FoodSearchModeTests {

    private static let logging = FoodSearchMode.logging
    private static let ingredient = FoodSearchMode.ingredientSelection { _ in }
    private static let mealComponent = FoodSearchMode.mealComponentSelection { _ in }

    private static let allModes: [(name: String, mode: FoodSearchMode)] = [
        ("logging", logging),
        ("ingredientSelection", ingredient),
        ("mealComponentSelection", mealComponent),
    ]

    // MARK: - The matrix

    @Test("Each mode titles the screen for the task that opened it")
    func titles() {
        #expect(Self.logging.title == "Add Food")
        #expect(Self.ingredient.title == "Add Ingredient")
        #expect(Self.mealComponent.title == "Add Meal Item")
    }

    @Test("Only the two hand-back modes are selection modes")
    func isSelection() {
        #expect(Self.logging.isSelection == false)
        #expect(Self.ingredient.isSelection)
        #expect(Self.mealComponent.isSelection)
    }

    @Test("Recipes are candidates everywhere except as recipe ingredients")
    func includesRecipes() {
        #expect(Self.logging.includesRecipes)
        #expect(Self.ingredient.includesRecipes == false)
        #expect(Self.mealComponent.includesRecipes)
    }

    @Test("Ingredient selection is the one mode with pinned section headings")
    func usesNonStickySectionTitles() {
        #expect(Self.logging.usesNonStickySectionTitles)
        #expect(Self.ingredient.usesNonStickySectionTitles == false)
        #expect(Self.mealComponent.usesNonStickySectionTitles)
    }

    @Test("Only ingredient selection offers to create a manual entry")
    func allowsManualEntryCreation() {
        #expect(Self.logging.allowsManualEntryCreation == false)
        #expect(Self.ingredient.allowsManualEntryCreation)
        #expect(Self.mealComponent.allowsManualEntryCreation == false)
    }

    @Test("Only logging can batch several rows; a caller wants one food back")
    func supportsMultiSelection() {
        #expect(Self.logging.supportsMultiSelection)
        #expect(Self.ingredient.supportsMultiSelection == false)
        #expect(Self.mealComponent.supportsMultiSelection == false)
    }

    @Test("Only ingredient selection reports itself as such")
    func isIngredientSelection() {
        #expect(Self.logging.isIngredientSelection == false)
        #expect(Self.ingredient.isIngredientSelection)
        #expect(Self.mealComponent.isIngredientSelection == false)
    }

    // MARK: - Cross-flag invariants

    @Test("The manual-entry control and the Select control are never both shown")
    func manualEntryAndMultiSelectionAreMutuallyExclusive() {
        for (name, mode) in Self.allModes {
            #expect(
                !(mode.allowsManualEntryCreation && mode.supportsMultiSelection),
                "\(name) offers both toolbar controls for one slot"
            )
        }
    }

    @Test("A mode that hands its result back never batches")
    func selectionModesAreSingleSelect() {
        for (name, mode) in Self.allModes where mode.isSelection {
            #expect(
                mode.supportsMultiSelection == false,
                "\(name) would batch a result its caller can only take one of"
            )
        }
    }

    // MARK: - The Select/Cancel control

    @Test("The Select control needs something to tick before it opens")
    func multiSelectionControlNeedsAnOption() {
        #expect(
            Self.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: false,
                selectableOptionCount: 0
            ) == false
        )
        #expect(
            Self.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: false,
                selectableOptionCount: 1
            )
        )
    }

    @Test("Cancel stays live with nothing selectable, so nobody is stranded")
    func multiSelectionControlStaysEnabledOnceActive() {
        #expect(
            Self.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: true,
                selectableOptionCount: 0
            )
        )
    }

    @Test("A mode without multi-selection never enables the control")
    func multiSelectionControlIsDeadInSelectionModes() {
        for (name, mode) in Self.allModes where !mode.supportsMultiSelection {
            for isSelectingMultiple in [true, false] {
                for count in [0, 1, 50] {
                    #expect(
                        mode.isMultiSelectionControlEnabled(
                            isSelectingMultiple: isSelectingMultiple,
                            selectableOptionCount: count
                        ) == false,
                        "\(name) enabled the control at \(count) options"
                    )
                }
            }
        }
    }

    @Test("A negative option count cannot enable the control")
    func negativeOptionCountDoesNotEnableTheControl() {
        #expect(
            Self.logging.isMultiSelectionControlEnabled(
                isSelectingMultiple: false,
                selectableOptionCount: -1
            ) == false
        )
    }

    // MARK: - The bridge the listing rules read

    @Test("FoodSearchListing.Mode takes the two facts filtering asks each mode")
    func listingModeMatchesTheSourceMode() {
        for (name, mode) in Self.allModes {
            let listingMode = FoodSearchListing.Mode(mode)
            #expect(
                listingMode.includesRecipes == mode.includesRecipes,
                "\(name) disagrees about recipes"
            )
            #expect(
                listingMode.supportsMultiSelection == mode.supportsMultiSelection,
                "\(name) disagrees about multi-selection"
            )
        }
    }
}
