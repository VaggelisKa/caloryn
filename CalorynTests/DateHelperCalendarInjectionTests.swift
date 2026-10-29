import Testing
import Foundation
@testable import Caloryn

struct DateHelperCalendarInjectionTests {
    private static func calendar(
        _ timeZone: String,
        identifier: Calendar.Identifier = .gregorian,
        locale: String = "en_US_POSIX",
        firstWeekday: Int? = nil
    ) -> Calendar {
        var cal = Calendar(identifier: identifier)
        cal.timeZone = TimeZone(identifier: timeZone)!
        cal.locale = Locale(identifier: locale)
        if let firstWeekday { cal.firstWeekday = firstWeekday }
        return cal
    }

    private static func instant(
        utcYear year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.timeZone = TimeZone(identifier: "UTC")!
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private static let utc = calendar("UTC")
    private static let kolkata = calendar("Asia/Kolkata")
    private static let losAngeles = calendar("America/Los_Angeles")

    @Test("startOfDay resolves one instant to two different days when the injected zone straddles midnight")
    func startOfDayFollowsTheInjectedTimeZoneAcrossMidnight() {
        let newYearsEve = Self.instant(utcYear: 2025, month: 12, day: 31, hour: 23, minute: 45)

        let inUTC = newYearsEve.startOfDay(in: Self.utc)
        let inKolkata = newYearsEve.startOfDay(in: Self.kolkata)

        #expect(inUTC == Self.instant(utcYear: 2025, month: 12, day: 31))
        #expect(inKolkata == Self.instant(utcYear: 2025, month: 12, day: 31, hour: 18, minute: 30))
        #expect(inUTC != inKolkata)
    }

    @Test("daysFrom counts a day boundary the injected zone has crossed and the host's has not")
    func daysFromFollowsTheInjectedTimeZone() {
        let lateEvening = Self.instant(utcYear: 2026, month: 6, day: 15, hour: 23)
        let nextMorning = Self.instant(utcYear: 2026, month: 6, day: 16, hour: 3)

        #expect(nextMorning.daysFrom(lateEvening, in: Self.utc) == 1)
        #expect(nextMorning.daysFrom(lateEvening, in: Self.losAngeles) == 0)
        #expect(nextMorning.daysFrom(lateEvening, in: Self.kolkata) == 0)
    }

    @Test("daysFrom stays antisymmetric under a foreign calendar")
    func daysFromIsAntisymmetricUnderAForeignCalendar() {
        let earlier = Self.instant(utcYear: 2025, month: 11, day: 2, hour: 8)
        let later = Self.instant(utcYear: 2026, month: 3, day: 9, hour: 21)

        #expect(later.daysFrom(earlier, in: Self.kolkata) == -(earlier.daysFrom(later, in: Self.kolkata)))
        #expect(later.daysFrom(earlier, in: Self.kolkata) > 0)
    }

    @Test("datesInRange walks back through the injected zone's midnights, not the host's")
    func datesInRangeUsesTheInjectedZonesMidnights() {
        let instant = Self.instant(utcYear: 2026, month: 1, day: 2, hour: 12)
        let dates = Date.datesInRange(from: instant, days: 3, in: Self.kolkata)

        #expect(dates == [
            Self.instant(utcYear: 2026, month: 1, day: 1, hour: 18, minute: 30),
            Self.instant(utcYear: 2025, month: 12, day: 31, hour: 18, minute: 30),
            Self.instant(utcYear: 2025, month: 12, day: 30, hour: 18, minute: 30),
        ])
    }

    @Test("tomorrow and yesterday step by the injected zone's day, keeping the local wall clock")
    func tomorrowAndYesterdayStepInTheInjectedZone() {
        let noonInKolkata = Self.instant(utcYear: 2026, month: 6, day: 15, hour: 6, minute: 30)

        let next = noonInKolkata.tomorrow(in: Self.kolkata)
        let previous = noonInKolkata.yesterday(in: Self.kolkata)

        #expect(Self.kolkata.component(.hour, from: next) == 12)
        #expect(Self.kolkata.component(.day, from: next) == 16)
        #expect(Self.kolkata.component(.day, from: previous) == 14)
    }

    @Test(
        "shortFormatted labels the second after the injected zone's midnight as Today",
        arguments: ["UTC", "Asia/Kolkata", "America/Los_Angeles", "Pacific/Kiritimati"]
    )
    func shortFormattedSaysTodayJustAfterTheInjectedZonesMidnight(timeZone: String) {
        let cal = Self.calendar(timeZone)
        let justAfterMidnight = cal.startOfDay(for: .now).addingTimeInterval(1)
        #expect(justAfterMidnight.shortFormatted(in: cal) == "Today")
        #expect(justAfterMidnight.isToday(in: cal))
    }

    @Test(
        "shortFormatted labels the second before the injected zone's midnight as Yesterday",
        arguments: ["UTC", "Asia/Kolkata", "America/Los_Angeles", "Pacific/Kiritimati"]
    )
    func shortFormattedSaysYesterdayJustBeforeTheInjectedZonesMidnight(timeZone: String) {
        let cal = Self.calendar(timeZone)
        let justBeforeMidnight = cal.startOfDay(for: .now).addingTimeInterval(-1)
        #expect(justBeforeMidnight.shortFormatted(in: cal) == "Yesterday")
        #expect(!justBeforeMidnight.isToday(in: cal))
    }

    @Test("isAtFutureLogLimit counts the seven days in the injected zone")
    func isAtFutureLogLimitCountsInTheInjectedZone() {
        let now = Self.instant(utcYear: 2026, month: 6, day: 15, hour: 12)
        let sixDaysOut = Self.instant(utcYear: 2026, month: 6, day: 21, hour: 12)
        let sevenDaysOut = Self.instant(utcYear: 2026, month: 6, day: 22, hour: 12)

        #expect(!sixDaysOut.isAtFutureLogLimit(from: now, in: Self.utc))
        #expect(sevenDaysOut.isAtFutureLogLimit(from: now, in: Self.utc))
    }

    @Test(
        "startOfWeek stays Monday-based even when the calendar's own week starts on another day",
        arguments: [1, 2, 6, 7]
    )
    func startOfWeekIgnoresTheCalendarsFirstWeekday(firstWeekday: Int) {
        let cal = Self.calendar("UTC", firstWeekday: firstWeekday)
        let sunday = Self.instant(utcYear: 2026, month: 1, day: 4, hour: 15)

        #expect(sunday.startOfWeek(in: cal) == Self.instant(utcYear: 2025, month: 12, day: 29))
    }

    @Test("startOfWeek anchors on the injected zone's Monday midnight, not the host's")
    func startOfWeekUsesTheInjectedZonesMidnight() {
        let wednesday = Self.instant(utcYear: 2026, month: 1, day: 7, hour: 12)

        #expect(wednesday.startOfWeek(in: Self.utc) == Self.instant(utcYear: 2026, month: 1, day: 5))
        #expect(
            wednesday.startOfWeek(in: Self.kolkata)
                == Self.instant(utcYear: 2026, month: 1, day: 4, hour: 18, minute: 30)
        )
    }

    @Test("datesForCurrentWeek returns the seven days of the injected calendar's Mon-Sun week")
    func datesForCurrentWeekReturnsSevenConsecutiveDaysFromMonday() {
        let thursday = Self.instant(utcYear: 2026, month: 1, day: 8, hour: 9)
        let week = Date.datesForCurrentWeek(from: thursday, in: Self.utc)

        #expect(week.count == 7)
        #expect(week.first == Self.instant(utcYear: 2026, month: 1, day: 5))
        #expect(week.last == Self.instant(utcYear: 2026, month: 1, day: 11))
        #expect(week == week.sorted())
        #expect(week.allSatisfy { $0 == $0.startOfDay(in: Self.utc) })
    }

    @Test("a week-start override cannot make startOfWeek disagree with itself: it stays idempotent")
    func startOfWeekIsIdempotentUnderAnOverriddenFirstWeekday() {
        let cal = Self.calendar("Asia/Kolkata", firstWeekday: 7)
        let friday = Self.instant(utcYear: 2026, month: 3, day: 13, hour: 4)
        let monday = friday.startOfWeek(in: cal)

        #expect(monday.startOfWeek(in: cal) == monday)
    }

    @Test("weekdayInitial names the weekday of the injected zone's day")
    func weekdayInitialFollowsTheInjectedZone() {
        let mondayEvening = Self.instant(utcYear: 2026, month: 1, day: 5, hour: 22)

        #expect(mondayEvening.weekdayInitial(in: Self.utc) == "M")
        #expect(mondayEvening.weekdayInitial(in: Self.kolkata) == "T")
        #expect(mondayEvening.weekdayInitial(in: Self.losAngeles) == "M")
    }

    @Test(
        "weekdayInitial walks S M T W T F S across a Sunday-to-Saturday week",
        arguments: Array(zip(4...10, ["S", "M", "T", "W", "T", "F", "S"]))
    )
    func weekdayInitialWalksTheWholeWeek(day: Int, expected: String) {
        let date = Self.instant(utcYear: 2026, month: 1, day: day, hour: 12)
        #expect(date.weekdayInitial(in: Self.utc) == expected)
    }

    @Test("weekdayInitial is unaffected by the calendar's first weekday, which only reorders a displayed week")
    func weekdayInitialIgnoresFirstWeekday() {
        let sundayStart = Self.calendar("UTC", firstWeekday: 1)
        let saturdayStart = Self.calendar("UTC", firstWeekday: 7)
        let wednesday = Self.instant(utcYear: 2026, month: 1, day: 7, hour: 12)

        #expect(wednesday.weekdayInitial(in: sundayStart) == "W")
        #expect(wednesday.weekdayInitial(in: saturdayStart) == "W")
    }

    @Test("dayMonthFormatted renumbers and renames the day under a non-Gregorian calendar")
    func dayMonthFormattedUsesANonGregorianCalendar() {
        var islamic = Calendar(identifier: .islamicUmmAlQura)
        islamic.timeZone = TimeZone(identifier: "UTC")!
        islamic.locale = Locale(identifier: "en_US_POSIX")

        let date = Self.instant(utcYear: 2026, month: 6, day: 15, hour: 12)

        let islamicDay = islamic.component(.day, from: date)
        #expect(date.dayMonthFormatted(in: islamic).hasPrefix("\(islamicDay)"))
        #expect(date.dayMonthFormatted(in: islamic) != date.dayMonthFormatted(in: Self.utc))
        #expect(date.dayMonthFormatted(in: Self.utc) == "15 Jun")
    }

    @Test("shortWeekday and shortFormatted render in the injected calendar's locale")
    func formattingUsesTheInjectedLocale() {
        let french = Self.calendar("UTC", locale: "fr_FR")
        let english = Self.calendar("UTC", locale: "en_US_POSIX")
        let monday = Self.instant(utcYear: 2026, month: 1, day: 5, hour: 12)

        #expect(monday.shortWeekday(in: english) == "Mon")
        #expect(monday.shortWeekday(in: french) == "lun.")
        #expect(monday.shortFormatted(in: english) == "Mon, 5 Jan")
        #expect(monday.shortFormatted(in: french).hasPrefix("lun."))
    }

    @Test("the day named by dayMonthFormatted is the day the date lands on in that zone")
    func dayMonthFormattedFollowsTheInjectedZone() {
        let evening = Self.instant(utcYear: 2026, month: 6, day: 15, hour: 20)
        let kolkataEnglish = Self.calendar("Asia/Kolkata")
        let losAngelesEnglish = Self.calendar("America/Los_Angeles")

        #expect(evening.dayMonthFormatted(in: kolkataEnglish) == "16 Jun")
        #expect(evening.dayMonthFormatted(in: losAngelesEnglish) == "15 Jun")
    }
}

