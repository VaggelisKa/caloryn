import Foundation

struct HistoryDetailSelection: Equatable {
    enum Detail: Equatable {
        case calorieTrend
        case recurringPattern
    }

    enum Pane: Hashable {
        case calorieTrend(HistoryRange)
        case recurringPattern
        case empty

        var detail: Detail? {
            switch self {
            case .calorieTrend: .calorieTrend
            case .recurringPattern: .recurringPattern
            case .empty: nil
            }
        }
    }

    private(set) var chosen: Detail?

    mutating func choose(_ detail: Detail) {
        chosen = detail
    }

    func pane(
        range: HistoryRange,
        canDrillIntoCalorieTrend: Bool,
        hasRecurringPattern: Bool
    ) -> Pane {
        func isAvailable(_ detail: Detail) -> Bool {
            switch detail {
            case .calorieTrend: canDrillIntoCalorieTrend
            case .recurringPattern: hasRecurringPattern
            }
        }

        let preferenceOrder: [Detail] = [chosen, .calorieTrend, .recurringPattern].compactMap { $0 }
        switch preferenceOrder.first(where: isAvailable) {
        case .calorieTrend: return .calorieTrend(range)
        case .recurringPattern: return .recurringPattern
        case nil: return .empty
        }
    }
}
