import SwiftUI

struct NutritionDetailsView: View {
    let date: Date
    let entries: [FoodLogEntry]
    let calorieBudget: ActivityCalorieBudget
    let nutrientTargets: [TrackedNutrient: Double]
    let nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("showNutriscore") private var showNutriscore = true

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 52
    @ScaledMetric(relativeTo: .subheadline) private var barHeight: CGFloat = 8
    @ScaledMetric(relativeTo: .footnote) private var chipHeight: CGFloat = 30

    private var summary: NutritionDetailsSummary {
        NutritionDetailsSummary(
            entries: entries.map {
                NutritionDetailsSummary.Entry(
                    nutrition: $0.nutrition,
                    portionGrams: $0.portionGrams
                )
            }
        )
    }

    private var shouldShowDynamicTDEE: Bool {
        NutritionDetailsSummary.showsDynamicTDEE(
            isDynamicModeRequested: calorieBudget.isDynamicModeRequested,
            activeEnergyKcal: calorieBudget.activeEnergyKcal,
            dynamicAdjustment: calorieBudget.dynamicAdjustment,
            hasActivityMessage: calorieBudget.activityMessage != nil
        )
    }

    private var allNutrientMetrics: [TrackedNutrientMetric] {
        TrackedNutrient.allCases.map { nutrient in
            metric(for: nutrient, value: nutrient.value(in: entries))
        }
    }

    private var produceSummary: ProduceVarietySummary {
        ProduceVarietySummary(entries: entries)
    }

    private var nutriscoreGrades: [String?] {
        entries.map(\.historicalNutriscoreGrade)
    }