@MainActor
struct HistoryCalendarInjectionTests {
    private func calendar(_ timeZone: String) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZone)!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }

    private func date(utcYear year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.timeZone = TimeZone(identifier: "UTC")!
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test("a weekly rollup buckets days by the analytics calendar's Monday, not the host's")
    func weeklyRollupsUseTheInjectedCalendar() {
        let cal = calendar("Asia/Kolkata")
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .month,
            endDate: date(utcYear: 2026, month: 1, day: 8),
            calendar: cal
        )

        for week in analytics.current.weeklyRollups {
            #expect(cal.component(.weekday, from: week.startDate) == 2)
            #expect(week.startDate == cal.startOfDay(for: week.startDate))
        }
    }

    @Test("the trend chart labels each day with the weekday it has in the analytics calendar")
    func trendPointLabelsUseTheAnalyticsCalendar() {
        let cal = calendar("UTC")
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: date(utcYear: 2026, month: 1, day: 10),
            calendar: cal
        )
        let discovery = HistoryPatternDiscovery(analytics: analytics, today: date(utcYear: 2026, month: 1, day: 10))
        let labels = discovery.calorieTrend.points.map(\.xAxisLabel)

        #expect(labels == ["S", "M", "T", "W", "T", "F", "S"])
    }

    @Test("a trend point's label and its accessibility description name the same day")
    func trendPointLabelAndAccessibilityLabelAgreeUnderAForeignZone() {
        let cal = calendar("Pacific/Kiritimati")
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: date(utcYear: 2026, month: 1, day: 10),
            calendar: cal
        )
        let discovery = HistoryPatternDiscovery(analytics: analytics, today: date(utcYear: 2026, month: 1, day: 10))

        for (point, day) in zip(discovery.calorieTrend.points, analytics.current.days) {
            #expect(point.xAxisLabel == day.date.weekdayInitial(in: cal))
            #expect(point.accessibilityLabel == day.date.shortFormatted(in: cal))
        }
    }

    @Test("a summary rebuilt into the detail projection keeps the calendar it was derived under")
    func detailProjectionRebuiltFromASummaryKeepsItsCalendar() {
        let cal = calendar("Pacific/Kiritimati")
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .week,
            endDate: date(utcYear: 2026, month: 1, day: 10),
            calendar: cal
        )

        let projection = HistoryCalorieTrendProjection(
            range: analytics.range,
            summary: analytics.current,
            today: date(utcYear: 2026, month: 1, day: 10)
        )

        for (point, day) in zip(projection.points, analytics.current.days) {
            #expect(point.xAxisLabel == day.date.weekdayInitial(in: cal))
            #expect(point.accessibilityLabel == day.date.shortFormatted(in: cal))
            #expect(projection.dayText(for: day.date) == day.date.formatted(pattern: "EEE d MMM", in: cal))
        }

        #expect(projection.points.map(\.xAxisLabel) == ["M", "T", "W", "T", "F", "S", "S"])
    }

    @Test("the detail projection's week labels name the week its rollups were bucketed into")
    func detailProjectionWeekLabelsUseTheSummaryCalendar() {
        let cal = calendar("Pacific/Kiritimati")
        let analytics = HistoryAnalytics(
            entries: [],
            profile: nil,
            range: .quarter,
            endDate: date(utcYear: 2026, month: 1, day: 10),
            calendar: cal
        )
        let projection = HistoryCalorieTrendProjection(
            range: analytics.range,
            summary: analytics.current,
            today: date(utcYear: 2026, month: 1, day: 10)
        )

        for (point, week) in zip(projection.points, analytics.current.weeklyRollups) {
            #expect(point.accessibilityLabel.hasSuffix(week.startDate.dayMonthFormatted(in: cal)))
            #expect(projection.weekStartText(for: week.startDate)
                == week.startDate.dayMonthFormatted(in: cal))
        }
    }

    @Test("a recurring pattern labels its supporting days in the calendar it was discovered under")
    func recurringPatternDayLabelsUseItsDiscoveryCalendar() {
        let cal = calendar("Pacific/Kiritimati")
        let now = date(utcYear: 2026, month: 2, day: 2)
        let entries = Self.recurringDinnerEntries(now: now, calendar: cal)
        let resolver = HistoryDayTargetResolver(
            fallbackTarget: 2_000,
            valuesByDayKey: Self.savedTargets(now: now, calendar: cal)
        )

        guard let pattern = HistoryRecurringCaloriePatternEngine().discover(
            entries: entries,
            targetResolver: resolver,
            now: now,
            calendar: cal
        ) else {
            Issue.record("expected a recurring pattern from the seeded window")
            return
        }

        for day in pattern.supportingDays {
            #expect(pattern.dayText(for: day.date) == day.date.shortFormatted(in: cal))
        }
    }

    private static func savedTargets(
        now: Date,
        calendar: Calendar
    ) -> [String: DailyGoalSnapshotValues] {
        var values: [String: DailyGoalSnapshotValues] = [:]
        for offset in 1...31 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            values[DailyGoalSnapshot.dayKey(for: day, calendar: calendar)] = DailyGoalSnapshotValues(
                calorieTarget: 2_000,
                isManualTarget: false
            )
        }
        return values
    }

    private static func recurringDinnerEntries(
        now: Date,
        calendar: Calendar
    ) -> [FoodLogEntry] {
        var entries: [FoodLogEntry] = []
        for offset in 1...30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let noon = calendar.date(
                bySettingHour: 12,
                minute: 0,
                second: 0,
                of: calendar.startOfDay(for: day)
            ) ?? day
            let isMonday = calendar.component(.weekday, from: day) == 2

            entries.append(
                makeTestEntry(
                    date: noon,
                    mealType: .lunch,
                    foodItem: makeTestFoodItem(
                        name: "Lunch plate",
                        caloriesPer100g: 1_400,
                        proteinPer100g: 0,
                        carbsPer100g: 0,
                        fatPer100g: 0
                    ),
                    portionGrams: 100
                )
            )
            entries.append(
                makeTestEntry(
                    date: noon,
                    mealType: .dinner,
                    foodItem: makeTestFoodItem(
                        name: "Dinner plate",
                        caloriesPer100g: isMonday ? 1_600 : 600,
                        proteinPer100g: 0,
                        carbsPer100g: 0,
                        fatPer100g: 0
                    ),
                    portionGrams: 100
                )
            )
        }
        return entries
    }
}
