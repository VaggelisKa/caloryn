import Foundation

enum WidgetConstants {
    static let appGroupIdentifier = "group.www.caloryn"
    static let dailyProgressKind = "CalorynDailyProgress"
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
    let remaining: Int
    let overAmount: Int
    let progress: Double
    let dynamicAdjustment: Int

    init(
        consumed: Double,
        baseTarget: Int,
        target: Int,
        dynamicAdjustment: Int = 0
    ) {
        let roundedConsumed = max(0, Int(consumed.rounded()))
        let safeBaseTarget = max(1, baseTarget)
        let safeTarget = max(1, target)

        self.consumed = roundedConsumed
        self.baseTarget = safeBaseTarget
        self.target = safeTarget
        self.remaining = max(0, safeTarget - roundedConsumed)
        self.overAmount = max(0, roundedConsumed - safeTarget)
        self.progress = min(max(Double(roundedConsumed) / Double(safeTarget), 0), 1)
        self.dynamicAdjustment = dynamicAdjustment
    }

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
        DailyWidgetSnapshot(
            generatedAt: date,
            dayStart: calendar.startOfDay(for: date),
            state: .needsOnboarding,
            calories: WidgetCalorieSummary(
                consumed: 0,
                baseTarget: 2_000,
                target: 2_000
            )
        )
    }

    static func placeholder(at date: Date = .now, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            generatedAt: date,
            dayStart: calendar.startOfDay(for: date),
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: 1_258,
                baseTarget: 2_000,
                target: 2_000
            )
        )
    }

    static func unavailable(at date: Date, calendar: Calendar = .current) -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            generatedAt: date,
            dayStart: calendar.startOfDay(for: date),
            state: .unavailable,
            calories: WidgetCalorieSummary(
                consumed: 0,
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
