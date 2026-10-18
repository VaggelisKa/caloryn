import Foundation

/// What the top of History says: the daily-average headline ("1,953 kcal a day"), the line
/// under it, and the "On track" count with its comparison to the period before.
///
/// Takes the period's counts and averages rather than the summary, so every wording —
/// including the empty range and the singular day — is reachable without entries or a store.
struct HistoryOverviewSummary: Equatable {
    let range: HistoryRange
    let loggedDayCount: Int
    let totalDayCount: Int
    let averageCaloriesPerLoggedDay: Double
    let averageTargetPerLoggedDay: Int
    let onTrackLoggedDayCount: Int
    /// On-track days now minus on-track days in the equally long period before.
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

    // MARK: - Headline

    /// The average per logged day, whole kcal, grouped for the locale.
    var averageValueText: String {
        averageCaloriesPerLoggedDay.rounded().truncatedSafely.formatted()
    }

    var averageUnitText: String { "kcal a day" }

    /// Shown in place of the number when nothing in the range is logged: an average of zero
    /// would read as a day of fasting rather than as no record.
    var emptyHeadlineText: String { "Nothing logged" }

    /// "47 under your 2,000 goal, 6 of 7 days logged". The difference is the displayed
    /// average against the average goal of the same logged days, so the two numbers the
    /// reader can see always subtract to the one in the sentence.
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

    /// The headline alone, for VoiceOver: "1,953 kcal a day on average".
    var averageAccessibilityLabel: String {
        guard hasLoggedDays else { return emptyHeadlineText }
        return "\(averageValueText) \(averageUnitText) on average"
    }

    /// The headline and its support line as one sentence, for VoiceOver.
    var accessibilityLabel: String {
        guard hasLoggedDays else { return "\(emptyHeadlineText). \(supportText)" }
        return "\(averageValueText) \(averageUnitText) on average. \(supportText)."
    }

    // MARK: - On track

    var onTrackValueText: String {
        onTrackLoggedDayCount.formatted()
    }

    /// "of 6 logged days, one fewer than last week".
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

    /// Small counts read as words ("one fewer"), larger ones as figures.
    static func countWord(_ count: Int) -> String {
        let words = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]
        guard words.indices.contains(count) else { return count.formatted() }
        return words[count]
    }
}

extension HistoryRange {
    /// The equally long period before this one, as History compares against it.
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

    /// The range chip's title. Only the first chip carries the unit — "7 days", "14", "30",
    /// "90" — so the row stays one line at the larger text sizes. VoiceOver and the UI tests
    /// read the full `label` instead.
    var chipTitle: String {
        self == .week ? "\(days) days" : "\(days)"
    }
}

extension HistoryGoalStatus {
    /// The status in sentence case, for the status badge: "On track", "Not logged".
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

/// One row of History's "Macros" section: the name, its daily average and how many logged
/// days hit the goal, plus the share that fills the ink bar and the change in the average
/// from the period before.
struct HistoryMacroRowSummary: Equatable, Identifiable {
    let id: String
    let name: String
    let goalKind: NutrientGoalKind
    let averageGrams: Double
    let hitDays: Int
    let loggedDays: Int
    let range: HistoryRange
    /// This period's daily average minus the period before's; `nil` when nothing was logged
    /// before, so there is nothing to compare against.
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

    /// How much of the bar is filled: the share of logged days that met the goal, 0 with
    /// nothing logged.
    var hitRatio: Double {
        guard loggedDays > 0 else { return 0 }
        return min(1, max(0, Double(hitDays) / Double(loggedDays)))
    }

    /// "124 g a day, hit 3 of 6".
    var detailText: String {
        "\(averageGrams.rounded().truncatedSafely.formatted()) g a day, \(hitLabel) \(hitDays) of \(loggedDays)"
    }

    /// "12 g more than last week", "Same as last week"; `nil` with nothing to compare against.
    /// Rounded to whole grams first, so a change that shows as 0 g reads as the same.
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
