import Foundation

struct DayFoodLogProjection<Entry> {
    let today: [Entry]
    let yesterday: [Entry]

    private let entriesByMeal: [MealType: [Entry]]

    init(
        _ entries: [Entry],
        on day: Date,
        calendar: Calendar = .current,
        date: (Entry) -> Date,
        mealType: (Entry) -> MealType,
        createdAt: (Entry) -> Date
    ) {
        let previousDay = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        var today: [Entry] = []
        var yesterday: [Entry] = []

        for entry in entries {
            let entryDate = date(entry)
            if calendar.isDate(entryDate, inSameDayAs: day) {
                today.append(entry)
            } else if calendar.isDate(entryDate, inSameDayAs: previousDay) {
                yesterday.append(entry)
            }
        }

        self.today = today
        self.yesterday = yesterday
        self.entriesByMeal = Dictionary(grouping: today, by: mealType)
            .mapValues { entries in
                entries.sorted { createdAt($0) < createdAt($1) }
            }
    }

    func entries(for meal: MealType) -> [Entry] {
        entriesByMeal[meal] ?? []
    }
}

enum DayFoodLogSelection {
    static let coreMeals: [MealType] = [.breakfast, .lunch, .dinner]

    static func entries<Entry>(
        _ entries: [Entry],
        on day: Date,
        calendar: Calendar = .current,
        date: (Entry) -> Date
    ) -> [Entry] {
        entries.filter { calendar.isDate(date($0), inSameDayAs: day) }
    }

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

    static func canCopyYesterday(loggedTodayCount: Int, loggedYesterdayCount: Int) -> Bool {
        loggedTodayCount == 0 && loggedYesterdayCount > 0
    }
}
