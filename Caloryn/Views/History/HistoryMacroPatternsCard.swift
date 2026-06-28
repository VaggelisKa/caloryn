import SwiftUI

struct HistoryMacroPatternsCard: View {
    let patterns: [HistoryMacroPattern]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Macro Patterns")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .textCase(.uppercase)

                if let summaryText {
                    Text(summaryText)
                        .font(.system(.subheadline))
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            VStack(spacing: 14) {
                ForEach(patterns) { pattern in
                    HistoryMacroPatternRow(pattern: pattern)

                    if pattern.id != patterns.last?.id {
                        Divider()
                    }
                }
            }
        }
        .glassCard()
    }

    private var summaryText: String? {
        let loggedPatterns = patterns.filter { $0.current.loggedDays > 0 }
        guard let weakest = loggedPatterns.min(by: { $0.current.hitDays < $1.current.hitDays }) else {
            return nil
        }

        return "\(weakest.nutrient.compactName) was the least consistent macro at \(weakest.current.hitDays) of \(weakest.current.loggedDays) logged days."
    }
}

private struct HistoryMacroPatternRow: View {
    let pattern: HistoryMacroPattern

    private var hitRatio: Double {
        guard pattern.current.loggedDays > 0 else { return 0 }
        return Double(pattern.current.hitDays) / Double(pattern.current.loggedDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: pattern.nutrient.systemImage)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(pattern.nutrient.color)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.nutrient.displayName)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text("\(pattern.current.hitDays) of \(pattern.current.loggedDays) days \(hitLabel)")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(pattern.current.averageValue.macroFormatted)
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text(deltaText)
                        .font(CalorynTheme.numericCaption)
                        .foregroundStyle(deltaColor)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(pattern.nutrient.color.opacity(0.14))

                    Capsule()
                        .fill(pattern.nutrient.color)
                        .frame(width: geo.size.width * hitRatio)
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var hitLabel: String {
        switch pattern.goalKind {
        case .minimum:
            "hit"
        case .target:
            "on target"
        case .maximum:
            "under max"
        }
    }

    private var deltaText: String {
        guard pattern.previous.loggedDays > 0 else { return "No prev data" }

        let rounded = Int(pattern.averageValueDelta.rounded())
        if rounded > 0 { return "+\(rounded)g vs prev" }
        if rounded < 0 { return "\(rounded)g vs prev" }
        return "No avg change"
    }

    private var deltaColor: Color {
        guard pattern.previous.loggedDays > 0 else {
            return CalorynTheme.textSecondary
        }

        guard Int(pattern.averageValueDelta.rounded()) != 0 else {
            return CalorynTheme.textSecondary
        }

        switch pattern.goalKind {
        case .minimum:
            return pattern.averageValueDelta > 0 ? CalorynTheme.sage : CalorynTheme.terracotta
        case .target:
            return CalorynTheme.textSecondary
        case .maximum:
            return pattern.averageValueDelta < 0 ? CalorynTheme.sage : CalorynTheme.terracotta
        }
    }

    private var accessibilityLabel: String {
        "\(pattern.nutrient.displayName), \(pattern.current.hitDays) of \(pattern.current.loggedDays) logged days \(hitLabel), average \(pattern.current.averageValue.macroFormatted)"
    }
}
