#if DEBUG
import Foundation

enum UITestConfiguration {
    static let resetFlag = "-uitest-reset"

    static let seedFlag = "-uitest-seed"

    enum Fixture: String {
        case empty
        case profileOnly
        case loggedDay
        case loggedYesterday
        case customFoods
        case history
        case historyPattern
        case historyNoPattern
        case overBudgetDay
    }

    static var isActive: Bool {
        arguments.contains(resetFlag)
    }

    static var fixture: Fixture? {
        guard let flagIndex = arguments.firstIndex(of: seedFlag),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Fixture(rawValue: arguments[flagIndex + 1])
    }

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }
}
#endif
