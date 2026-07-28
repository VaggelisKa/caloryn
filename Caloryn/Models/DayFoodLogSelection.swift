import Foundation

/// Which of the log's entries belong to the day on screen, and in what order.
///
/// The rules are generic over the entry so they can be exercised without a
/// SwiftData store: each one takes the facts it needs — a date, a meal, a
/// creation time — as accessors rather than reaching into a `FoodLogEntry`.
enum DayFoodLogSelection {
    /// The meals that always have a section, whether or not anything is in them.
    /// Snacks are shown separately because they carry a slot number.
    static let coreMeals: [MealType] = [.breakfast, .lunch, .dinner]

    /// Everything logged on the given day.
    ///
    /// Matched by calendar day rather than by a range, so a day is still its own
    /// day across a daylight-saving change.
    static func entries<Entry>(
        _ entries: [Entry],
        on day: Date,
        calendar: Calendar = .current,
        date: (Entry) -> Date
    ) -> [Entry] {
        entries.filter { calendar.isDate(date($0), inSameDayAs: day) }
    }

    /// One meal's entries, oldest first, so a section keeps the order things
    /// were added in rather than reshuffling when a portion is edited.
    static func entries<Entry>(
        _ entries: [Entry],
        inMeal meal: MealType,
        mealType: (Entry) -> MealType,
        createdAt: (Entry) -> Date
    ) -> [Entry] {
        entries
            .filter { mealType($0) == meal }
            .sorted { createdAt($0) < createdAt($1) }
    }

    /// Yesterday's log in the order it should be re-created: meal by meal down
    /// the day, and within a meal oldest first. Copying in query order would
    /// interleave breakfast and dinner in the new day's timestamps.
    static func copyOrdered<Entry>(
        _ entries: [Entry],
        mealType: (Entry) -> MealType,
        createdAt: (Entry) -> Date
    ) -> [Entry] {
        entries.sorted { lhs, rhs in
            let lhsOrder = mealType(lhs).sortOrder
            let rhsOrder = mealType(rhs).sortOrder
            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }
            return createdAt(lhs) < createdAt(rhs)
        }
    }

    /// Copying yesterday is offered only into an empty day, so it can never
    /// silently double up a day that has already been logged.
    static func canCopyYesterday(loggedTodayCount: Int, loggedYesterdayCount: Int) -> Bool {
        loggedTodayCount == 0 && loggedYesterdayCount > 0
    }
}
