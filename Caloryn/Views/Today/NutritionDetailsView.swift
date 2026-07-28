import SwiftUI

struct NutritionDetailsView: View {
    let date: Date
    let entries: [FoodLogEntry]
    let calorieBudget: ActivityCalorieBudget
    let nutrientTargets: [TrackedNutrient: Double]
    let nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind]

    @Environment(\.dismiss) private var dismiss

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

    private var calorieAccentColor: Color {
        color(for: NutritionDetailsSummary.calorieAccent(isOver: calorieBudget.isOver))
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

    private func color(for accent: NutritionDetailsSummary.CalorieAccent) -> Color {
        switch accent {
        case .withinBudget:
            CalorynTheme.sage
        case .overBudget:
            CalorynTheme.terracotta
        }
    }

    private func color(for group: NutrientDetailGroup) -> Color {
        switch group {
        case .protein:
            CalorynTheme.proteinColor
        case .carbs:
            CalorynTheme.carbColor
        case .fat:
            CalorynTheme.fatColor
        case .salt:
            CalorynTheme.stone
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CalorynTheme.cardSpacing) {
                    calorieSummary
                    dynamicTDEESummary
                    produceVarietyCard
                    allStatsGrid
                    detailSections
                    dataQualityNote
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.vertical, CalorynTheme.cardSpacing)
            }
            .calorynSheetCanvas()
            .navigationTitle("Nutrition Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.sage)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var calorieSummary: some View {
        let summary = summary

        return VStack(alignment: .leading, spacing: 14) {
            Text("Daily Nutrition")
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityIdentifier("nutritionDetails.title")

            HStack(alignment: .firstTextBaseline) {
                Text("\(calorieBudget.roundedConsumed)")
                    .font(CalorynTheme.displayNumber)
                    .foregroundStyle(calorieAccentColor)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("nutritionDetails.consumedCalories")

                Text("/ \(calorieBudget.adjustedTarget) kcal")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            progressBar(
                current: summary.totalCalories,
                target: Double(calorieBudget.adjustedTarget),
                color: calorieAccentColor
            )

            Divider()
                .foregroundStyle(CalorynTheme.stone.opacity(0.3))

            HStack(alignment: .top, spacing: 10) {
                summaryStat(
                    label: NutritionDetailsSummary.calorieSummaryLabel(isOver: calorieBudget.isOver),
                    value: "\(calorieBudget.isOver ? calorieBudget.overAmount : calorieBudget.remaining)",
                    detail: "kcal",
                    color: calorieAccentColor
                )

                verticalDivider

                summaryStat(
                    label: "Logged",
                    value: "\(summary.loggedItemCount)",
                    detail: summary.loggedItemsUnitText
                )

                verticalDivider

                summaryStat(
                    label: "Food Weight",
                    value: summary.totalPortionGramsText,
                    detail: "total"
                )
            }
        }
        .glassCard()
    }

    @ViewBuilder
    private var dynamicTDEESummary: some View {
        if shouldShowDynamicTDEE {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(CalorynTheme.carbColor.opacity(0.16))

                        Image(systemName: "flame.fill")
                            .font(CalorynTheme.inlineIcon)
                            .foregroundStyle(CalorynTheme.carbColor)
                    }
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-adjusted calories")
                            .font(CalorynTheme.itemTitle)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Text(ActivityCalorieBudget.dynamicEnergyPolicyText)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        if calorieBudget.isActivityLoading {
                            ProgressView()
                        }

                        Text(dynamicAdjustmentText)
                            .font(CalorynTheme.numericBody)
                            .foregroundStyle(
                                NutritionDetailsSummary.isDynamicAdjustmentMuted(calorieBudget.dynamicAdjustment)
                                    ? CalorynTheme.textSecondary
                                    : CalorynTheme.carbColor
                            )
                            .contentTransition(.numericText())
                    }
                }

                if let dynamicMessage = calorieBudget.dynamicStatusText {
                    dynamicStatusNotice(dynamicMessage)
                }

                Divider()
                    .foregroundStyle(CalorynTheme.stone.opacity(0.3))

                HStack(alignment: .top, spacing: 10) {
                    compactActivityStat(
                        label: "Baseline",
                        value: baselineText
                    )

                    verticalDivider

                    compactActivityStat(
                        label: "Today",
                        value: NutritionDetailsSummary.activeEnergyText(
                            activeEnergyKcal: calorieBudget.activeEnergyKcal
                        ),
                        color: CalorynTheme.carbColor
                    )

                    verticalDivider

                    compactActivityStat(
                        label: "Target",
                        value: calorieBudget.baseTarget.kcalFormatted
                    )
                }
            }
            .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
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
            CalorynTheme.terracotta
        case .informational:
            CalorynTheme.carbColor
        case .neutral:
            CalorynTheme.textSecondary
        }
    }

    private func dynamicStatusNotice(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(CalorynTheme.compactIcon)
                .foregroundStyle(dynamicStatusNoticeColor)
                .padding(.top, 1)
                .accessibilityHidden(true)

            Text(message)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dynamicStatusNoticeColor.opacity(0.10), in: .rect(cornerRadius: CalorynTheme.smallCornerRadius))
    }

    private func compactActivityStat(
        label: String,
        value: String,
        color: Color = CalorynTheme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(CalorynTheme.microCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var produceVarietyCard: some View {
        let summary = produceSummary
        let countColor = summary.totalCount > 0 ? CalorynTheme.fiberColor : CalorynTheme.textSecondary

        return HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(CalorynTheme.fiberColor.opacity(0.16))

                Image(systemName: "carrot.fill")
                    .font(CalorynTheme.inlineIcon)
                    .foregroundStyle(CalorynTheme.fiberColor)
            }
            .frame(width: 42, height: 42)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Fruit & veg variety")
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(summary.breakdownText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let preview = summary.previewText {
                    Text(preview)
                        .font(CalorynTheme.microCaption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.totalCount)")
                    .font(CalorynTheme.compactNumber)
                    .foregroundStyle(countColor)
                    .contentTransition(.numericText())

                Text("unique")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .accessibilityHidden(true)
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Fruit and veg variety, \(summary.totalCount) unique, \(summary.breakdownText)"
        )
    }

    private var verticalDivider: some View {
        Divider()
            .foregroundStyle(CalorynTheme.stone.opacity(0.3))
            .frame(height: 42)
    }

    private func summaryStat(
        label: String,
        value: String,
        detail: String,
        color: Color = CalorynTheme.textPrimary
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(CalorynTheme.microCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(value)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(detail)
                .font(CalorynTheme.microCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var allStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(CalorynTheme.sage)

                Text("All Stats")
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 142), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(allNutrientMetrics) { metric in
                    nutrientTile(metric)
                }
            }
        }
    }

    private var detailSections: some View {
        ForEach(NutrientDetailGroup.populatedGroups(in: summary.totalNutrition)) { populated in
            detailSection(
                populated.title,
                systemImage: populated.systemImage,
                color: color(for: populated.group),
                items: populated.items
            )
        }
    }

    private var dataQualityNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(CalorynTheme.compactIcon)
                .foregroundStyle(CalorynTheme.textSecondary)

            Text("Detailed nutrients come from product data and may be missing or inaccurate for some foods.")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func detailSection(_ title: String, systemImage: String, color: Color, items: [DetailNutrient]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(color)

                Text(title)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }

            VStack(spacing: 0) {
                ForEach(items) { item in
                    detailRow(label: item.label, value: item.formattedValue)
                        .padding(.vertical, 5)

                    if item.id != items.last?.id {
                        Divider()
                            .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textPrimary)

            Spacer()

            Text(value)
                .font(CalorynTheme.numericCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func nutrientTile(_ metric: TrackedNutrientMetric) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: metric.nutrient.systemImage)
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(metric.accentColor)

                Text(metric.nutrient.compactName)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(metric.formattedValue)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(metric.accentColor)
                .contentTransition(.numericText())

            if let target = metric.target, target > 0 {
                progressBar(current: metric.value, target: target, color: metric.accentColor)

                Text(metric.targetSummary ?? "of \(metric.nutrient.unit.formatted(target))")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("today")
                    .font(CalorynTheme.microCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .adaptiveGlassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.accessibilityLabel)
    }

    private func metric(for nutrient: TrackedNutrient, value: Double) -> TrackedNutrientMetric {
        TrackedNutrientMetric(
            nutrient: nutrient,
            value: value,
            target: nutrientTargets[nutrient],
            goalKind: nutrientTargets[nutrient] == nil ? nil : nutrientGoalKinds[nutrient, default: nutrient.defaultGoalKind]
        )
    }

    private func progressBar(current: Double, target: Double, color: Color) -> some View {
        let progress = NutritionDetailsSummary.progressFraction(current: current, target: target)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.15))

                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 7)
        .clipShape(Capsule())
        .accessibilityHidden(true)
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
