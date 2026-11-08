import Foundation

struct ChatbotPasteOffer: Equatable {
    private(set) var generation: Int?
    private(set) var foundLink: Bool?
    private var latestCheck = 0

    mutating func beginCheck(generation: Int) -> Int {
        latestCheck += 1
        if generation != self.generation {
            self.generation = generation
            foundLink = nil
        }
        return latestCheck
    }

    mutating func finishCheck(_ check: Int, foundLink: Bool) {
        guard check == latestCheck else { return }
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
