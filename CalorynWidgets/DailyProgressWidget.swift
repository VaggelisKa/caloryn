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
                .containerBackground(for: .widget) {
                    CalorynTheme.backgroundPrimary
                }
        }
        .configurationDisplayName("Today")
        .description("See today's plate and quickly log a meal.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct DailyProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: DailyProgressEntry

    var body: some View {
        Group {
            switch entry.snapshot.state {
            case .ready:
                switch family {
                case .systemLarge:
                    LargeProgressView(entry: entry)
                case .systemMedium:
                    MediumProgressView(entry: entry)
                default:
                    SmallProgressView(entry: entry)
                }
            case .needsOnboarding:
                WidgetMessageView(
                    title: "Start with Caloryn",
                    message: "Finish setup to see your day."
                )
            case .unavailable:
                WidgetMessageView(
                    title: "Open Caloryn",
                    message: "Open the app to update today's plate."
                )
            }
        }
        .widgetURL(AppRoute.today.url)
    }
}

private struct SmallProgressView: View {
    let entry: DailyProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader(isStale: entry.isStale)

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                WidgetPlateView(summary: WidgetPlateSummary(calories: entry.snapshot.calories), size: 64)
                WidgetPlateFigures(calories: entry.snapshot.calories, numberFont: .title2.weight(.heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 4)

            WidgetEatenLine(calories: entry.snapshot.calories)
        }
        .privacySensitive()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(WidgetAccessibility.summary(for: entry.snapshot.calories))
    }
}

private struct MediumProgressView: View {
    let entry: DailyProgressEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                WidgetHeader(isStale: entry.isStale)

                Spacer(minLength: 4)

                HStack(spacing: 10) {
                    WidgetPlateView(summary: WidgetPlateSummary(calories: entry.snapshot.calories), size: 72)
                    WidgetPlateFigures(calories: entry.snapshot.calories, numberFont: .title.weight(.heavy))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 4)

                WidgetEatenLine(calories: entry.snapshot.calories)
            }
            .frame(maxWidth: .infinity)
            .privacySensitive()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(WidgetAccessibility.summary(for: entry.snapshot.calories))

            Rectangle()
                .fill(CalorynTheme.separator)
                .frame(width: 1)

            QuickLogSection()
                .frame(maxWidth: .infinity)
        }
    }
}

private struct LargeProgressView: View {
    let entry: DailyProgressEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                WidgetHeader(isStale: entry.isStale)

                HStack(alignment: .center, spacing: 14) {
                    WidgetPlateView(summary: WidgetPlateSummary(calories: entry.snapshot.calories), size: 124)

                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 0) {
                            WidgetPlateFigures(calories: entry.snapshot.calories, numberFont: .largeTitle.weight(.heavy))
                            WidgetEatenLine(calories: entry.snapshot.calories)
                        }
                        WidgetPlateLegend(calories: entry.snapshot.calories)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .privacySensitive()
            .accessibilityElement(children: .combine)
            .accessibilityLabel(WidgetAccessibility.summary(for: entry.snapshot.calories, withMeals: true))

            Rectangle()
                .fill(CalorynTheme.separator)
                .frame(height: 1)

            QuickLogSection()
        }
    }
}

private struct QuickLogSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetSectionTitle(title: "Log a meal")

            WidgetQuickLogRows()
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WidgetHeader: View {
    let isStale: Bool

    var body: some View {
        HStack(spacing: 4) {
            WidgetSectionTitle(title: "Today")

            Spacer(minLength: 4)

            if isStale {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityLabel("Update needed")
            }
        }
    }
}

enum WidgetAccessibility {
    static func summary(for calories: WidgetCalorieSummary, withMeals: Bool = false) -> String {
        var parts = ["Today.", "\(calories.consumed) calories eaten."]
        if calories.isOver {
            parts.append("\(calories.overAmount) calories over target.")
        } else {
            parts.append("\(calories.remaining) calories remaining.")
        }
        if withMeals {
            for meal in WidgetMeal.allCases {
                if let kcal = calories.kcal(for: meal) {
                    parts.append("\(meal.displayName) \(kcal) calories.")
                } else {
                    parts.append("\(meal.displayName) not logged.")
                }
            }
        }
        return parts.joined(separator: " ")
    }
}

private struct WidgetMessageView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)

            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(CalorynTheme.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

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
            calories: WidgetCalorieSummary(
                consumed: 2_450,
                target: 2_000,
                mealCalories: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 228]
            )
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

#Preview("Large · in progress", as: .systemLarge) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(date: .now, snapshot: .placeholder(), isStale: false)
}

#Preview("Large · over target", as: .systemLarge) {
    DailyProgressWidget()
} timeline: {
    DailyProgressEntry(
        date: .now,
        snapshot: DailyWidgetSnapshot(
            generatedAt: .now,
            dayStart: Calendar.current.startOfDay(for: .now),
            state: .ready,
            calories: WidgetCalorieSummary(
                consumed: 2_450,
                target: 2_000,
                mealCalories: [.breakfast: 382, .lunch: 463, .dinner: 1_377, .snack: 228]
            )
        ),
        isStale: false
    )
}
