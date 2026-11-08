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
        generation: Int = 1,
        foundLink: Bool
    ) -> ChatbotPasteOffer {
        var offer = offer
        let check = offer.beginCheck(generation: generation)
        offer.finishCheck(check, foundLink: foundLink)
        return offer
    }

    @Test("Nothing is offered before the pasteboard has been checked")
    func hiddenBeforeAnyCheck() {
        #expect(showsRow(ChatbotPasteOffer()) == false)
    }

    @Test("Nothing is offered while the first check has not answered yet")
    func hiddenWhileFirstCheckIsPending() {
        var offer = ChatbotPasteOffer()
        _ = offer.beginCheck(generation: 1)
        #expect(offer.foundLink == nil)
        #expect(showsRow(offer) == false)
    }

    @Test("Paste is offered when the check found a link and not when it found none")
    func followsTheCheck() {
        #expect(showsRow(checked(foundLink: true)))
        #expect(showsRow(checked(foundLink: false)) == false)
    }

    @Test("A re-check in the same generation is answered, so a link that arrived unnoticed is offered")
    func everyCheckIsAnswered() {
        let noLink = checked(generation: 1, foundLink: false)
        let relooked = checked(noLink, generation: 1, foundLink: true)
        #expect(showsRow(relooked), "The sheet must not keep a stale \"no link\" until the app relaunches")
    }

    @Test("Within a generation the previous answer stays up while a re-check runs")
    func keepsItsAnswerWhileRecheckingTheSameGeneration() {
        var offer = checked(generation: 1, foundLink: true)
        _ = offer.beginCheck(generation: 1)
        #expect(showsRow(offer))
    }

    @Test("A new generation hides the offer until its own check answers")
    func newGenerationHidesUntilAnswered() {
        var offer = checked(generation: 1, foundLink: true)
        let check = offer.beginCheck(generation: 2)
        #expect(showsRow(offer) == false, "The previous generation's answer must not show for the new one")
        offer.finishCheck(check, foundLink: true)
        #expect(showsRow(offer))
    }

    @Test("An answer from a check that has since been superseded is ignored")
    func ignoresASupersededAnswer() {
        var offer = ChatbotPasteOffer()
        let first = offer.beginCheck(generation: 1)
        let second = offer.beginCheck(generation: 1)
        offer.finishCheck(first, foundLink: true)
        #expect(offer.foundLink == nil)
        #expect(showsRow(offer) == false)
        offer.finishCheck(second, foundLink: false)
        #expect(offer.foundLink == false)
    }

    @Test("A refused pasteboard stays hidden through re-checks within its generation")
    func refusalHoldsWithinItsGeneration() {
        let refused = checked(generation: 3, foundLink: true)
        #expect(showsRow(refused, rejectedGeneration: 3) == false)

        let relooked = checked(refused, generation: 3, foundLink: true)
        #expect(showsRow(relooked, rejectedGeneration: 3) == false, "A re-check alone does not lift a refusal")
    }

    @Test("A refusal is lifted only by a check that began in a later generation")
    func refusalLiftsOnALaterGenerationsCheck() {
        var offer = checked(generation: 3, foundLink: true)

        let check = offer.beginCheck(generation: 4)
        #expect(showsRow(offer, rejectedGeneration: 3) == false, "Hidden until the new check answers")
        offer.finishCheck(check, foundLink: true)
        #expect(showsRow(offer, rejectedGeneration: 3))
    }

    @Test("A link is still offered only while logging with the search idle and nothing being selected")
    func respectsTheScreen() {
        let offer = checked(foundLink: true)
        #expect(showsRow(offer, isSelectingMultiple: true) == false)
        #expect(showsRow(offer, mode: .ingredientSelection { _ in }) == false)
        #expect(showsRow(offer, mode: .mealComponentSelection { _ in }) == false)
        for content in FoodSearchScreenContent.allCases where content != .recent {
            #expect(showsRow(offer, on: content) == false, "Paste should give way to \(content)")
        }
    }
}
