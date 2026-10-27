import Foundation

struct MyFoodsSelection: Equatable {
    private var chosenID: UUID?
    private var knownOrder: [UUID] = []

    func selectedID(in order: [UUID]) -> UUID? {
        guard let chosenID else { return order.first }
        if order.contains(chosenID) { return chosenID }

        let remaining = Set(order)
        if let index = knownOrder.firstIndex(of: chosenID) {
            if let next = knownOrder[(index + 1)...].first(where: remaining.contains) {
                return next
            }
            if let previous = knownOrder[..<index].last(where: remaining.contains) {
                return previous
            }
        }
        return order.first
    }

    mutating func select(_ id: UUID, in order: [UUID]) {
        guard order.contains(id) else { return }
        chosenID = id
        knownOrder = order
    }

    mutating func settle(on order: [UUID]) {
        chosenID = selectedID(in: order)
        knownOrder = order
    }
}