    var body: some View {
        let summary = summary
        let sections = NutritionDetailsSections(
            metrics: allNutrientMetrics,
            details: NutrientDetailGroup.populatedGroups(in: summary.totalNutrition)
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    calorieSummary(summary)
                    dynamicTDEESummary

                    if !sections.targets.isEmpty {
                        targetsSection(sections.targets)
                    }

                    produceSection

                    if showNutriscore, NutriscoreDayDistribution.hasData(nutriscoreGrades) {
                        nutriscoreSection
                    }

                    if !sections.amounts.isEmpty {
                        amountSection("Also in today's food", rows: sections.amounts)
                    }

                    ForEach(sections.breakdowns) { breakdown in
                        amountSection(breakdown.title, rows: breakdown.rows)
                    }

                    dataQualityNote
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 22)
                .padding(.bottom, 32)
            }
            .calorynSheetCanvas()
            .navigationTitle(DayTitle.text(for: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(DayTitle.text(for: date))
                        .font(CalorynTheme.sectionHeaderTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)
                        .accessibilityLabel("Nutrition details, \(DayTitle.accessibilityLabel(for: date))")
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("nutritionDetails.title")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("nutritionDetails.close")
                }
            }
        }
    }

    private func calorieSummary(_ summary: NutritionDetailsSummary) -> some View {
        let isStacked = dynamicTypeSize.isAccessibilitySize
        let layout = isStacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .bottom, spacing: 10))

        return layout {
            Text("\(calorieBudget.roundedConsumed)")
                .font(CalorynTheme.heroNumber(size: numberSize))
                .tracking(-numberSize * 0.01)
                .foregroundStyle(CalorynTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .accessibilityLabel("\(calorieBudget.roundedConsumed) kcal eaten")
                .accessibilityIdentifier("nutritionDetails.consumedCalories")

            VStack(alignment: .leading, spacing: 2) {
                Text(
                    NutritionDetailsSections.calorieTargetText(
                        adjustedTarget: calorieBudget.adjustedTarget,
                        isOver: calorieBudget.isOver,
                        overAmount: calorieBudget.overAmount
                    )
                )
                .font(TodayPlateFont.detailsNumberCaption)
                .foregroundStyle(CalorynTheme.textPrimary)

                Text(NutritionDetailsSections.foodAmountText(summary: summary))
                    .font(TodayPlateFont.detailsNote)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .lineLimit(isStacked ? nil : 2)
            .fixedSize(horizontal: false, vertical: isStacked)
            .padding(.bottom, isStacked ? 0 : 4)
        }
    }

    @ViewBuilder
    private var dynamicTDEESummary: some View {
        if shouldShowDynamicTDEE {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sectionTitle("Auto-adjusted calories")

                    Spacer(minLength: 8)

                    if calorieBudget.isActivityLoading {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Text(dynamicAdjustmentText)
                        .font(TodayPlateFont.detailsRowValue)
                        .foregroundStyle(
                            NutritionDetailsSummary.isDynamicAdjustmentMuted(calorieBudget.dynamicAdjustment)
                                ? CalorynTheme.textSecondary
                                : CalorynTheme.textPrimary
                        )
                        .contentTransition(.numericText())
                }

                Text(ActivityCalorieBudget.dynamicEnergyPolicyText)
                    .font(TodayPlateFont.detailsNote)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let dynamicMessage = calorieBudget.dynamicStatusText {
                    dynamicStatusNotice(dynamicMessage)
                }

                VStack(spacing: 0) {
                    amountRow(label: "Baseline", value: baselineText)
                    amountRow(
                        label: "Today",
                        value: NutritionDetailsSummary.activeEnergyText(
                            activeEnergyKcal: calorieBudget.activeEnergyKcal
                        )
                    )
                    amountRow(label: "Target", value: calorieBudget.baseTarget.kcalFormatted)
                }
                .padding(.top, 4)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Auto-adjusted calories, \(baselineText) baseline, \(calorieBudget.activeEnergyKcal.kcalFormatted) today, \(dynamicAdjustmentText) adjustment, \(calorieBudget.adjustedTarget.kcalFormatted) target")
        }
    }

    private var baselineText: String {
        NutritionDetailsSummary.baselineText(
            activityBaselineKcal: calorieBudget.activityBaselineKcal
        )
    }

    private var dynamicAdjustmentText: String {
        NutritionDetailsSummary.dynamicAdjustmentText(calorieBudget.dynamicAdjustment)
    }

    private var dynamicStatusNoticeColor: Color {
        switch NutritionDetailsSummary.statusNoticeStyle(for: calorieBudget.dynamicStatus) {
        case .warning:
            CalorynTheme.textPrimary
        case .informational, .neutral:
            CalorynTheme.textSecondary
        }
    }

    private func dynamicStatusNotice(_ message: String) -> some View {
        Text(message)
            .font(TodayPlateFont.detailsNote)
            .foregroundStyle(dynamicStatusNoticeColor)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CalorynTheme.surface,
                in: RoundedRectangle(cornerRadius: CalorynTheme.smallCornerRadius, style: .continuous)
            )
    }

    private func targetsSection(_ rows: [NutritionDetailsSections.TargetRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Against your targets")

            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.name)
                            .font(TodayPlateFont.detailsRow)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Spacer(minLength: 0)

                        targetFigures(row)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.numericText())
                    }

                    progressBar(row.progress)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.accessibilityLabel)
            }
        }
    }

    private func targetFigures(_ row: NutritionDetailsSections.TargetRow) -> Text {
        let value = Text(row.valueText)
            .font(TodayPlateFont.detailsRowValue)
            .fontWeight(row.isOverMaximum ? .bold : .semibold)
            .foregroundStyle(CalorynTheme.textPrimary)
        let target = Text(row.targetText)
            .font(TodayPlateFont.detailsRow)
            .foregroundStyle(CalorynTheme.textSecondary)

        guard let overText = row.overText else {
            return Text("\(value) \(target)")
        }
        let over = Text(", \(overText)")
            .font(TodayPlateFont.detailsRowValue)
            .foregroundStyle(CalorynTheme.textPrimary)
        return Text("\(value) \(target)\(over)")
    }

    private func progressBar(_ progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CalorynTheme.hairline)

                Capsule()
                    .fill(CalorynTheme.textPrimary)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: barHeight)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private var produceSection: some View {
        let produce = produceSummary

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Fruit and veg",
                trailing: NutritionDetailsSections.produceCountText(produce.totalCount)
            )

            ChipFlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(produce.items) { item in
                    Text(item.name)
                        .font(CalorynTheme.chipLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(CalorynTheme.mealSnackInk)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minHeight: chipHeight)
                        .background(CalorynTheme.mealSnack.opacity(0.16), in: Capsule())
                }

                if let remaining = NutritionDetailsSections.produceRemainingText(produce.totalCount) {
                    Text(remaining)
                        .font(CalorynTheme.chipLabel)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minHeight: chipHeight)
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    CalorynTheme.textPrimary.opacity(0.25),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                                )
                        }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Fruit and veg variety, \(produce.totalCount) unique, \(produce.breakdownText)"
        )
    }

    private var nutriscoreSection: some View {
        let distribution = NutriscoreDayDistribution.distribution(of: nutriscoreGrades)
        let graded = distribution.reduce(0) { $0 + $1.count }

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                "Nutri-Score today",
                trailing: NutritionDetailsSections.nutriscoreGradedText(graded: graded, total: entries.count)
            )

            NutriscoreDaySummary(distribution: distribution)
        }
    }

    private func amountSection(_ title: String, rows: [NutritionDetailsSections.AmountRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(title)
                .padding(.bottom, 6)

            ForEach(rows) { row in
                amountRow(label: row.label, value: row.valueText)
            }
        }
    }

    private func amountRow(label: String, value: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(CalorynTheme.hairline)
                .frame(height: CalorynTheme.hairlineWidth)

            HStack {
                Text(label)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text(value)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .font(TodayPlateFont.detailsRow)
            .padding(.vertical, 8)
        }
        .accessibilityElement(children: .combine)
    }

    private var dataQualityNote: some View {
        Text("Detailed nutrients come from product data and may be missing or inaccurate for some foods.")
            .font(TodayPlateFont.detailsFootnote)
            .foregroundStyle(CalorynTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("nutritionDetails.dataQualityNote")
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TodayPlateFont.detailsSectionTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private func sectionHeader(_ title: String, trailing: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            sectionTitle(title)

            Spacer(minLength: 8)

            Text(trailing)
                .font(TodayPlateFont.detailsNote)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)
        }
    }

    private func metric(for nutrient: TrackedNutrient, value: Double) -> TrackedNutrientMetric {
        TrackedNutrientMetric(
            nutrient: nutrient,
            value: value,
            target: nutrientTargets[nutrient],
            goalKind: nutrientTargets[nutrient] == nil ? nil : nutrientGoalKinds[nutrient, default: nutrient.defaultGoalKind]
        )
    }
}

