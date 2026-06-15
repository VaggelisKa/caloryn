import SwiftUI

struct DaySummaryRow: View {
    let date: Date
    let totalCalories: Double
    let target: Int
    let entryCount: Int

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(totalCalories / Double(target), 1.0)
    }

    private var isOver: Bool {
        totalCalories > Double(target)
    }

    private var barColor: Color {
        if entryCount == 0 { return CalorynTheme.stone.opacity(0.3) }
        return isOver ? CalorynTheme.terracotta : CalorynTheme.sage
    }

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.shortFormatted)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(entryCount == 0 ? "No entries" : "\(entryCount) items")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            .frame(width: 90, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(barColor.opacity(0.15))

                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 12)
            .clipShape(Capsule())

            Text(entryCount == 0 ? "—" : "\(Int(totalCalories))")
                .font(CalorynTheme.numericBody)
                .foregroundStyle(entryCount == 0 ? CalorynTheme.textSecondary : CalorynTheme.textPrimary)
                .frame(width: 55, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, CalorynTheme.cardPadding)
        .adaptiveGlassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(date.shortFormatted), \(entryCount == 0 ? "no entries" : "\(Int(totalCalories)) calories, \(entryCount) items")")
    }
}

#Preview {
    VStack(spacing: 10) {
        DaySummaryRow(date: .now, totalCalories: 1850, target: 2000, entryCount: 8)
        DaySummaryRow(date: .now.yesterday, totalCalories: 2200, target: 2000, entryCount: 12)
        DaySummaryRow(date: .now.yesterday.yesterday, totalCalories: 0, target: 2000, entryCount: 0)
    }
    .padding()
}
