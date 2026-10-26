import SwiftUI

struct HistoryOverviewSection: View {
    let range: HistoryRange
    let summary: HistoryPeriodSummary
    let overview: HistoryOverviewSummary
    let today: Date

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 40

    private var averageLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headline

            HistoryDayPlateGrid(
                strip: HistoryDayPlateStrip(range: range, summary: summary, today: today),
                coverageText: overview.hasLoggedDays ? summary.coverageLevel.label : nil
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("history.goalSummary.card")
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 4) {
            if overview.hasLoggedDays {
                averageLayout {
                    Text(overview.averageValueText)
                        .font(CalorynTheme.heroNumber(size: heroSize))
                        .tracking(-heroSize * 0.01)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(overview.averageUnitText)
                        .font(CalorynTheme.cardSubtitle.weight(.medium))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(overview.averageAccessibilityLabel)
                .accessibilityIdentifier("history.goalSummary.metric.kcal/day-avg")
            } else {
                Text(overview.emptyHeadlineText)
                    .font(CalorynTheme.sectionTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }

            Text(overview.supportText)
                .font(CalorynTheme.cardSubtitle.monospacedDigit())
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("history.goalSummary.metric.days-logged")
        }
    }
}

struct HistoryDayPlateGrid: View {
    let strip: HistoryDayPlateStrip
    var coverageText: String? = nil

    @State private var gridWidth: CGFloat?

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(
                .flexible(minimum: 0, maximum: .infinity),
                spacing: HistoryDayPlateStrip.columnSpacing,
                alignment: .top
            ),
            count: strip.columnCount
        )
    }

    var body: some View {
        let plateSize = strip.plateSize(fittingWidth: gridWidth)

        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, alignment: .center, spacing: 10) {
                ForEach(strip.plates) { plate in
                    VStack(spacing: 6) {
                        CalorieMiniDonutView(
                            summary: plate.donut,
                            size: plateSize,
                            outline: outline(for: plate.outline),
                            uniformFill: CalorynTheme.dataSecondary
                        )

                        Text(plate.label)
                            .font(labelFont(for: plate.labelStyle))
                            .foregroundStyle(
                                plate.labelStyle == .regular
                                    ? CalorynTheme.textSecondary
                                    : CalorynTheme.textPrimary
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)

                        if plate.consistencyText != nil || plate.overGoalText != nil {
                            weekCaption(for: plate)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { gridWidth = width }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(strip.accessibilityLabel)
            .accessibilityValue(coverageText ?? "")
            .accessibilityIdentifier("history.goalSummary.metric.coverage")
            .contentShape(.accessibility, Rectangle().inset(by: -8))

            HistoryPlateLegend(
                ringKeyText: strip.ringKeyText,
                currentKeyText: strip.currentKeyText
            )
        }
    }

    private func weekCaption(for plate: HistoryDayPlateStrip.Plate) -> some View {
        VStack(spacing: 2) {
            if let consistencyText = plate.consistencyText {
                Text(consistencyText)
                    .font(CalorynTheme.numericMicroCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            if let overGoalText = plate.overGoalText {
                Text(overGoalText)
                    .font(CalorynTheme.microCaptionEmphasized)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func outline(for outline: HistoryDayPlateStrip.Outline) -> CalorieMiniDonutView.Outline {
        switch outline {
        case .standard: .standard
        case .over: .over
        case .current: .today
        }
    }

    private func labelFont(for style: HistoryDayPlateStrip.LabelStyle) -> Font {
        switch style {
        case .regular: CalorynTheme.microCaption
        case .emphasized: CalorynTheme.microCaptionEmphasized
        case .current: CalorynTheme.microCaptionEmphasized.weight(.bold)
        }
    }
}

private struct HistoryPlateLegend: View {
    let ringKeyText: String
    let currentKeyText: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { keys }
            VStack(alignment: .leading, spacing: 6) { keys }
        }
        .font(CalorynTheme.caption)
        .foregroundStyle(CalorynTheme.textSecondary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var keys: some View {
        key(text: "eaten") {
            Circle()
                .fill(CalorynTheme.dataSecondary)
                .padding(1)
        }

        key(text: ringKeyText) {
            Circle()
                .inset(by: 1.75)
                .stroke(CalorynTheme.dataPrimary, lineWidth: 1.5)
        }

        key(text: currentKeyText) {
            Circle()
                .inset(by: 1)
                .stroke(
                    CalorynTheme.dataPrimary.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1, dash: [1.5, 2])
                )
        }
    }

    private func key(text: String, @ViewBuilder glyph: () -> some View) -> some View {
        HStack(spacing: 5) {
            glyph()
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            Text(text)
        }
    }
}

struct HistoryOnTrackSection: View {
    let overview: HistoryOverviewSummary

    @ScaledMetric(relativeTo: .title) private var countSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HistorySectionTitle("On track")

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(overview.onTrackValueText)
                    .font(CalorynTheme.heroNumber(size: countSize))
                    .tracking(-countSize * 0.005)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(overview.onTrackSupportText)
                    .font(CalorynTheme.cardSubtitle)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(overview.onTrackAccessibilityLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
