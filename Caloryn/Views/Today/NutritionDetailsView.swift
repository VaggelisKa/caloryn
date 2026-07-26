import SwiftUI

struct NutritionDetailsView: View {
    let date: Date
    let entries: [FoodLogEntry]
    let calorieBudget: ActivityCalorieBudget
    let nutrientTargets: [TrackedNutrient: Double]
    let nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind]

    @Environment(\.dismiss) private var dismiss

    private var totalNutrition: NutritionValues {
        entries.reduce(.zero) { $0 + $1.nutrition }
    }

    private var totalCalories: Double {
        totalNutrition.calories
    }

    private var totalPortionGrams: Double {
        entries.reduce(0) { $0 + $1.portionGrams }
    }

    private var roundedCalories: Int {
        calorieBudget.roundedConsumed
    }

    private var remainingCalories: Int {
        calorieBudget.remaining
    }

    private var overCalories: Int {
        calorieBudget.overAmount
    }

    private var calorieAccentColor: Color {
        calorieBudget.isOver ? CalorynTheme.terracotta : CalorynTheme.sage
    }

    private var shouldShowDynamicTDEE: Bool {
        calorieBudget.isDynamicModeRequested
            || calorieBudget.activeEnergyKcal > 0
            || calorieBudget.dynamicAdjustment != 0
            || calorieBudget.activityMessage != nil
    }

    private var allNutrientMetrics: [TrackedNutrientMetric] {
        TrackedNutrient.allCases.map { nutrient in
            metric(for: nutrient, value: nutrient.value(in: entries))
        }
    }

    private var produceSummary: ProduceVarietySummary {
        ProduceVarietySummary(entries: entries)
    }

    private var proteinDetails: [DetailNutrient] {
        [
            detail("casein", "Casein", \.caseinG),
            detail("serum-proteins", "Serum proteins", \.serumProteinsG)
        ].compactMap { $0 }
    }

    private var carbDetails: [DetailNutrient] {
        [
            detail("sucrose", "Sucrose", \.sucroseG),
            detail("glucose", "Glucose", \.glucoseG),
            detail("fructose", "Fructose", \.fructoseG),
            detail("lactose", "Lactose", \.lactoseG),
            detail("maltose", "Maltose", \.maltoseG),
            detail("maltodextrins", "Maltodextrins", \.maltodextrinsG),
            detail("starch", "Starch", \.starchG),
            detail("polyols", "Polyols", \.polyolsG)
        ].compactMap { $0 }
    }

    private var fatDetails: [DetailNutrient] {
        [
            detail("trans-fat", "Trans fat", \.transFatG),
            detail("monounsaturated-fat", "Monounsaturated", \.monounsaturatedFatG),
            detail("polyunsaturated-fat", "Polyunsaturated", \.polyunsaturatedFatG),
            detail("omega-3-fat", "Omega-3 fat", \.omega3FatG),
            detail("omega-6-fat", "Omega-6 fat", \.omega6FatG),
            detail("omega-9-fat", "Omega-9 fat", \.omega9FatG)
        ].compactMap { $0 }
    }

    private var saltDetails: [DetailNutrient] {
        [
            detail("salt", "Salt equivalent", \.saltG)
        ].compactMap { $0 }
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
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }

    private var calorieSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Nutrition")
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)

            HStack(alignment: .firstTextBaseline) {
                Text("\(roundedCalories)")
                    .font(CalorynTheme.displayNumber)
                    .foregroundStyle(calorieAccentColor)
                    .contentTransition(.numericText())

                Text("/ \(calorieBudget.adjustedTarget) kcal")
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            progressBar(
                current: totalCalories,
                target: Double(calorieBudget.adjustedTarget),
                color: calorieAccentColor
            )

            Divider()
                .foregroundStyle(CalorynTheme.stone.opacity(0.3))

            HStack(alignment: .top, spacing: 10) {
                summaryStat(
                    label: calorieBudget.isOver ? "Over" : "Remaining",
                    value: "\(calorieBudget.isOver ? overCalories : remainingCalories)",
                    detail: "kcal",
                    color: calorieAccentColor
                )

                verticalDivider

                summaryStat(
                    label: "Logged",
                    value: "\(entries.count)",
                    detail: entries.count == 1 ? "item" : "items"
                )

                verticalDivider

                summaryStat(
                    label: "Food Weight",
                    value: totalPortionGrams.macroFormatted,
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
                            .foregroundStyle(calorieBudget.dynamicAdjustment < 0 ? CalorynTheme.textSecondary : CalorynTheme.carbColor)
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
                        value: Int(calorieBudget.activeEnergyKcal.rounded()).kcalFormatted,
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
        guard let baseline = calorieBudget.activityBaselineKcal else {
            return "-"
        }

        return Int(baseline.rounded()).kcalFormatted
    }

    private var dynamicAdjustmentText: String {
        let adjustment = calorieBudget.dynamicAdjustment
        if adjustment > 0 {
            return "+\(adjustment.kcalFormatted)"
        }
        if adjustment < 0 {
            return "-\(abs(adjustment).kcalFormatted)"
        }
        return "0 kcal"
    }

    private var dynamicStatusNoticeColor: Color {
        switch calorieBudget.dynamicStatus {
        case .unavailable:
            CalorynTheme.terracotta
        case .learning:
            CalorynTheme.carbColor
        case .staticEstimate, .ready:
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

    @ViewBuilder
    private var detailSections: some View {
        if !proteinDetails.isEmpty {
            detailSection("Protein Details", systemImage: "dumbbell.fill", color: CalorynTheme.proteinColor, items: proteinDetails)
        }

        if !carbDetails.isEmpty {
            detailSection("Carb Details", systemImage: "fork.knife", color: CalorynTheme.carbColor, items: carbDetails)
        }

        if !fatDetails.isEmpty {
            detailSection("Fat Details", systemImage: "drop.fill", color: CalorynTheme.fatColor, items: fatDetails)
        }

        if !saltDetails.isEmpty {
            detailSection("Salt", systemImage: "s.circle.fill", color: CalorynTheme.stone, items: saltDetails)
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
                    detailRow(label: item.label, value: formattedDetailValue(item))
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
        let progress = target > 0 ? min(max(current / target, 0), 1) : 0

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

    private func detail(
        _ id: String,
        _ label: String,
        _ keyPath: KeyPath<NutritionValues, Double?>,
        unit: DetailNutrient.Unit = .grams
    ) -> DetailNutrient? {
        guard let value = totalNutrition[keyPath: keyPath] else { return nil }
        return DetailNutrient(id: id, label: label, value: value, unit: unit)
    }

    private func formattedDetailValue(_ item: DetailNutrient) -> String {
        switch item.unit {
        case .grams:
            item.value.macroFormatted
        case .milligramsFromGrams:
            "\(Int((item.value * 1000).rounded()))mg"
        }
    }
}

private struct DetailNutrient: Identifiable {
    enum Unit {
        case grams
        case milligramsFromGrams
    }

    let id: String
    let label: String
    let value: Double
    let unit: Unit
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
