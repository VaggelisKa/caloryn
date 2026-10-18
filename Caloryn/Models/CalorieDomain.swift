import Foundation

enum CalorieDomain {
    static let maximum = 1_000_000_000
    static let minimum = -1_000_000_000

    static func clamped(_ value: Int) -> Int {
        min(max(value, minimum), maximum)
    }
}

extension Double {
    var roundedCalories: Int {
        CalorieDomain.clamped(rounded().truncatedSafely)
    }
}
