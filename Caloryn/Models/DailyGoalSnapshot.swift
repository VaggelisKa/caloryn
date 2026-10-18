import Foundation
import SwiftData

@Model
final class DailyGoalSnapshot {
    var id: UUID = UUID()

    var dayKey: String = ""

    var baseCalorieTarget: Int = 0

    var healthAdjustment: Int = 0

    var effectiveCalorieTarget: Int = 0

    var calculationModeRaw: String = EnergyCalculationMode.lifestyleEstimate.rawValue

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
    let baseCalorieTarget: Int
    let healthAdjustment: Int
    let effectiveCalorieTarget: Int
    let calculationMode: EnergyCalculationMode
    let isManualTarget: Bool
}

extension ActivityCalorieBudget {
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
