import Foundation
import SwiftData

/// CloudKit compatibility: every attribute has a default value and there are no
/// unique constraints, so adding this model is an additive, lightweight schema
/// change for existing stores. Uniqueness per day is enforced by
/// `DailyGoalSnapshotStore` upserts and by last-write-wins deduplication when
/// reading, because CloudKit-backed stores cannot declare `.unique` attributes.
@Model
final class DailyGoalSnapshot {
    var id: UUID = UUID()

    var dayKey: String = ""

    var baseCalorieTarget: Int = 0

    var effectiveCalorieTarget: Int = 0

    // Recorded the removed Apple Health auto-adjust. Kept so the CloudKit-backed store
    // migrates without a schema change; snapshots from before the removal still carry them.
    var healthAdjustment: Int = 0
    var calculationModeRaw: String = "lifestyleEstimate"

    var isManualTarget: Bool = false

    var goalRevisionID: UUID?

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

    var values: DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            calorieTarget: effectiveCalorieTarget,
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
        baseCalorieTarget = values.calorieTarget
        healthAdjustment = 0
        effectiveCalorieTarget = values.calorieTarget
        calculationModeRaw = "lifestyleEstimate"
        isManualTarget = values.isManualTarget
        goalRevisionID = profile?.id
        goalRevisionUpdatedAt = profile?.updatedAt
        updatedAt = recordedAt
    }

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

struct DailyGoalSnapshotValues: Equatable {
    let calorieTarget: Int
    let isManualTarget: Bool
}

extension CalorieBudget {
    var goalSnapshotValues: DailyGoalSnapshotValues {
        DailyGoalSnapshotValues(
            calorieTarget: target,
            isManualTarget: isManualOverride
        )
    }
}
