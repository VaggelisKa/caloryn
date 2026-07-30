import Foundation

/// The range a whole-number calorie figure is allowed to occupy.
///
/// `Double.truncatedSafely` stops `Int(_:)` terminating the process, but it
/// clamps to `Int.min` / `Int.max` — and the *next* integer operation on such
/// a value traps in turn, so the crash moves one step downstream rather than
/// going away. `target - Int.min` overflows, `abs(Int.min)` overflows, and a
/// month of `Int.max` targets summed overflows.
///
/// Clamping at the conversion is what actually removes the trap: the bound is
/// absurd as a calorie figure — a billion kcal is several thousand lifetimes
/// of eating — yet small enough that everything done with these numbers stays
/// far inside `Int`. Two bounded figures can be subtracted, negated, doubled
/// and summed over a year of days without overflowing.
///
/// It also fails better. `Int.max` renders as a nineteen-digit number that
/// reads like a real total; a billion reads as obviously wrong.
enum CalorieDomain {
    static let maximum = 1_000_000_000
    static let minimum = -1_000_000_000

    static func clamped(_ value: Int) -> Int {
        min(max(value, minimum), maximum)
    }
}

extension Double {
    /// Rounds a calorie figure to a whole number inside `CalorieDomain`.
    ///
    /// Use this rather than `truncatedSafely` wherever the result is used as a
    /// number — subtracted from a target, summed across days, passed to `abs`.
    /// `truncatedSafely` remains correct for a value that is only ever turned
    /// straight into text.
    var roundedCalories: Int {
        CalorieDomain.clamped(rounded().truncatedSafely)
    }
}
