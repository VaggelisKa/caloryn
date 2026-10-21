import Foundation
import SwiftData
import Testing
@testable import Caloryn

@MainActor
struct FoodLogEntryWindowTests {
    private static let farEast = "Pacific/Kiritimati"
    private static let farWest = "Pacific/Pago_Pago"

    @Test(
        "Given entries either side of every nearby midnight, when the recent window is fetched, then today's entries, the widget snapshot and the reminder plan match the whole log",
        arguments: [
            ("Europe/Copenhagen", 2026, 3, 29, 12),
            ("Europe/Copenhagen", 2026, 10, 25, 23),
            ("Europe/Copenhagen", 2026, 7, 15, 0),
            ("America/Havana", 2026, 3, 8, 12)
        ]
    )
    func recentWindowKeepsToday(zone: String, year: Int, month: Int, day: Int, hour: Int) throws {
        let calendar = makeCalendar(zone)
        let now = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)))
        let context = try makeContext()
        try insertEntries(around: now, calendar: calendar, into: context)

        let everyEntry = try context.fetch(FetchDescriptor<FoodLogEntry>())
        let recent = try context.fetch(
            FetchDescriptor(predicate: FoodLogEntryWindow.loggedSince(
                FoodLogEntryWindow.recentStart(now: now, calendar: calendar)
            ))
        )
        let todayFromRecent = DayFoodLogSelection.entries(recent, on: now, calendar: calendar, date: \.date)
        let todayFromEveryEntry = DayFoodLogSelection.entries(everyEntry, on: now, calendar: calendar, date: \.date)
        let profile = makeProfile()

        #expect(recent.count < everyEntry.count)
        #expect(!todayFromEveryEntry.isEmpty)
        #expect(todayFromRecent.map(\.id) == todayFromEveryEntry.map(\.id))
        #expect(
            DailyWidgetSnapshotProjector.makeSnapshot(profile: profile, entries: recent, now: now, calendar: calendar)
                == DailyWidgetSnapshotProjector.makeSnapshot(profile: profile, entries: everyEntry, now: now, calendar: calendar)
        )
        #expect(reminderPlan(today: todayFromRecent, now: now, calendar: calendar)
            == reminderPlan(today: todayFromEveryEntry, now: now, calendar: calendar))
    }

    @Test(
        "Given the recent window was built a minute either side of midnight, when days pass and the time zone moves while the app stays open, then today's entries still match the whole log",
        arguments: [(24, 23, 59), (25, 0, 1)]
    )
    func recentWindowNeedsNoRollover(day: Int, hour: Int, minute: Int) throws {
        let calendar = makeCalendar("Europe/Copenhagen")
        let built = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)))
        let context = try makeContext()
        try insertEntries(around: built, calendar: calendar, into: context)

        let everyEntry = try context.fetch(FetchDescriptor<FoodLogEntry>())
        let recent = try context.fetch(
            FetchDescriptor(predicate: FoodLogEntryWindow.loggedSince(
                FoodLogEntryWindow.recentStart(now: built, calendar: calendar)
            ))
        )

        for later in [built.addingTimeInterval(120), built.addingTimeInterval(3_600), built.addingTimeInterval(3 * 86_400)] {
            for zone in ["Europe/Copenhagen", Self.farEast, Self.farWest] {
                let laterCalendar = makeCalendar(zone)
                let fromRecent = DayFoodLogSelection.entries(recent, on: later, calendar: laterCalendar, date: \.date)
                let fromEveryEntry = DayFoodLogSelection.entries(everyEntry, on: later, calendar: laterCalendar, date: \.date)

                #expect(!fromEveryEntry.isEmpty, "\(later) in \(zone) should see a logged day")
                #expect(fromRecent.map(\.id) == fromEveryEntry.map(\.id), "\(later) in \(zone)")
            }
        }
    }

    private func reminderPlan(today: [FoodLogEntry], now: Date, calendar: Calendar) -> [PlannedReminder] {
        let consumed = today.reduce(0) { $0 + $1.calories }
        return DailyReminderPlanner.makePlan(
            isEnabled: true,
            remainingToday: DailyReminderPlanner.remainingToday(target: 2_000, consumed: consumed),
            fullDayTarget: 2_000,
            now: now,
            calendar: calendar
        )
    }

    private func insertEntries(around now: Date, calendar: Calendar, into context: ModelContext) throws {
        let food = makeTestFoodItem(caloriesPer100g: 100)
        context.insert(food)
        let shiftedCalendars = [makeCalendar(Self.farEast), makeCalendar(Self.farWest)]
        let meals = MealType.allCases
        var index = 0

        for offset in -5...6 {
            let day = try #require(calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)))
            let dayStart = calendar.startOfDay(for: day)
            let instants = [dayStart.addingTimeInterval(-1), dayStart, dayStart.addingTimeInterval(1), dayStart.addingTimeInterval(12 * 3_600)]
                + shiftedCalendars.map { $0.startOfDay(for: day) }

            for instant in instants {
                let entry = makeTestEntry(
                    mealType: meals[index % meals.count],
                    foodItem: food,
                    portionGrams: Double(10 + index)
                )
                entry.date = instant
                entry.createdAt = now.addingTimeInterval(Double((index * 7) % 13) * 60 + Double(index))
                context.insert(entry)
                index += 1
            }
        }
        try context.save()
    }

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            dailyCalorieTarget: 2_000,
            manualOverride: true
        )
    }

    private func makeCalendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
        return calendar
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(
            try ModelContainer(
                for: UserProfile.self,
                FoodItem.self,
                FoodLogEntry.self,
                RecipeIngredient.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        )
    }
}
