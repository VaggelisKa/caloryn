import SwiftUI

struct HistoryRecurringCaloriePatternDetailView: View {
    let pattern: HistoryRecurringCaloriePattern

    @State private var expandedDayIDs: Set<Date>

    init(
        pattern: HistoryRecurringCaloriePattern,
        initiallyExpandedDayIDs: Set<Date> = []
    ) {
        self.pattern = pattern
        _expandedDayIDs = State(initialValue: initiallyExpandedDayIDs)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                HistoryPatternContextHeader(pattern: pattern)
                HistoryPatternEvidence(pattern: pattern)

                VStack(alignment: .leading, spacing: 4) {
                    HistorySectionTitle("Supporting days")

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(pattern.supportingDays) { day in
                            HistoryPatternSupportingDayRow(
                                day: day,
                                dateText: pattern.dayText(for: day.date),
                                mealType: pattern.mealType,
                                isExpanded: expandedDayIDs.contains(day.id),
                                action: { toggleDay(day) }
                            )

                            if day.id != pattern.supportingDays.last?.id {
                                HistoryHairline()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .historyDebugScrollAnchor()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Pattern details")
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
                .font(CalorynTheme.sectionTitle.weight(.heavy))
                .tracking(-0.4)
                .foregroundStyle(CalorynTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(pattern.comparisonText)
                .font(CalorynTheme.cardSubtitle)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(pattern.basisText)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// How often the outcome happened on the pattern's days against the rest, and how much
/// heavier (or lighter) the meal ran.
private struct HistoryPatternEvidence: View {
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

        return VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 12) {
                HistorySectionTitle("Outcome frequency")
                frequencyComparison(summary)
            }

            VStack(alignment: .leading, spacing: 4) {
                HistorySectionTitle(summary.mealComparisonTitle)
                    .padding(.bottom, 6)

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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        VStack(alignment: .leading, spacing: 2) {
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

/// One supporting day as a hairline row: the date and its totals on the left, the meal's
/// kcal over its name (in the meal's ink) on the right, and a chevron that opens the foods.
private struct HistoryPatternSupportingDayRow: View {
    let day: HistoryRecurringCaloriePatternDay
    let dateText: String
    let mealType: MealType
    let isExpanded: Bool
    let action: () -> Void

    private var row: HistoryRecurringCaloriePatternDayRow {
        HistoryRecurringCaloriePatternDayRow(
            dateText: dateText,
            totalCalories: day.totalCalories,
            dailyCalorieTarget: day.dailyCalorieTarget,
            mealCalories: day.mealCalories,
            mealType: mealType,
            isExpanded: isExpanded
        )
    }

    var body: some View {
        let row = row

        return VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.dateText)
                            .font(CalorynTheme.bodyText.weight(.medium))
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Text(row.totalsText)
                            .font(CalorynTheme.caption.monospacedDigit())
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.mealCaloriesText)
                            .font(CalorynTheme.bodyText.weight(.semibold).monospacedDigit())
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Text(row.mealName)
                            .font(CalorynTheme.caption.weight(.semibold))
                            .foregroundStyle(mealType.ink)
                    }

                    Image(systemName: "chevron.down")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .padding(.vertical, 12)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.expandedSectionTitle)
                        .font(CalorynTheme.caption.weight(.semibold))
                        .foregroundStyle(CalorynTheme.textSecondary)

                    if day.mealFoods.isEmpty {
                        Text(row.expandedEmptyText)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(day.mealFoods) { food in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(food.name)
                                    .font(CalorynTheme.cardSubtitle)
                                    .foregroundStyle(CalorynTheme.textPrimary)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                Text(food.calories.rounded().truncatedSafely.kcalFormatted)
                                    .font(CalorynTheme.cardSubtitle.monospacedDigit())
                                    .foregroundStyle(CalorynTheme.textSecondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(.bottom, 14)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("history.recurringPattern.supportingDay.details")
                .transition(.opacity)
            }
        }
    }
}

#if DEBUG
#Preview("Pattern Details") {
    HistoryPreviewFixtures.patternDetailPreview()
}
#endif
