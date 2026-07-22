import Foundation
import SwiftData

/// The canonical record of the calorie goal that applied to one calendar day.
///
/// Today computes an effective calorie target at runtime (base target plus any
/// eligible Apple Health adjustment). This model persists that promise once per
/// calendar day so History can evaluate each day against the target that was
/// actually shown to the user on that date, instead of reinterpreting the past
/// with the current profile settings.
///
/// CloudKit compatibility: every attribute has a default value and there are no
/// unique constraints, so adding this model is an additive, lightweight schema
/// change for existing stores. Uniqueness per day is enforced by
/// `DailyGoalSnapshotStore` upserts and by last-write-wins deduplication when
/// reading, because CloudKit-backed stores cannot declare `.unique` attributes.
@Model
final class DailyGoalSnapshot {
    var id: UUID = UUID()

    /// Calendar-day identity in the "yyyy-MM-dd" form produced by
    /// `DailyGoalSnapshot.dayKey(for:calendar:)`. The key is derived from the
    /// calendar (and therefore time zone) that was current when the snapshot
    /// was recorded, which keeps day-boundary behavior deterministic: a day
    /// keeps the identity it had while the user lived it.
    var dayKey: String = ""

    /// The base calorie target before any Health adjustment.
    var baseCalorieTarget: Int = 0

    /// The Apple Health activity adjustment applied on top of the base target.
    /// Zero for static and manual days. Always equals
    /// `effectiveCalorieTarget - baseCalorieTarget`.
    var healthAdjustment: Int = 0

    /// The effective calorie target the user was asked to hit that day.
    var effectiveCalorieTarget: Int = 0

    /// Raw `EnergyCalculationMode` that applied that day.
    var calculationModeRaw: String = EnergyCalculationMode.lifestyleEstimate.rawValue

    /// Whether the target came from a manual override rather than a computed
    /// recommendation. Manual days keep manual semantics: base == effective and
    /// no Health adjustment.
    var isManualTarget: Bool = false

    /// Identity of the goal revision (profile) that produced this snapshot.
    var goalRevisionID: UUID?

    /// `updatedAt` of the profile at recording time, distinguishing revisions
    /// of the same profile.
    var goalRevisionUpdatedAt: Date?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        dayKey: String,
        values: DailyGoalSnapshotValues,
        profile: UserProfile?,
        recordedAt: Date = .now
    ) {
        self.id = UUID()
        self.dayKey = dayKey
        self.createdAt = recordedAt
        self.updatedAt = recordedAt
        apply(values, profile: profile, recordedAt: recordedAt)
    }

    var calculationMode: EnergyCalculationMode {
        EnergyCalculationMode(rawValue: calculationModeRaw) ?? .lifestyleEstimate
    }

    var values: DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            baseCalorieTarget: baseCalorieTarget,
            healthAdjustment: healthAdjustment,
            effectiveCalorieTarget: effectiveCalorieTarget,
            calculationMode: calculationMode,
            isManualTarget: isManualTarget
        )
    }

    func matches(_ values: DailyGoalSnapshotValues, profile: UserProfile?) -> Bool {
        self.values == values
            && goalRevisionID == profile?.id
            && goalRevisionUpdatedAt == profile?.updatedAt
    }

    func apply(
        _ values: DailyGoalSnapshotValues,
        profile: UserProfile?,
        recordedAt: Date = .now
    ) {
        baseCalorieTarget = values.baseCalorieTarget
        healthAdjustment = values.healthAdjustment
        effectiveCalorieTarget = values.effectiveCalorieTarget
        calculationModeRaw = values.calculationMode.rawValue
        isManualTarget = values.isManualTarget
        goalRevisionID = profile?.id
        goalRevisionUpdatedAt = profile?.updatedAt
        updatedAt = recordedAt
    }

    /// Deterministic calendar-day key for a date. Uses the supplied calendar's
    /// time zone, so the same instant can legitimately map to different keys in
    /// different time zones — what matters is that recording and lookup use the
    /// device's current calendar consistently.
    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

/// Value form of a daily goal snapshot, decoupled from SwiftData for pure
/// computation and testing.
struct DailyGoalSnapshotValues: Equatable {
    let baseCalorieTarget: Int
    let healthAdjustment: Int
    let effectiveCalorieTarget: Int
    let calculationMode: EnergyCalculationMode
    let isManualTarget: Bool
}

extension ActivityCalorieBudget {
    /// The single canonical definition of a day's goal. Today renders
    /// `adjustedTarget` directly and History compares against the persisted
    /// copy of these values, so both surfaces always share one definition of
    /// "effective target".
    ///
    /// `healthAdjustment` is derived from `adjustedTarget - baseTarget` (the
    /// adjustment that actually applied after clamping and the safe minimum),
    /// so `base + adjustment == effective` holds for every snapshot.
    var goalSnapshotValues: DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            baseCalorieTarget: baseTarget,
            healthAdjustment: adjustedTarget - baseTarget,
            effectiveCalorieTarget: adjustedTarget,
            calculationMode: calculationMode,
            isManualTarget: isManualOverride
        )
    }
}
