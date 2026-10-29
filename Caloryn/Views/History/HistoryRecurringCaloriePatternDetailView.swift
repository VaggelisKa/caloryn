import SwiftUI

struct HistoryRecurringCaloriePatternDetailView: View {
    let pattern: HistoryRecurringCaloriePattern
    let presentation: HistoryDetailPresentation

    @State private var expandedDayIDs: Set<Date>

    init(
        pattern: HistoryRecurringCaloriePattern,
        initiallyExpandedDayIDs: Set<Date> = [],
        presentation: HistoryDetailPresentation = .pushed
    ) {
        self.pattern = pattern
        self.presentation = presentation
        _expandedDayIDs = State(initialValue: initiallyExpandedDayIDs)
    }

    private var summary: HistoryRecurringCaloriePatternDetailSummary {
        HistoryRecurringCaloriePatternDetailSummary(
            kind: pattern.kind,
            outcome: pattern.outcome,
            weekdayName: pattern.weekdayName,
            mealType: pattern.mealType,
            supportingDayCount: pattern.supportingDays.count,
            cohortDayCount: pattern.cohortDayCount,
            outcomeComparisonCount: pattern.outcomeComparisonCount,
            outcomeComparisonDayCount: pattern.outcomeComparisonDayCount,
            eligibleDayCount: pattern.eligibleDayCount,
            windowDayCount: pattern.windowDayCount,
            supportingMealAverageCalories: pattern.supportingMealAverageCalories,
            comparisonMealAverageCalories: pattern.comparisonMealAverageCalories
        )
    }

    var body: some View {
        let summary = summary
        let days = pattern.supportingDaysNewestFirst

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if presentation == .inline {
                    HistoryDetailPaneTitle("Pattern")
                }

                HistoryPatternContextHeader(headline: pattern.headline, summary: summary)
                HistoryPatternOutcomeSection(summary: summary)
                HistoryPatternMealSection(summary: summary, mealType: pattern.mealType)

                VStack(alignment: .leading, spacing: 4) {
                    HistorySectionTitle(summary.daysListTitle)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(days) { day in
                            HistoryPatternSupportingDayRow(
                                day: day,
                                dateText: pattern.dayText(for: day.date),
                                mealType: pattern.mealType,
                                isExpanded: expandedDayIDs.contains(day.id),
                                action: { toggleDay(day) }
                            )

                            if day.id != days.last?.id {
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
        .historyDetailChrome("Pattern", presentation: presentation)
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
    let headline: String
    let summary: HistoryRecurringCaloriePatternDetailSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline)
                .font(CalorynTheme.sectionTitle.weight(.heavy))
                .tracking(-0.2)
                .foregroundStyle(CalorynTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HistoryRecurringCaloriePatternPhraseText(
                phrase: summary.mealLead,
                font: CalorynTheme.cardSubtitle,
                emphasisFont: CalorynTheme.cardSubtitle.weight(.semibold)
            )
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)

            Text(summary.basisText)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryPatternOutcomeSection: View {
    let summary: HistoryRecurringCaloriePatternDetailSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HistorySectionTitle(summary.outcomeTitle)

            layout {
                ForEach(summary.outcomeStats) { stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.value)
                            .font(CalorynTheme.compactNumber)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Text(stat.label)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryPatternMealSection: View {
    let summary: HistoryRecurringCaloriePatternDetailSummary
    let mealType: MealType

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HistorySectionTitle(summary.mealTitle)

            ForEach(summary.mealBars) { bar in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(bar.label)
                            .font(CalorynTheme.cardSubtitle.weight(.medium))
                            .foregroundStyle(bar.isPatternDays ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        Text(bar.valueText)
                            .font(CalorynTheme.cardSubtitle.weight(.semibold).monospacedDigit())
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }

                    HistoryPatternMealBar(ratio: bar.ratio, fill: mealType.fill)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct HistoryPatternMealBar: View {
    let ratio: Double
    let fill: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CalorynTheme.fillTrack)

                Capsule()
                    .fill(fill)
                    .frame(width: geometry.size.width * ratio)
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

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

                        HistoryRecurringCaloriePatternPhraseText(
                            phrase: row.totals,
                            font: CalorynTheme.caption.monospacedDigit(),
                            emphasisFont: CalorynTheme.caption.weight(.semibold).monospacedDigit()
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(row.mealName)
                            .font(CalorynTheme.caption.weight(.semibold))
                            .foregroundStyle(mealType.ink)

                        Text(row.mealCaloriesText)
                            .font(CalorynTheme.bodyText.weight(.semibold).monospacedDigit())
                            .foregroundStyle(CalorynTheme.textPrimary)
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
