import Foundation
import Testing
@testable import Caloryn

@MainActor
struct ChatbotPasteOfferTests {
    private func showsRow(
        _ offer: ChatbotPasteOffer,
        mode: FoodSearchMode = .logging,
        on screenContent: FoodSearchScreenContent = .recent,
        isSelectingMultiple: Bool = false,
        rejectedGeneration: Int? = nil
    ) -> Bool {
        offer.showsPasteRow(
            in: mode,
            on: screenContent,
            isSelectingMultiple: isSelectingMultiple,
            rejectedGeneration: rejectedGeneration
        )
    }

    private func checked(
        _ offer: ChatbotPasteOffer = ChatbotPasteOffer(),
        changeCount: Int,
        generation: Int = 1,
        foundLink: Bool
    ) -> ChatbotPasteOffer {
        var offer = offer
        _ = offer.beginCheck(changeCount: changeCount, generation: generation)
        offer.finishCheck(changeCount: changeCount, foundLink: foundLink)
        return offer
    }

    @Test("Nothing is offered before the pasteboard has been checked")
    func hiddenBeforeAnyCheck() {
        #expect(showsRow(ChatbotPasteOffer()) == false)
    }

    @Test("Nothing is offered while a check has not answered yet")
    func hiddenWhileCheckIsPending() {
        var offer = ChatbotPasteOffer()
        let began = offer.beginCheck(changeCount: 7, generation: 1)
        #expect(began)
        #expect(offer.foundLink == nil)
        #expect(showsRow(offer) == false)
    }

    @Test("Paste is offered when the check found a link and not when it found none")
    func followsTheCheck() {
        #expect(showsRow(checked(changeCount: 7, foundLink: true)))
        #expect(showsRow(checked(changeCount: 7, foundLink: false)) == false)
    }

    @Test("An unchanged pasteboard is not checked again and keeps its answer")
    func skipsAnUnchangedPasteboard() {
        var offer = checked(changeCount: 7, foundLink: true)
        let began = offer.beginCheck(changeCount: 7, generation: 2)
        #expect(began == false)
        #expect(offer.generation == 1)
        #expect(showsRow(offer))
    }

    @Test("A changed pasteboard hides the offer until its own check answers")
    func changedPasteboardHidesUntilAnswered() {
        var offer = checked(changeCount: 7, foundLink: true)
        let began = offer.beginCheck(changeCount: 8, generation: 1)
        #expect(began)
        #expect(showsRow(offer) == false, "The previous pasteboard's answer must not show for the new one")
        offer.finishCheck(changeCount: 8, foundLink: true)
        #expect(showsRow(offer))
    }

    @Test("An answer for a pasteboard that has since changed is ignored")
    func ignoresAStaleAnswer() {
        var offer = ChatbotPasteOffer()
        _ = offer.beginCheck(changeCount: 7, generation: 1)
        _ = offer.beginCheck(changeCount: 8, generation: 1)
        offer.finishCheck(changeCount: 7, foundLink: true)
        #expect(offer.foundLink == nil)
        #expect(showsRow(offer) == false)
        offer.finishCheck(changeCount: 8, foundLink: false)
        #expect(offer.foundLink == false)
    }

    @Test("A refused pasteboard stays hidden through changeCount drift within its generation")
    func refusalHoldsWithinItsGeneration() {
        let refused = checked(changeCount: 7, generation: 3, foundLink: true)
        #expect(showsRow(refused, rejectedGeneration: 3) == false)

        let drifted = checked(refused, changeCount: 11, generation: 3, foundLink: true)
        #expect(showsRow(drifted, rejectedGeneration: 3) == false, "A changeCount alone does not lift a refusal")
    }

    @Test("A refusal is lifted only by a check that began in a later generation")
    func refusalLiftsOnALaterGenerationsCheck() {
        var offer = checked(changeCount: 7, generation: 3, foundLink: true)

        let skipped = offer.beginCheck(changeCount: 7, generation: 4)
        #expect(skipped == false)
        #expect(showsRow(offer, rejectedGeneration: 3) == false, "An unchanged pasteboard stays refused")

        _ = offer.beginCheck(changeCount: 12, generation: 4)
        #expect(showsRow(offer, rejectedGeneration: 3) == false, "Hidden until the new check answers")
        offer.finishCheck(changeCount: 12, foundLink: true)
        #expect(showsRow(offer, rejectedGeneration: 3))
    }

    @Test("A link is still offered only while logging with the search idle and nothing being selected")
    func respectsTheScreen() {
        let offer = checked(changeCount: 7, foundLink: true)
        #expect(showsRow(offer, isSelectingMultiple: true) == false)
        #expect(showsRow(offer, mode: .ingredientSelection { _ in }) == false)
        #expect(showsRow(offer, mode: .mealComponentSelection { _ in }) == false)
        for content in FoodSearchScreenContent.allCases where content != .recent {
            #expect(showsRow(offer, on: content) == false, "Paste should give way to \(content)")
        }
    }
}
