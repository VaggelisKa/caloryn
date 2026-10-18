import SwiftUI

/// A day's Nutri-Score grades as a row of chips — the grade's badge and how many items got
/// it — drawn straight on whatever it sits on (no card), wrapping onto a second line when
/// they do not fit. Today shows it under the hero and Nutrition Details under "Nutri-Score
/// today".
///
/// Grades come in a-to-e order whatever order `distribution` lists them in; a grade nothing
/// was logged for has no chip. The badge colours are the official Nutri-Score ones and do not
/// change with the appearance (`NutriscoreBadge`).
struct NutriscoreDaySummary: View {
    let distribution: [(grade: String, count: Int)]

    @ScaledMetric(relativeTo: .footnote) private var chipHeight: CGFloat = 30

    private var orderedSegments: [(grade: String, count: Int)] {
        NutriscoreDayDistribution.recognizedGrades.compactMap { grade in
            distribution.first(where: { $0.grade.lowercased() == grade }).map { ($0.grade, $0.count) }
        }
    }

    var body: some View {
        // Wraps rather than squeezing: with all five grades at the accessibility text sizes
        // the chips are wider than Today or Nutrition Details, and a row ran off the edge.
        ChipFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(orderedSegments, id: \.grade) { item in
                gradeChip(grade: item.grade, count: item.count)
            }
        }
        .animation(.smooth(duration: 0.35), value: orderedSegments.map { "\($0.grade)-\($0.count)" })
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func gradeChip(grade: String, count: Int) -> some View {
        HStack(spacing: 5) {
            NutriscoreBadge(grade: grade)

            Text("\(count)")
                .font(CalorynTheme.chipLabel)
                .fontWeight(.semibold)
                .foregroundStyle(CalorynTheme.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.leading, 6)
        .padding(.trailing, 10)
        .frame(minHeight: chipHeight)
        // Ink at 6%: a quiet chip that reads on paper, on a white sheet and in dark mode alike.
        .background(CalorynTheme.textPrimary.opacity(0.06), in: Capsule())
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
    }

    private var accessibilitySummary: String {
        let parts = orderedSegments.map { "\($0.count) \($0.grade.uppercased())" }
        return "Nutri-Score today: \(parts.joined(separator: ", "))"
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        NutriscoreDaySummary(distribution: [
            ("a", 4),
            ("c", 1),
            ("d", 1)
        ])
        NutriscoreDaySummary(distribution: [("e", 1)])
    }
    .padding()
    .background(CalorynTheme.pageBackground)
}
