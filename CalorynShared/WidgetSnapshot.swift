import Foundation

enum WidgetConstants {
    nonisolated static let appGroupIdentifier = "group.www.caloryn"
    nonisolated static let dailyProgressKind = "CalorynDailyProgress"
    nonisolated static let quickLogKind = "CalorynQuickLog"
    nonisolated static let snapshotFileName = "daily-widget-snapshot.json"
    nonisolated static let currentSchemaVersion = 1
}

enum DailyWidgetState: String, Codable, Hashable, Sendable {
    case needsOnboarding
    case ready
    case unavailable
}

struct WidgetMealCalories: Codable, Hashable, Sendable {
    let meal: WidgetMeal
    let kcal: Int
}

struct WidgetCalorieSummary: Codable, Hashable, Sendable {
    let consumed: Int
    let target: Int
    let meals: [WidgetMealCalories]

    init(
        consumed: Double,
        target: Int,
        mealCalories: [WidgetMeal: Double] = [:]
    ) {
        self.consumed = Self.clamped(consumed)
        self.target = max(1, target)
        self.meals = WidgetMeal.allCases.compactMap { meal in
            guard let kcal = mealCalories[meal] else { return nil }
            return WidgetMealCalories(meal: meal, kcal: Self.clamped(kcal))
        }
    }

    /// `Int(_:)` is a trap, not a conversion: NaN, an infinity or anything past `Int64`
    /// terminates the process, and `consumed` is a raw sum of logged calories.
    /// `Double.truncatedSafely` says the same thing, but it lives in the app target, which
    /// this shared file is compiled into the widget without — so the guard is spelled out
    /// here. Anything that is not a positive finite number floors at 0.
    private static func clamped(_ kcal: Double) -> Int {
        let rounded = kcal.rounded()
        if !rounded.isFinite || rounded <= 0 {
            return 0
        } else if rounded >= Double(Int.max) {
            return .max
        } else {
            return Int(rounded)
        }
    }

    var remaining: Int { max(0, target - consumed) }
    var overAmount: Int { max(0, consumed - target) }
    var progress: Double { min(max(Double(consumed) / Double(target), 0), 1) }

    var isOver: Bool {
        overAmount > 0
    }

    func kcal(for meal: WidgetMeal) -> Int? {
        meals.first { $0.meal == meal }?.kcal
    }

    // Hand-written so a snapshot saved before `meals` existed still decodes: the widget
    // reads it until the app next publishes, and a decode failure would show "Open
    // Caloryn" in its place.
    private enum CodingKeys: String, CodingKey {
        case consumed, target, meals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consumed = try container.decode(Int.self, forKey: .consumed)
        target = try container.decode(Int.self, forKey: .target)
        meals = try container.decodeIfPresent([WidgetMealCalories].self, forKey: .meals) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consumed, forKey: .consumed)
        try container.encode(target, forKey: .target)
        try container.encode(meals, forKey: .meals)
    }
}

struct DailyWidgetSnapshot: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let dayStart: Date
    let state: DailyWidgetState
    let calories: WidgetCalorieSummary

    init(
        generatedAt: Date,
        dayStart: Date,
        state: DailyWidgetState,
        calories: WidgetCalorieSummary,
        schemaVersion: Int = WidgetConstants.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.dayStart = dayStart
        self.state = state
        self.calories = calories
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, dayStart, state, calories, usesDynamicTarget
    }

    // Builds before the Apple Health auto-adjust was removed wrote `usesDynamicTarget`.
    // Such a snapshot's target carries an activity adjustment that no longer applies,
    // so it reads as unavailable until the app publishes a fresh one.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        dayStart = try container.decode(Date.self, forKey: .dayStart)
        calories = try container.decode(WidgetCalorieSummary.self, forKey: .calories)
        let decodedState = try container.decode(DailyWidgetState.self, forKey: .state)
        let usedDynamicTarget = try container.decodeIfPresent(Bool.self, forKey: .usesDynamicTarget) ?? false
        state = usedDynamicTarget ? .unavailable : decodedState
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(dayStart, forKey: .dayStart)
        try container.encode(state, forKey: .state)
        try container.encode(calories, forKey: .calories)
    }

    static func needsOnboarding(at date: Date, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        fixed(state: .needsOnboarding, consumed: 0, at: date, calendar: calendar)
    }

    static func placeholder(at date: Date = .now, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        fixed(
            state: .ready,
            consumed: 1_258,
            mealCalories: [.breakfast: 382, .lunch: 526, .snack: 350],
            at: date,
            calendar: calendar
        )
    }

    static func unavailable(at date: Date, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        fixed(state: .unavailable, consumed: 0, at: date, calendar: calendar)
    }

    private static func fixed(
        state: DailyWidgetState,
        consumed: Double,
        mealCalories: [WidgetMeal: Double] = [:],
        at date: Date,
        calendar: Calendar
    ) -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            generatedAt: date,
            dayStart: calendar.startOfDay(for: date),
            state: state,
            calories: WidgetCalorieSummary(
                consumed: consumed,
                target: 2_000,
                mealCalories: mealCalories
            )
        )
    }

    struct RenderIdentity: Hashable, Sendable {
        let schemaVersion: Int
        let dayStart: Date
        let state: DailyWidgetState
        let calories: WidgetCalorieSummary
    }

    var renderIdentity: RenderIdentity {
        RenderIdentity(
            schemaVersion: schemaVersion,
            dayStart: dayStart,
            state: state,
            calories: calories
        )
    }

    func hasSameRenderableContent(as other: DailyWidgetSnapshot) -> Bool {
        renderIdentity == other.renderIdentity
    }

    func displaySnapshot(at date: Date, calendar: Calendar = .current) -> (snapshot: DailyWidgetSnapshot, isStale: Bool) {
        guard state == .ready else { return (self, false) }

        let requestedDay = calendar.startOfDay(for: date)
        guard !calendar.isDate(dayStart, inSameDayAs: requestedDay) else {
            return (self, false)
        }

        return (
            DailyWidgetSnapshot(
                generatedAt: generatedAt,
                dayStart: requestedDay,
                state: .ready,
                calories: WidgetCalorieSummary(
                    consumed: 0,
                    target: calories.target
                )
            ),
            true
        )
    }
}
