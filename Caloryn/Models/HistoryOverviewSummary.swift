import Foundation

struct HistoryOverviewSummary: Equatable {
    struct GoalGap: Equatable {
        let emphasis: String
        let remainder: String

        var text: String { emphasis + remainder }
    }

    let loggedDayCount: Int
    let totalDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int

    var hasLoggedDays: Bool { loggedDayCount > 0 }

    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var averageUnitText: String { "kcal a day on average" }

    var emptyHeadlineText: String { "Nothing logged" }

    var goalGap: GoalGap? {
        guard hasLoggedDays else { return nil }

        let remainder = " your \(averageTargetPerLoggedDay.formatted()) goal"
        let difference = averageCaloriesPerLoggedDay.roundedCalories - averageTargetPerLoggedDay
        if difference < 0 {
            return GoalGap(emphasis: "\(abs(difference).formatted()) under", remainder: remainder)
        }
        if difference > 0 {
            return GoalGap(emphasis: "\(difference.formatted()) over", remainder: remainder)
        }
        return GoalGap(emphasis: "Right on", remainder: remainder)
    }

    var supportText: String {
        goalGap?.text ?? "No days logged in the last \(totalDayCount) days."
    }

    var averageAccessibilityLabel: String {
        guard hasLoggedDays else { return emptyHeadlineText }
        return "\(averageValueText) \(averageUnitText)"
    }

    var accessibilityLabel: String {
        guard hasLoggedDays else { return "\(emptyHeadlineText). \(supportText)" }
        return "\(averageAccessibilityLabel). \(supportText)."
    }
}

extension HistoryRange {
    var previousPeriodText: String {
        switch self {
        case .week:
            "last week"
        case .twoWeeks:
            "the two weeks before"
        case .month:
            "the 30 days before"
        case .quarter:
            "the 90 days before"
        }
    }

    var chipTitle: String {
        self == .week ? "\(days) days" : "\(days)"
    }
}

extension HistoryGoalStatus {
    var sentenceLabel: String {
        switch self {
        case .under:
            "Under"
        case .onTrack:
            "On track"
        case .over:
            "Over"
        case .notLogged:
            "Not logged"
        }
    }
}

struct HistoryMacroRowSummary: Equatable, Identifiable {
    let id: String
    let name: String
    let goalKind: NutrientGoalKind
    let averageGrams: Double
    let goalGrams: Double
    let hitDays: Int
    let loggedDays: Int
    let range: HistoryRange
    let averageGramsChange: Double?

    init(
        id: String,
        name: String,
        goalKind: NutrientGoalKind,
        averageGrams: Double,
        goalGrams: Double,
        hitDays: Int,
        loggedDays: Int,
        range: HistoryRange,
        averageGramsChange: Double?
    ) {
        self.id = id
        self.name = name
        self.goalKind = goalKind
        self.averageGrams = averageGrams
        self.goalGrams = goalGrams
        self.hitDays = hitDays
        self.loggedDays = loggedDays
        self.range = range
        self.averageGramsChange = averageGramsChange
    }

    var averageText: String {
        Self.wholeGrams(averageGrams)
    }

    var goalText: String {
        " / \(Self.wholeGrams(goalGrams)) g a day"
    }

    var averageRatio: Double {
        guard goalGrams > 0, averageGrams.isFinite else { return 0 }
        return min(1, max(0, averageGrams / goalGrams))
    }

    var metText: String {
        "\(goalKindName) · \(metWording)"
    }

    var changeText: String? {
        changeWording(unit: "g")
    }

    var accessibilityLabel: String {
        let base = "\(name), \(averageText) of \(Self.wholeGrams(goalGrams)) grams a day, \(goalKindName.lowercased()), \(metWording)"
        guard let change = changeWording(unit: "grams") else { return base }
        return "\(base), \(change)"
    }

    private var metWording: String {
        "\(goalKind == .maximum ? "at or under" : "met") on \(hitDays) of \(loggedDays) \(loggedDays == 1 ? "day" : "days")"
    }

    private func changeWording(unit: String) -> String? {
        guard let averageGramsChange else { return nil }

        let change = averageGramsChange.rounded().truncatedSafely
        guard change != 0 else { return nil }
        let amount = change.magnitude.formatted()
        let direction = change > 0 ? "more" : "less"
        return "\(amount) \(unit) \(direction) than \(range.previousPeriodText)"
    }

    private var goalKindName: String {
        switch goalKind {
        case .minimum:
            "Minimum"
        case .target:
            "Target"
        case .maximum:
            "Maximum"
        }
    }

    private static func wholeGrams(_ grams: Double) -> String {
        grams.rounded().truncatedSafely.formatted()
    }
}
