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
                .containerBackground(for: .widget) {
                    WidgetTheme.page
                }
        }
        .configurationDisplayName("Log a Meal")
        .description("Jump straight to logging breakfast, lunch, dinner, or a snack.")
        .supportedFamilies([.systemSmall])
    }
}

private struct QuickLogWidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            WidgetSectionTitle(title: "Log a meal")

            WidgetQuickLogRows()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    QuickLogWidget()
} timeline: {
    QuickLogEntry(date: .now)
}
