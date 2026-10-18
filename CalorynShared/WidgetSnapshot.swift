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
    let baseTarget: Int
    let target: Int
    let dynamicAdjustment: Int
    let meals: [WidgetMealCalories]

    init(
        consumed: Double,
        baseTarget: Int,
        target: Int,
        dynamicAdjustment: Int = 0,
        mealCalories: [WidgetMeal: Double] = [:]
    ) {
        self.consumed = Self.clamped(consumed)
        self.baseTarget = max(1, baseTarget)
        self.target = max(1, target)
        self.dynamicAdjustment = dynamicAdjustment
        self.meals = WidgetMeal.allCases.compactMap { meal in
            guard let kcal = mealCalories[meal] else { return nil }
            return WidgetMealCalories(meal: meal, kcal: Self.clamped(kcal))
        }
    }

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

    private enum CodingKeys: String, CodingKey {
        case consumed, baseTarget, target, dynamicAdjustment, meals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consumed = try container.decode(Int.self, forKey: .consumed)
        baseTarget = try container.decode(Int.self, forKey: .baseTarget)
        target = try container.decode(Int.self, forKey: .target)
        dynamicAdjustment = try container.decode(Int.self, forKey: .dynamicAdjustment)
        meals = try container.decodeIfPresent([WidgetMealCalories].self, forKey: .meals) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(consumed, forKey: .consumed)
        try container.encode(baseTarget, forKey: .baseTarget)
        try container.encode(target, forKey: .target)
        try container.encode(dynamicAdjustment, forKey: .dynamicAdjustment)
        try container.encode(meals, forKey: .meals)
    }
}

struct DailyWidgetSnapshot: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let dayStart: Date
    let state: DailyWidgetState
    let calories: WidgetCalorieSummary
    let usesDynamicTarget: Bool
    let activityRefreshedAt: Date?

    init(
        generatedAt: Date,
        dayStart: Date,
        state: DailyWidgetState,
        calories: WidgetCalorieSummary,
        usesDynamicTarget: Bool = false,
        activityRefreshedAt: Date? = nil,
        schemaVersion: Int = WidgetConstants.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.dayStart = dayStart
        self.state = state
        self.calories = calories
        self.usesDynamicTarget = usesDynamicTarget
        self.activityRefreshedAt = activityRefreshedAt
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
                baseTarget: 2_000,
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
        let usesDynamicTarget: Bool
        let activityRefreshedAt: Date?
    }

    var renderIdentity: RenderIdentity {
        RenderIdentity(
            schemaVersion: schemaVersion,
            dayStart: dayStart,
            state: state,
            calories: calories,
            usesDynamicTarget: usesDynamicTarget,
            activityRefreshedAt: activityRefreshedAt
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
                    baseTarget: calories.baseTarget,
                    target: calories.baseTarget
                ),
                usesDynamicTarget: usesDynamicTarget,
                activityRefreshedAt: activityRefreshedAt
            ),
            true
        )
    }
}
