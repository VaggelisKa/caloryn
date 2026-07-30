import Foundation
import Testing
@testable import Caloryn

/// Which state the food search screen resolves to, and in what order.
///
/// The precedence is the rule: these tests fix which fact wins when several are
/// true at once, because that is what two nested `if`/`else if` chains in a
/// view used to decide silently.
struct FoodSearchScreenContentTests {

    private func content(
        isLookingUpBarcode: Bool = false,
        hasBarcodeLookupError: Bool = false,
        showingRecent: Bool = false,
        isSearching: Bool = false,
        hasSearchFailure: Bool = false,
        hasLocalMatches: Bool = false,
        hasProductSearchResults: Bool = false
    ) -> FoodSearchScreenContent {
        FoodSearchScreenContent.resolve(
            isLookingUpBarcode: isLookingUpBarcode,
            hasBarcodeLookupError: hasBarcodeLookupError,
            showingRecent: showingRecent,
            isSearching: isSearching,
            hasSearchFailure: hasSearchFailure,
            hasLocalMatches: hasLocalMatches,
            hasProductSearchResults: hasProductSearchResults
        )
    }

    // MARK: - The resting state

    @Test("An empty query with no barcode in flight rests on the recent list")
    func restsOnRecents() {
        #expect(content(showingRecent: true) == .recent)
    }

    @Test("The recent list stands even while a query is in flight behind it")
    func recentsOutrankAStaleSearch() {
        #expect(
            content(
                showingRecent: true,
                isSearching: true,
                hasSearchFailure: true
            ) == .recent
        )
    }

    // MARK: - Barcode precedence

    @Test("A barcode lookup covers the list, empty query or not")
    func barcodeLookupOutranksTheList() {
        #expect(content(isLookingUpBarcode: true) == .barcodeLookupProgress)
        #expect(
            content(isLookingUpBarcode: true, showingRecent: true)
                == .barcodeLookupProgress
        )
    }

    @Test("A failed barcode lookup outranks one still running")
    func barcodeFailureOutranksBarcodeProgress() {
        #expect(
            content(isLookingUpBarcode: true, hasBarcodeLookupError: true)
                == .barcodeLookupFailure
        )
    }

    @Test("A barcode failure outranks everything the query would have shown")
    func barcodeFailureOutranksResults() {
        #expect(
            content(
                hasBarcodeLookupError: true,
                showingRecent: true,
                hasLocalMatches: true,
                hasProductSearchResults: true
            ) == .barcodeLookupFailure
        )
    }

    // MARK: - Search states

    @Test("A query in flight with nothing local yet shows the spinner")
    func searchProgress() {
        #expect(content(isSearching: true) == .searchProgress)
    }

    @Test("A provider failure with nothing local shows the failure")
    func searchFailure() {
        #expect(content(hasSearchFailure: true) == .searchFailure)
    }

    @Test("A query that matched nothing anywhere shows No Results")
    func noResults() {
        #expect(content() == .noResults)
    }

    @Test("Anything found shows the list")
    func results() {
        #expect(content(hasLocalMatches: true) == .results)
        #expect(content(hasProductSearchResults: true) == .results)
    }

    // MARK: - Local matches beat the network

    @Test("A local match shows the list rather than the spinner")
    func localMatchesOutrankTheSpinner() {
        #expect(content(isSearching: true, hasLocalMatches: true) == .results)
    }

    @Test("A local match shows the list rather than the provider's failure")
    func localMatchesOutrankTheFailure() {
        #expect(content(hasSearchFailure: true, hasLocalMatches: true) == .results)
    }

    @Test("A local match is never No Results, even with no provider hits")
    func localMatchesAreNeverNoResults() {
        #expect(
            content(hasLocalMatches: true, hasProductSearchResults: false)
                == .results
        )
    }

    @Test("Provider hits alone do not suppress the spinner")
    func providerHitsDoNotSuppressTheSpinner() {
        #expect(
            content(isSearching: true, hasProductSearchResults: true)
                == .searchProgress
        )
    }

    // MARK: - Covering the search field

    @Test("Only the two barcode states cover the search field")
    func coversSearchField() {
        for state in FoodSearchScreenContent.allCases {
            let isBarcode = state == .barcodeLookupFailure
                || state == .barcodeLookupProgress
            #expect(
                state.coversSearchField == isBarcode,
                "\(state) disagreed about covering the search field"
            )
        }
    }

    // MARK: - Typing past a barcode failure

    @Test("A real query dismisses a barcode failure that yields to name search")
    func typingDismissesADismissibleFailure() {
        #expect(
            FoodSearchScreenContent.dismissesBarcodeFailure(
                forSearchText: "oats",
                errorDismissesOnNameSearch: true
            )
        )
    }

    @Test("Whitespace alone is not a search and dismisses nothing")
    func whitespaceDoesNotDismiss() {
        for text in ["", " ", "   ", "\n", " \n\t "] {
            #expect(
                FoodSearchScreenContent.dismissesBarcodeFailure(
                    forSearchText: text,
                    errorDismissesOnNameSearch: true
                ) == false,
                "\(text.debugDescription) counted as a search"
            )
        }
    }

    @Test("A failure that does not yield to name search survives typing")
    func nonDismissibleFailureSurvives() {
        #expect(
            FoodSearchScreenContent.dismissesBarcodeFailure(
                forSearchText: "oats",
                errorDismissesOnNameSearch: false
            ) == false
        )
    }

    @Test("Text either side of the trim still counts as a search")
    func surroundingWhitespaceIsTrimmedNotRejected() {
        #expect(
            FoodSearchScreenContent.dismissesBarcodeFailure(
                forSearchText: "  oats \n",
                errorDismissesOnNameSearch: true
            )
        )
    }
}

/// The copy the multi-add selection UI reads out.
struct MultiAddSelectionLabelsTests {

    @Test("The review button pluralises on the item count, not the group count")
    func reviewButtonTitlePluralises() {
        #expect(
            MultiAddSelectionLabels.reviewButtonTitle(selectedItemCount: 0)
                == "Review 0 Items"
        )
        #expect(
            MultiAddSelectionLabels.reviewButtonTitle(selectedItemCount: 1)
                == "Review 1 Item"
        )
        #expect(
            MultiAddSelectionLabels.reviewButtonTitle(selectedItemCount: 2)
                == "Review 2 Items"
        )
        #expect(
            MultiAddSelectionLabels.reviewButtonTitle(selectedItemCount: 21)
                == "Review 21 Items"
        )
    }

    @Test("Rows stay silent about selection while there are no checkboxes")
    func silentOutsideSelectionMode() {
        #expect(
            MultiAddSelectionLabels.selectionValue(
                isSelectingMultiple: false,
                isSelected: false
            ) == ""
        )
        #expect(
            MultiAddSelectionLabels.selectionValue(
                isSelectingMultiple: false,
                isSelected: true
            ) == ""
        )
    }

    @Test("In selection mode every row announces which way it is")
    func announcesBothStatesInSelectionMode() {
        #expect(
            MultiAddSelectionLabels.selectionValue(
                isSelectingMultiple: true,
                isSelected: true
            ) == "Selected"
        )
        #expect(
            MultiAddSelectionLabels.selectionValue(
                isSelectingMultiple: true,
                isSelected: false
            ) == "Not selected"
        )
    }
}
