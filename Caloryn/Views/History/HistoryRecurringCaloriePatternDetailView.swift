import SwiftUI

struct HistoryRecurringCaloriePatternDetailView: View {
    let pattern: HistoryRecurringCaloriePattern

    @State private var expandedDayIDs: Set<Date> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: CalorynTheme.cardSpacing) {
                HistoryPatternContextHeader(pattern: pattern)
                HistoryPatternGroupCountsCard(pattern: pattern)

                ForEach(pattern.supportingDays) { day in
                    HistoryPatternSupportingDayCard(
                        day: day,
                        mealType: pattern.mealType,
                        isExpanded: expandedDayIDs.contains(day.id),
                        action: { toggleDay(day) }
                    )
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 20)
        }
        .calorynPageCanvas()
        .historyDrillDownNavigation()
        .navigationTitle("Pattern Details")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("history.recurringPattern.details")
    }

    private func toggleDay(_ day: HistoryRecurringCaloriePatternDay) {
        withAnimation(.smooth(duration: 0.2)) {
            if expandedDayIDs.contains(day.id) {
                expandedDayIDs.remove(day.id)
            } else {
                expandedDayIDs.insert(day.id)
            }
        }
    }
}

private struct HistoryPatternContextHeader: View {
    let pattern: HistoryRecurringCaloriePattern

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pattern.headline)
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(pattern.basisText)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryPatternGroupCountsCard: View {
    let pattern: HistoryRecurringCaloriePattern

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var mealName: String {
        pattern.mealType == .snack ? "Snack" : pattern.mealType.displayName
    }

    private var mealDifference: String {
        let roundedDifference = Int(abs(pattern.mealDifferenceCalories).rounded()).formatted()
        let sign = pattern.mealDifferenceCalories >= 0 ? "+" : "−"
        return "\(sign)\(roundedDifference) kcal"
    }

    private var supportingTitle: String {
        switch pattern.kind {
        case .weekdayMeal:
            "Logged \(pattern.weekdayName)s"
        case .mealOnly:
            "\(pattern.outcome.targetText.capitalized) days"
        }
    }

    private var supportingValue: String {
        switch pattern.kind {
        case .weekdayMeal:
            "\(pattern.supportingDays.count) of \(pattern.cohortDayCount)"
        case .mealOnly:
            "\(pattern.supportingDays.count)"
        }
    }

    private var supportingDetail: String {
        switch pattern.kind {
        case .weekdayMeal:
            pattern.outcome.targetText
        case .mealOnly:
            "supporting logged days"
        }
    }

    private var comparisonValue: String {
        switch pattern.kind {
        case .weekdayMeal:
            "\(pattern.outcomeComparisonCount) of \(pattern.outcomeComparisonDayCount)"
        case .mealOnly:
            "\(pattern.mealComparisonDayCount)"
        }
    }

    private var comparisonDetail: String {
        switch pattern.kind {
        case .weekdayMeal:
            pattern.outcome.targetText
        case .mealOnly:
            "comparison logged days"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Outcome Frequency")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            frequencyComparison

            Divider()
                .foregroundStyle(CalorynTheme.cardSeparator)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(mealName) Comparison")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                Text(mealDifference)
                    .font(CalorynTheme.compactNumber)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("Average difference versus other eligible logged days")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        .historyCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pattern evidence")
    }

    @ViewBuilder
    private var frequencyComparison: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                frequencyStats
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                frequencyStats
            }
        }
    }

    @ViewBuilder
    private var frequencyStats: some View {
        HistoryPatternFrequencyStat(
            title: supportingTitle,
            value: supportingValue,
            detail: supportingDetail
        )

        HistoryPatternFrequencyStat(
            title: "Other logged days",
            value: comparisonValue,
            detail: comparisonDetail
        )
    }
}

private struct HistoryPatternFrequencyStat: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(value)
                .font(CalorynTheme.compactNumber)
                .foregroundStyle(CalorynTheme.textPrimary)

            Text(detail)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryPatternSupportingDayCard: View {
    let day: HistoryRecurringCaloriePatternDay
    let mealType: MealType
    let isExpanded: Bool
    let action: () -> Void

    private var mealName: String {
        mealType == .snack ? "Snacks" : mealType.displayName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.date.shortFormatted)
                                .font(CalorynTheme.itemTitle)
                                .foregroundStyle(CalorynTheme.textPrimary)

                            Text("\(Int(day.totalCalories.rounded()).formatted()) kcal logged · \(day.dailyCalorieTarget.formatted()) kcal target")
                                .font(CalorynTheme.caption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(CalorynTheme.compactIcon)
                            .foregroundStyle(CalorynTheme.sage)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }

                    Divider()
                        .foregroundStyle(CalorynTheme.cardSeparator)

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: mealType.iconName)
                            .font(CalorynTheme.compactIcon)
                            .foregroundStyle(CalorynTheme.sage)
                            .frame(width: 20)
                            .accessibilityHidden(true)

                        Text(mealName)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text(Int(day.mealCalories.rounded()).kcalFormatted)
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(day.date.shortFormatted), \(Int(day.totalCalories.rounded()).formatted()) kcal logged, \(day.dailyCalorieTarget.formatted()) kcal target, \(mealName), \(Int(day.mealCalories.rounded()).kcalFormatted)"
            )
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses contributing foods" : "Expands contributing foods")
            .accessibilityIdentifier("history.recurringPattern.supportingDay")

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Foods logged in \(mealName.lowercased())")
                        .font(CalorynTheme.microCaptionEmphasized)
                        .foregroundStyle(CalorynTheme.textSecondary)

                    if day.mealFoods.isEmpty {
                        Text("No \(mealName.lowercased()) calories were logged.")
                            .font(CalorynTheme.microCaption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(day.mealFoods) { food in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(food.name)
                                    .font(CalorynTheme.caption)
                                    .foregroundStyle(CalorynTheme.textPrimary)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                Text(Int(food.calories.rounded()).kcalFormatted)
                                    .font(CalorynTheme.numericCaption)
                                    .foregroundStyle(CalorynTheme.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("history.recurringPattern.supportingDay.details")
                .transition(.opacity)
            }
        }
        .historyCard()
    }
}

#if DEBUG
#Preview("Pattern Details") {
    HistoryPreviewFixtures.patternDetailPreview()
}
#endif
