import SwiftUI
import WidgetKit

struct QuickLogEntry: TimelineEntry {
    let date: Date
}

struct QuickLogProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLogEntry {
        QuickLogEntry(date: .now)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuickLogEntry) -> Void
    ) {
        completion(QuickLogEntry(date: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuickLogEntry>) -> Void
    ) {
        // The buttons are static deep links, so a single entry that never
        // needs refreshing is all we need.
        completion(Timeline(entries: [QuickLogEntry(date: .now)], policy: .never))
    }
}

struct QuickLogWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: WidgetConstants.quickLogKind,
            provider: QuickLogProvider()
        ) { _ in
            QuickLogWidgetView()
                .fontDesign(.rounded)
                .containerBackground(for: .widget) {
                    WidgetTheme.background
                }
        }
        .configurationDisplayName("Log a Meal")
        .description("Jump straight to logging breakfast, lunch, dinner, or a snack.")
        .supportedFamilies([.systemSmall])
    }
}

private struct QuickLogWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Log a meal")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    QuickLogButton(meal: .breakfast)
                    QuickLogButton(meal: .lunch)
                }
                HStack(spacing: 8) {
                    QuickLogButton(meal: .dinner)
                    QuickLogButton(meal: .snack)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry(date: .now)
}
