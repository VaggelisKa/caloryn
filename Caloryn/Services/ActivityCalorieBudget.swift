import Foundation

struct DailyActiveEnergySample: Equatable {
    let date: Date
    let activeEnergyKcal: Double
}

struct ActivityCalorieBudget: Equatable {
    enum DynamicStatus: Equatable {
        case staticEstimate
        case unavailable(String)
        case learning(validDays: Int, requiredDays: Int)
        case ready
    }

    static let requiredDynamicActivityDays = 7
    static let maxDynamicActivityDays = 14
    static let historyLookbackDays = 21
    static let minimumValidActiveEnergyKcal = 50.0
    static let thermicEffectOfFoodRatio = 0.10
    static let minimumTarget = 1_200
    static let minimumDailyDelta = -300
    static let maximumDailyDelta = 600

    let consumed: Double
    let staticTarget: Int
    let bmr: Double
    let calorieDeficit: Double
    let activeEnergyKcal: Double
    let recentActiveEnergySamples: [DailyActiveEnergySample]
    let calculationMode: EnergyCalculationMode
    let isManualOverride: Bool
    let isActivityLoading: Bool
    let activityMessage: String?
    let date: Date

    static var dynamicEnergyPolicyText: String {
        "Apple Health activity"
    }

    static var dynamicEnergyShortText: String {
        "Auto-adjust calories"
    }

    static var connectedWaitingText: String {
        "Apple Health is connected. Waiting for Active Energy data."
    }

    var isDynamicModeRequested: Bool {
        calculationMode == .dynamicHealth
    }

    var validActivityDays: Int {
        validActivitySamples.count
    }

    var hasAnyActiveEnergyData: Bool {
        activeEnergyKcal > 0 || recentActiveEnergySamples.contains { $0.activeEnergyKcal > 0 }
    }

    var activityBaselineKcal: Double? {
        guard dynamicStatus == .ready else { return nil }
        return Self.median(samplesForBaseline.map(\.activeEnergyKcal))
    }

    var dynamicStatus: DynamicStatus {
        guard calculationMode == .dynamicHealth else {
            return .staticEstimate
        }

        if isManualOverride {
            return .unavailable("Auto-adjust calories is unavailable while a manual calorie target is set.")
        }

        if let activityMessage {
            return .unavailable(activityMessage)
        }

        guard validActivityDays >= Self.requiredDynamicActivityDays else {
            return .learning(
                validDays: validActivityDays,
                requiredDays: Self.requiredDynamicActivityDays
            )
        }

        return .ready
    }

    var baseTarget: Int {
        guard let activityBaselineKcal else { return staticTarget }
        let maintenanceTDEE = bmr + (bmr * Self.thermicEffectOfFoodRatio) + activityBaselineKcal
        return NutritionCalculator.defaultTarget(
            energyExpenditure: maintenanceTDEE,
            deficit: calorieDeficit
        )
    }

    var dynamicIncrease: Int {
        max(0, dynamicAdjustment)
    }

    var adjustedTarget: Int {
        guard dynamicStatus == .ready else { return baseTarget }
        return max(Self.minimumTarget, baseTarget + dynamicAdjustment)
    }

    var roundedConsumed: Int {
        Int(consumed.rounded())
    }

    var remaining: Int {
        max(0, adjustedTarget - roundedConsumed)
    }

    var overAmount: Int {
        max(0, roundedConsumed - adjustedTarget)
    }

    var isOver: Bool {
        consumed > Double(adjustedTarget)
    }

    var hasDynamicIncrease: Bool {
        dynamicStatus == .ready && dynamicAdjustment > 0 && adjustedTarget > baseTarget
    }

    var hasDynamicReduction: Bool {
        dynamicStatus == .ready && dynamicAdjustment < 0 && adjustedTarget < baseTarget
    }

    var dynamicAdjustment: Int {
        guard dynamicStatus == .ready, let activityBaselineKcal else { return 0 }
        let rawDelta: Double
        if date.startOfDay.isToday {
            rawDelta = max(0, activeEnergyKcal - activityBaselineKcal)
        } else {
            rawDelta = activeEnergyKcal - activityBaselineKcal
        }

        let roundedDelta = Int(rawDelta.rounded())
        return min(max(roundedDelta, Self.minimumDailyDelta), Self.maximumDailyDelta)
    }

    var progress: Double {
        guard adjustedTarget > 0 else { return 0 }
        return min(consumed / Double(adjustedTarget), 1.5)
    }

    var displayedRingProgress: Double {
        min(progress, 1.0)
    }

    var baseProgressEnd: Double {
        guard adjustedTarget > 0 else { return 1 }
        return min(max(Double(baseTarget) / Double(adjustedTarget), 0), 1)
    }

    var dynamicStatusText: String? {
        switch dynamicStatus {
        case .staticEstimate:
            return nil
        case .unavailable(let message):
            return message
        case .learning(let validDays, let requiredDays):
            if validDays == 0 && !hasAnyActiveEnergyData {
                return Self.connectedWaitingText
            }

            return "Needs \(requiredDays) active days to learn your baseline. \(validDays) found so far."
        case .ready:
            return nil
        }
    }

    private var validActivitySamples: [DailyActiveEnergySample] {
        recentActiveEnergySamples
            .filter { $0.activeEnergyKcal >= Self.minimumValidActiveEnergyKcal }
    }

    private var samplesForBaseline: [DailyActiveEnergySample] {
        validActivitySamples
            .sorted { $0.date > $1.date }
            .prefix(Self.maxDynamicActivityDays)
            .map { $0 }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let midpoint = sorted.count / 2

        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }

        return sorted[midpoint]
    }
}
