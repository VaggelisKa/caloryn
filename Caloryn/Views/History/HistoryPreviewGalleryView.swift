#if DEBUG
import SwiftUI

struct HistoryPreviewGalleryView: View {
    @State private var selectedScenario: HistoryPreviewScenario = .mostlyOnTrack

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Preview State", selection: $selectedScenario) {
                    ForEach(HistoryPreviewScenario.allCases) { scenario in
                        Text(scenario.title).tag(scenario)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.vertical, 10)

                Divider()

                HistoryPreviewFixtures.preview(for: selectedScenario)
                    .id(selectedScenario.id)
            }
            .navigationTitle("History Previews")
        }
    }
}

#Preview("History Preview Gallery") {
    HistoryPreviewGalleryView()
}
#endif
