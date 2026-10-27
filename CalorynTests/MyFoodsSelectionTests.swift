import Foundation
import Testing
@testable import Caloryn

@Suite("My Foods selection")
struct MyFoodsSelectionTests {
    private let first = UUID()
    private let second = UUID()
    private let third = UUID()

    private var order: [UUID] { [first, second, third] }

    @Test("With nothing chosen, the first food in list order is selected")
    func defaultsToFirst() {
        #expect(MyFoodsSelection().selectedID(in: order) == first)
    }

    @Test("With nothing to select, nothing is selected")
    func emptyLibrarySelectsNothing() {
        var selection = MyFoodsSelection()
        selection.settle(on: [])

        #expect(selection.selectedID(in: []) == nil)
    }

    @Test("A chosen food stays selected while it is still listed, wherever it moves")
    func choiceSurvivesReordering() {
        var selection = MyFoodsSelection()
        selection.select(second, in: order)
        let reordered = [second, third, first]
        selection.settle(on: reordered)

        #expect(selection.selectedID(in: reordered) == second)
    }

    @Test("Choosing a food that is not listed keeps the current selection")
    func unlistedChoiceIsIgnored() {
        var selection = MyFoodsSelection()
        selection.select(second, in: order)
        selection.select(UUID(), in: order)

        #expect(selection.selectedID(in: order) == second)
    }

    @Test("Deleting the selected food selects the one after it")
    func deletionFallsToNext() {
        var selection = MyFoodsSelection()
        selection.select(second, in: order)

        #expect(selection.selectedID(in: [first, third]) == third)
    }

    @Test("Deleting the last food while it is selected selects the one before it")
    func deletingLastFallsToPrevious() {
        var selection = MyFoodsSelection()
        selection.select(third, in: order)

        #expect(selection.selectedID(in: [first, second]) == second)
    }

    @Test("Deleting the selected food and its neighbour still lands on the next survivor")
    func deletionSkipsRemovedNeighbours() {
        var selection = MyFoodsSelection()
        selection.select(first, in: order)

        #expect(selection.selectedID(in: [third]) == third)
    }

    @Test("Deleting the last food in the library leaves nothing selected")
    func deletingEverythingSelectsNothing() {
        var selection = MyFoodsSelection()
        selection.select(first, in: [first])

        #expect(selection.selectedID(in: []) == nil)
    }

    @Test("The default selection sticks once settled, even when a new food is listed above it")
    func settledDefaultSticks() {
        var selection = MyFoodsSelection()
        selection.settle(on: order)
        let withNewFirst = [UUID()] + order

        #expect(selection.selectedID(in: withNewFirst) == first)
    }

    @Test("After a fallback settles, a later deletion falls back from the new selection")
    func fallbackSettlesForTheNextChange() {
        var selection = MyFoodsSelection()
        selection.select(first, in: order)
        selection.settle(on: [second, third])

        #expect(selection.selectedID(in: [third]) == third)
    }
}
