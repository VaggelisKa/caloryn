import SwiftUI
import WidgetKit

struct DailyProgressEntry: TimelineEntry {
    let date: Date
    let snapshot: DailyWidgetSnapshot
    let isStale: Bool
}

struct DailyProgressProvider: TimelineProvider {
    private let store = WidgetSnapshotStore()

    func placeholder(in context: Context) -> DailyProgressEntry {
        DailyProgressEntry(
            date: .now,
            snapshot: .placeholder(),
            isStale: false
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (DailyProgressEntry) -> Void
    ) {
        completion(entry(at: .now, usePlaceholderWhenEmpty: context.isPreview))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<DailyProgressEntry>) -> Void
    ) {
        let now = Date.now
        let calendar = Calendar.current
        let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(86_400)

        let entries = [
            entry(at: now, usePlaceholderWhenEmpty: false),
            entry(at: nextDay, usePlaceholderWhenEmpty: false),
        ]
        let refreshDate = nextDay.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func entry(
        at date: Date,
        usePlaceholderWhenEmpty: Bool
    ) -> DailyProgressEntry {
        do {
            if let storedSnapshot = try store.load() {
                let display = storedSnapshot.displaySnapshot(at: date)
                return DailyProgressEntry(
                    date: date,
                    snapshot: display.snapshot,
                    isStale: display.isStale
                )
            }
        } catch {
            return DailyProgressEntry(
                date: date,
                snapshot: .unavailable(at: date),
                isStale: true
            )
        }

        return DailyProgressEntry(
            date: date,
            snapshot: usePlaceholderWhenEmpty ? .placeholder(at: date) : .unavailable(at: date),
            isStale: !usePlaceholderWhenEmpty
        )
    }
}

struct DailyProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetConstants.dailyProgressKind,
            provider: DailyProgressProvider()
        ) { entry in
            DailyProgressWidgetView(entry: entry)
                .fontDesign(.rounded)
                .containerBackground(for: .widget) {
                    WidgetTheme.background
                }
        }
        .configurationDisplayName("Today")
        .description("See today's calorie progress and quickly log a meal.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailyProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyProgressEntry

    var body: some View {
        Group {
            switch entry.snapshot.state {
            case .ready:
                if family == .systemMedium {
                    MediumProgressView(entry: entry)
                } else {
                    SmallProgressView(entry: entry)
                }
            case .needsOnboarding:
                WidgetMessageView(
                    icon: "leaf.fill",
                    title: "Start with Caloryn",
                    message: "Finish setup to see your daily progress."
                )
            case .unavailable:
                WidgetMessageView(
                    icon: "arrow.clockwise",
                    title: "Open Caloryn",
                    message: "Open the app to update today's progress."
                )
            }
        }
        .widgetURL(AppRoute.today.url)
    }
}

private struct SmallProgressView: View {
    let entry: DailyProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(isStale: entry.isStale)

            ProgressRing(summary: entry.snapshot.calories, compact: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ConsumedFooter(calories: entry.snapshot.calories)
        }
        .privacySensitive()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WidgetAccessibility.summary(for: entry.snapshot.calories))
    }
}

private struct MediumProgressView: View {
    let entry: DailyProgressEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetHeader(isStale: entry.isStale)

                ProgressRing(summary: entry.snapshot.calories, compact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ConsumedFooter(calories: entry.snapshot.calories)
            }
            .frame(maxWidth: .infinity)
            .privacySensitive()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(WidgetAccessibility.summary(for: entry.snapshot.calories))

            VStack(alignment: .leading, spacing: 8) {
                Text("Log a meal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(WidgetMeal.allCases) { meal in
                        QuickLogButton(meal: meal)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetHeader: View {
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: 4)

            if isStale {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Update needed")
            }
        }
    }
}

private struct ConsumedFooter: View {
    let calories: WidgetCalorieSummary

    var body: some View {
        Text("\(calories.consumed.formatted()) of \(calories.target.formatted()) kcal")
            .font(.caption.weight(.medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct QuickLogButton: View {
    let meal: WidgetMeal

    var body: some View {
        Link(destination: AppRoute.addFood(meal: meal).url) {
            VStack(spacing: 4) {
                Image(systemName: meal.systemImage)
                    .font(.caption.weight(.semibold))
                Text(meal.displayName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(WidgetTheme.sage)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(WidgetTheme.sage.opacity(0.14), in: .rect(cornerRadius: 12))
        }
        .accessibilityLabel("Log \(meal.displayName)")
    }
}

private struct ProgressRing: View {
    let summary: WidgetCalorieSummary
    let compact: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetTheme.ringTrack, lineWidth: compact ? 8 : 9)

            Circle()
                .trim(from: 0, to: summary.progress)
                .stroke(
                    summary.isOver ? WidgetTheme.terracotta : WidgetTheme.sage,
                    style: StrokeStyle(lineWidth: compact ? 8 : 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            VStack(spacing: 0) {
                Text(primaryValue.formatted())
                    .font((compact ? Font.title3 : .title2).weight(.bold).monospacedDigit())
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                Text(summary.isOver ? "over" : "left")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var primaryValue: Int {
        summary.isOver ? summary.overAmount : summary.remaining
    }
}

private enum WidgetAccessibility {
    static func summary(for calories: WidgetCalorieSummary) -> String {
        if calories.isOver {
            return "Today. \(calories.consumed) calories eaten. \(calories.overAmount) calories over target."
        }
        return "Today. \(calories.consumed) calories eaten. \(calories.remaining) calories remaining."
    }
}

private struct WidgetMessageView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(WidgetTheme.sage)
                .widgetAccentable()

            Spacer(minLength: 0)

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Previews

#Preview("Small · in progress", as: .systemSmall) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(date: .now, snapshot: .placeholder(), isStale: false)
}

#Preview("Small · over target", as: .systemSmall) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(
        date: .now,
        snapshot: DailyWidgetSnapshot(
            generatedAt: .now,
            dayStart: Calendar.current.startOfDay(for: .now),
            state: .ready,
            calories: WidgetCalorieSummary(consumed: 2_450, baseTarget: 2_000, target: 2_000)
        ),
        isStale: false
    )
}

#Preview("Small · stale", as: .systemSmall) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(date: .now, snapshot: .placeholder(), isStale: true)
}

#Preview("Medium · in progress", as: .systemMedium) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(date: .now, snapshot: .placeholder(), isStale: false)
}

#Preview("Medium · onboarding", as: .systemMedium) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(date: .now, snapshot: .needsOnboarding(at: .now), isStale: false)
}
