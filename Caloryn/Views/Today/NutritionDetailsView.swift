import SwiftUI

struct NutritionDetailsView: View {
    let date: Date
    let entries: [FoodLogEntry]
    let calorieBudget: CalorieBudget
    let nutrientTargets: [TrackedNutrient: Double]
    let nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("showNutriscore") private var showNutriscore = true
    @State private var exportedDay: ExportedDay?

    private struct ExportedDay: Identifiable {
        let url: URL
        var id: URL { url }
    }

    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 52
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

    private var allNutrientMetrics: [TrackedNutrientMetric] {
        TrackedNutrientMetric.metrics(in: entries, targets: nutrientTargets, goalKinds: nutrientGoalKinds)
    }

    private var produceSummary: ProduceVarietySummary {
        ProduceVarietySummary(entries: entries)
    }

    private var nutriscoreGrades: [String?] {
        entries.map(\.historicalNutriscoreGrade)
    }

    private var exportReport: DayExportReport {
        DayExportReport(
            day: date,
            entries: entries.map {
                DayExportReport.Entry(
                    mealType: $0.mealType,
                    foodName: $0.historicalFoodName,
                    portionGrams: $0.portionGrams,
                    macros: DayExportReport.Macros(
                        calories: $0.calories,
                        proteinG: $0.proteinG,
                        carbsG: $0.carbsG,
                        fatG: $0.fatG
                    ),
                    createdAt: $0.createdAt
                )
            },
            targets: DayExportReport.Targets(
                calories: calorieBudget.target,
                proteinG: nutrientTargets[.protein],
                carbsG: nutrientTargets[.carbs],
                fatG: nutrientTargets[.fat]
            )
        )
    }

    private func share(_ url: URL?) {
        guard let url else { return }
        exportedDay = ExportedDay(url: url)
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

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            share(DayExportPDF.exportURL(for: exportReport))
                        } label: {
                            Label("PDF", systemImage: "doc.text")
                        }
                        .accessibilityIdentifier("nutritionDetails.exportDay.pdf")

                        Button {
                            share(CSVExporter.exportURL(from: entries, fileName: exportReport.fileName))
                        } label: {
                            Label("CSV", systemImage: "tablecells")
                        }
                        .accessibilityIdentifier("nutritionDetails.exportDay.csv")
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(entries.isEmpty ? CalorynTheme.textTertiary : CalorynTheme.accent)
                    }
                    .disabled(entries.isEmpty)
                    .accessibilityLabel("Share day")
                    .accessibilityIdentifier("nutritionDetails.exportDay")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.accent)
                    }
                    .accessibilityLabel("Close")
                    .accessibilityIdentifier("nutritionDetails.close")
                }
            }
            .sheet(item: $exportedDay) { exported in
                ShareSheet(url: exported.url)
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
                        target: calorieBudget.target,
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

    private func targetsSection(_ rows: [NutritionDetailsSections.TargetRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Against your targets")

            NutrientTargetRowsView(rows: rows)
        }
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
                        .foregroundStyle(CalorynTheme.mealInk(.snack))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .frame(minHeight: chipHeight)
                        .background(CalorynTheme.mealWash(.snack), in: Capsule())
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
                                // swiftlint:disable:next text_token_as_shape
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
                .fill(CalorynTheme.separator)
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
}

#Preview("Nutrition Details") {
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
        calorieBudget: CalorieBudget(consumed: 374, target: 1_900),
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
