import Foundation

enum WidgetConstants {
    static let appGroupIdentifier = "group.www.caloryn"
    static let dailyProgressKind = "CalorynDailyProgress"
    static let quickLogKind = "CalorynQuickLog"
    static let snapshotFileName = "daily-widget-snapshot.json"
    static let currentSchemaVersion = 1
}

enum DailyWidgetState: String, Codable, Hashable, Sendable {
    case needsOnboarding
    case ready
    case unavailable
}

struct WidgetCalorieSummary: Codable, Hashable, Sendable {
    let consumed: Int
    let baseTarget: Int
    let target: Int
    let dynamicAdjustment: Int

    init(
        consumed: Double,
        baseTarget: Int,
        target: Int,
        dynamicAdjustment: Int = 0
    ) {
        self.consumed = max(0, Int(consumed.rounded()))
        self.baseTarget = max(1, baseTarget)
        self.target = max(1, target)
        self.dynamicAdjustment = dynamicAdjustment
    }

    // Derived from the stored inputs above so they can never drift out of sync
    // and don't bloat the serialized snapshot.
    var remaining: Int { max(0, target - consumed) }
    var overAmount: Int { max(0, consumed - target) }
    var progress: Double { min(max(Double(consumed) / Double(target), 0), 1) }

    var isOver: Bool {
        overAmount > 0
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
        fixed(state: .ready, consumed: 1_258, at: date, calendar: calendar)
    }

    static func unavailable(at date: Date, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        fixed(state: .unavailable, consumed: 0, at: date, calendar: calendar)
    }

    /// Builds a snapshot with the fixed 2,000 kcal fallback target used by the
    /// onboarding / placeholder / unavailable states.
    private static func fixed(
        state: DailyWidgetState,
        consumed: Double,
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
                target: 2_000
            )
        )
    }

    /// Everything that affects what the widget draws, excluding `generatedAt`.
    /// Used both to skip redundant publishes and as a change-detection key in the app.
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
