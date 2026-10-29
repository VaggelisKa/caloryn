import Foundation

struct HistoryOverviewSummary: Equatable {
    let range: HistoryRange
    let loggedDayCount: Int
    let totalDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int
    let onTrackLoggedDayCount: Int
    let onTrackDayDelta: Int

    init(
        range: HistoryRange,
        loggedDayCount: Int,
        totalDayCount: Int,
        averageCaloriesPerLoggedDay: Double,
        averageTargetPerLoggedDay: Int,
        onTrackLoggedDayCount: Int,
        onTrackDayDelta: Int
    ) {
        self.range = range
        self.loggedDayCount = loggedDayCount
        self.totalDayCount = totalDayCount
        self.averageCaloriesPerLoggedDay = averageCaloriesPerLoggedDay
        self.averageTargetPerLoggedDay = averageTargetPerLoggedDay
        self.onTrackLoggedDayCount = onTrackLoggedDayCount
        self.onTrackDayDelta = onTrackDayDelta
    }

    var hasLoggedDays: Bool { loggedDayCount > 0 }

    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var averageUnitText: String { "kcal a day" }

    var emptyHeadlineText: String { "Nothing logged" }

    var supportText: String {
        guard hasLoggedDays else {
            return "No days logged in the last \(totalDayCount) days."
        }

        let target = averageTargetPerLoggedDay.formatted()
        let difference = averageCaloriesPerLoggedDay.roundedCalories - averageTargetPerLoggedDay
        let goalText: String
        if difference < 0 {
            goalText = "\(abs(difference).formatted()) under your \(target) goal"
        } else if difference > 0 {
            goalText = "\(difference.formatted()) over your \(target) goal"
        } else {
            goalText = "Right on your \(target) goal"
        }

        return "\(goalText), \(loggedDayCount) of \(totalDayCount) days logged"
    }

    var averageAccessibilityLabel: String {
        guard hasLoggedDays else { return emptyHeadlineText }
        return "\(averageValueText) \(averageUnitText) on average"
    }

    var accessibilityLabel: String {
        guard hasLoggedDays else { return "\(emptyHeadlineText). \(supportText)" }
        return "\(averageValueText) \(averageUnitText) on average. \(supportText)."
    }

    var onTrackValueText: String {
        onTrackLoggedDayCount.formatted()
    }

    var onTrackSupportText: String {
        let dayLabel = loggedDayCount == 1 ? "day" : "days"
        return "of \(loggedDayCount) logged \(dayLabel), \(comparisonText)"
    }

    var onTrackAccessibilityLabel: String {
        "On track: \(onTrackValueText) \(onTrackSupportText)."
    }

    private var comparisonText: String {
        let count = Self.countWord(abs(onTrackDayDelta))
        let previous = range.previousPeriodText
        if onTrackDayDelta > 0 { return "\(count) more than \(previous)" }
        if onTrackDayDelta < 0 { return "\(count) fewer than \(previous)" }
        return "the same as \(previous)"
    }

    static func countWord(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        guard words.indices.contains(count) else { return count.formatted() }
        return words[count]
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
        "met on \(hitDays) of \(loggedDays) \(loggedDays == 1 ? "day" : "days")"
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