#Preview("Nutrition Details - Auto-adjust") {
    let oatmeal = FoodItem(
        name: "Oatmeal",
        caloriesPer100g: 389,
        proteinPer100g: 16.9,
        carbsPer100g: 66.3,
        fatPer100g: 6.9,
        fiberPer100g: 10.6,
        sugarsPer100g: 0.9,
        sucrosePer100g: 0.2,
        starchPer100g: 55,
        saturatedFatPer100g: 1.2,
        omega3FatPer100g: 0.1,
        saltPer100g: 0.02
    )
    let apple = FoodItem(
        name: "Apple",
        caloriesPer100g: 52,
        proteinPer100g: 0.3,
        carbsPer100g: 14,
        fatPer100g: 0.2,
        fiberPer100g: 2.4,
        sugarsPer100g: 10.4,
        glucosePer100g: 2.4,
        fructosePer100g: 5.9,
        insolubleFiberPer100g: 1.8,
        produceKind: .fruit
    )
    NutritionDetailsView(
        date: .now,
        entries: [
            FoodLogEntry(date: .now, mealType: .breakfast, foodItem: oatmeal, portionGrams: 80),
            FoodLogEntry(date: .now, mealType: .snack, foodItem: apple, portionGrams: 120)
        ],
        calorieBudget: ActivityCalorieBudget(
            consumed: 374,
            staticTarget: 1900,
            bmr: 1_600,
            calorieDeficit: 300,
            activeEnergyKcal: 430,
            recentActiveEnergySamples: previewNutritionActivitySamples,
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        ),
        nutrientTargets: [
            .protein: 120,
            .carbs: 200,
            .fat: 65,
            .fiber: 30
        ],
        nutrientGoalKinds: [
            .protein: .minimum,
            .carbs: .target,
            .fat: .target,
            .fiber: .minimum
        ]
    )
}

private let previewNutritionActivitySamples: [DailyActiveEnergySample] = (1...10).compactMap { offset in
    guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date.now.startOfDay) else {
        return nil
    }

    return DailyActiveEnergySample(date: date, activeEnergyKcal: 280)
}
