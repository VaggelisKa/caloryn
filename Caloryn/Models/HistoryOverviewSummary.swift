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
    let hitDays: Int
    let loggedDays: Int
    let range: HistoryRange
    let averageGramsChange: Double?

    init(
        id: String,
        name: String,
        goalKind: NutrientGoalKind,
        averageGrams: Double,
        hitDays: Int,
        loggedDays: Int,
        range: HistoryRange,
        averageGramsChange: Double?
    ) {
        self.id = id
        self.name = name
        self.goalKind = goalKind
        self.averageGrams = averageGrams
        self.hitDays = hitDays
        self.loggedDays = loggedDays
        self.range = range
        self.averageGramsChange = averageGramsChange
    }

    var hitRatio: Double {
        guard loggedDays > 0 else { return 0 }
        return min(1, max(0, Double(hitDays) / Double(loggedDays)))
    }

    var detailText: String {
        "\(averageGrams.rounded().truncatedSafely.formatted()) g a day, \(hitLabel) \(hitDays) of \(loggedDays)"
    }

    var changeText: String? {
        changeWording(unit: "g")
    }

    var accessibilityLabel: String {
        let base = "\(name), \(averageGrams.rounded().truncatedSafely.formatted()) grams a day, \(hitLabel) on \(hitDays) of \(loggedDays) logged days"
        guard let change = changeWording(unit: "grams") else { return base }
        return "\(base), \(change.prefix(1).lowercased())\(change.dropFirst())"
    }

    private func changeWording(unit: String) -> String? {
        guard let averageGramsChange else { return nil }

        let change = averageGramsChange.rounded().truncatedSafely
        let amount = change.magnitude.formatted()
        let previous = range.previousPeriodText
        if change > 0 { return "\(amount) \(unit) more than \(previous)" }
        if change < 0 { return "\(amount) \(unit) less than \(previous)" }
        return "Same as \(previous)"
    }

    private var hitLabel: String {
        switch goalKind {
        case .minimum:
            "hit"
        case .target:
            "on target"
        case .maximum:
            "under max"
        }
    }
}
