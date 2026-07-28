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
        .calorynDrillDownNavigation()
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

    private var summary: HistoryRecurringCaloriePatternDetailSummary {
        HistoryRecurringCaloriePatternDetailSummary(
            kind: pattern.kind,
            outcomeTargetText: pattern.outcome.targetText,
            weekdayName: pattern.weekdayName,
            mealType: pattern.mealType,
            supportingDayCount: pattern.supportingDays.count,
            cohortDayCount: pattern.cohortDayCount,
            outcomeComparisonCount: pattern.outcomeComparisonCount,
            outcomeComparisonDayCount: pattern.outcomeComparisonDayCount,
            mealComparisonDayCount: pattern.mealComparisonDayCount,
            mealDifferenceCalories: pattern.mealDifferenceCalories
        )
    }

    var body: some View {
        let summary = summary

        return VStack(alignment: .leading, spacing: 16) {
            Text("Outcome Frequency")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            frequencyComparison(summary)

            Divider()
                .foregroundStyle(CalorynTheme.cardSeparator)

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.mealComparisonTitle)
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                Text(summary.mealDifferenceText)
                    .font(CalorynTheme.compactNumber)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(summary.mealDifferenceCaption)
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
    private func frequencyComparison(
        _ summary: HistoryRecurringCaloriePatternDetailSummary
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                frequencyStats(summary)
            }
        } else {
            HStack(alignment: .top, spacing: 16) {
                frequencyStats(summary)
            }
        }
    }

    @ViewBuilder
    private func frequencyStats(
        _ summary: HistoryRecurringCaloriePatternDetailSummary
    ) -> some View {
        HistoryPatternFrequencyStat(
            title: summary.supportingTitle,
            value: summary.supportingValue,
            detail: summary.supportingDetail
        )

        HistoryPatternFrequencyStat(
            title: summary.comparisonTitle,
            value: summary.comparisonValue,
            detail: summary.comparisonDetail
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

    private var row: HistoryRecurringCaloriePatternDayRow {
        HistoryRecurringCaloriePatternDayRow(
            dateText: day.date.shortFormatted,
            totalCalories: day.totalCalories,
            dailyCalorieTarget: day.dailyCalorieTarget,
            mealCalories: day.mealCalories,
            mealType: mealType,
            isExpanded: isExpanded
        )
    }

    var body: some View {
        let row = row

        return VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.dateText)
                                .font(CalorynTheme.itemTitle)
                                .foregroundStyle(CalorynTheme.textPrimary)

                            Text(row.totalsText)
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

                        Text(row.mealName)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text(row.mealCaloriesText)
                            .font(CalorynTheme.numericCaption)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.accessibilityLabel)
            .accessibilityValue(row.accessibilityValue)
            .accessibilityHint(row.accessibilityHint)
            .accessibilityIdentifier("history.recurringPattern.supportingDay")

            if isExpanded {
                VStack(alignment: .leading, spacing: 7) {
                    Text(row.expandedSectionTitle)
                        .font(CalorynTheme.microCaptionEmphasized)
                        .foregroundStyle(CalorynTheme.textSecondary)

                    if day.mealFoods.isEmpty {
                        Text(row.expandedEmptyText)
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
