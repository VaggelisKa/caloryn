import SwiftUI

struct ChatbotPasteRow: View {
    let onPaste: ([String]) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Food from your chatbot")
                .font(CalorynTheme.cardSubtitle)
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            PasteButton(payloadType: String.self) { @Sendable strings in
                Task { @MainActor in
                    onPaste(strings)
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .tint(CalorynTheme.accentControl)
            .accessibilityIdentifier("foodSearch.pasteLink")
        }
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 2)
        .padding(.bottom, 6)
    }
}
