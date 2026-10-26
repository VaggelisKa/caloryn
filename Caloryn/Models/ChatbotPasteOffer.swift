import Foundation

struct ChatbotPasteOffer: Equatable {
    private(set) var changeCount: Int?
    private(set) var generation: Int?
    private(set) var foundLink: Bool?

    mutating func beginCheck(changeCount: Int, generation: Int) -> Bool {
        guard changeCount != self.changeCount else { return false }
        self.changeCount = changeCount
        self.generation = generation
        foundLink = nil
        return true
    }

    mutating func finishCheck(changeCount: Int, foundLink: Bool) {
        guard changeCount == self.changeCount else { return }
        self.foundLink = foundLink
    }

    func showsPasteRow(
        in mode: FoodSearchMode,
        on screenContent: FoodSearchScreenContent,
        isSelectingMultiple: Bool,
        rejectedGeneration: Int?
    ) -> Bool {
        mode.offersChatbotPaste(on: screenContent, isSelectingMultiple: isSelectingMultiple)
            && foundLink == true
            && generation != rejectedGeneration
    }
}
