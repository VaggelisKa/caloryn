import Foundation
import Testing
@testable import Caloryn

/// Whether History's recompute key sees every live-food fact that a legacy (pre-snapshot)
/// entry still reads through its saved food.
@MainActor
@Suite("History refresh ID legacy coverage")
struct HistoryRefreshIDLegacyCoverageTests {

    @Test("given a legacy entry, when its saved food changes produce kind, then its signature changes so the produce count reruns")
    func aLegacyProduceKindChangeChangesTheSignature() {
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let legacy = makeLegacyTestEntry(foodItem: food, portionGrams: 120)
        let before = HistoryEntrySignature(entry: legacy)

        food.produceKind = .unclassified

        #expect(HistoryEntrySignature(entry: legacy) != before)
        #expect(ProduceVarietySummary(entries: [legacy]).totalCount == 0)
    }

    @Test("given a legacy entry, when its saved food is renamed, then the produce summary follows the new name while the signature stays the same")
    func aLegacyRenameIsReadByProduceButNotBySignature() {
        let banana = makeTestEntry(foodItem: makeTestFoodItem(name: "Banana", produceKind: .fruit), portionGrams: 100)
        let food = makeTestFoodItem(name: "Apple", produceKind: .fruit)
        let legacy = makeLegacyTestEntry(foodItem: food, portionGrams: 120)
        let before = HistoryEntrySignature(entry: legacy)
        #expect(ProduceVarietySummary(entries: [banana, legacy]).items.map(\.name) == ["Apple", "Banana"])

        food.name = "Banana"

        // The legacy produce path reads the live food's name, so the day now holds one kind.
        #expect(ProduceVarietySummary(entries: [banana, legacy]).items.map(\.name) == ["Banana"])
        // Current behaviour, suspected bug: the signature captures the stored name (historicalFoodName), not the live one the produce summary reads, so History keeps the stale count of two.
        #expect(HistoryEntrySignature(entry: legacy) == before)
    }
}
