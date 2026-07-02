import SwiftUI

struct NutriscoreDaySummary: View {
    let distribution: [(grade: String, count: Int)]

    private let gradeOrder = ["a", "b", "c", "d", "e"]

    private var orderedSegments: [(grade: String, count: Int)] {
        gradeOrder.compactMap { grade in
            distribution.first(where: { $0.grade.lowercased() == grade }).map { ($0.grade, $0.count) }
        }
    }

    private var totalCount: Int {
        distribution.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(CalorynTheme.compactIcon)
                    .foregroundStyle(CalorynTheme.sage)
                Text("Today's health")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            NutriscoreAllocationBar(segments: orderedSegments, total: totalCount)

            HStack(spacing: 12) {
                ForEach(orderedSegments, id: \.grade) { item in
                    HStack(spacing: 4) {
                        NutriscoreBadge(grade: item.grade)
                        Text("×\(item.count)")
                            .font(CalorynTheme.numericMicroCaption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .contentTransition(.numericText())
                    }
                }
                .animation(.smooth(duration: 0.35), value: orderedSegments.map { "\($0.grade)-\($0.count)" })
            }
        }
        .padding(CalorynTheme.cardPadding)
        .adaptiveGlassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let parts = distribution.map { "\($0.count) \($0.grade.uppercased())" }
        return "Today's health: \(parts.joined(separator: ", "))"
    }
}

private struct NutriscoreAllocationBar: View {
    let segments: [(grade: String, count: Int)]
    let total: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(segments, id: \.grade) { item in
                    if let color = CalorynTheme.nutriscoreColor(for: item.grade), total > 0 {
                        let fraction = Double(item.count) / Double(total)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(color)
                            .frame(width: max(0, geo.size.width * fraction))
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                    }
                }
            }
            .animation(.smooth(duration: 0.35), value: segments.map { "\($0.grade)-\($0.count)" })
        }
        .frame(height: 14)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 16) {
        NutriscoreDaySummary(distribution: [
            ("a", 2),
            ("b", 3),
            ("c", 1)
        ])
        NutriscoreDaySummary(distribution: [("e", 1)])
    }
    .padding()
}
