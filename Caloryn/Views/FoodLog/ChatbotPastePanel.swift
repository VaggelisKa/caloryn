import SwiftUI
import UIKit

struct ChatbotPastePanel: View {
    let onConfirm: (PastedFoodConfirmation) -> Void

    @Environment(\.locale) private var locale
    @State private var rejectionMessage: String?
    @State private var hasCopiedInstructions = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Food from a chatbot")
                    .font(CalorynTypeface.text(.subheadline, weight: .bold))
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text("Copy its reply with the caloryn:// line, then paste it here.")
                    .font(CreationFormTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: copyInstructions) {
                    Label(
                        hasCopiedInstructions ? "Instructions copied" : "Copy instructions for your chatbot",
                        systemImage: hasCopiedInstructions ? "checkmark" : "doc.on.doc"
                    )
                    .font(CalorynTypeface.text(.footnote, weight: .semibold))
                    .foregroundStyle(CalorynTheme.accent)
                    .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .accessibilityHint("Copies a message that tells your chatbot how to write a Caloryn link")
                .accessibilityIdentifier("foodSearch.copyChatbotInstructions")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PasteButton(payloadType: String.self) { @Sendable strings in
                Task { @MainActor in
                    receive(strings)
                }
            }
            .labelStyle(.titleAndIcon)
            .buttonBorderShape(.capsule)
            .tint(CalorynTheme.accentControl)
            .accessibilityIdentifier("foodSearch.pasteLink")
        }
        .padding(.horizontal, CalorynTheme.cardPadding)
        .padding(.vertical, 12)
        .calorynGroupSurface()
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .alert("Couldn’t Read Link", isPresented: rejectionIsPresented) {
            Button("OK", role: .cancel) { rejectionMessage = nil }
                .accessibilityIdentifier("foodSearch.pasteRejection.ok")
        } message: {
            Text(verbatim: rejectionMessage ?? "")
        }
    }

    private func receive(_ strings: [String]) {
        switch PastedFoodConfirmation.opening(pasted: strings, locale: locale) {
        case .success(let confirmation):
            onConfirm(confirmation)
        case .failure(let rejection):
            CalorynHaptics.warning()
            rejectionMessage = rejection.localizedDescription
        }
    }

    private func copyInstructions() {
        UIPasteboard.general.string = ChatbotLogInstructions.text
        CalorynHaptics.success()
        withAnimation(.smooth(duration: 0.2)) {
            hasCopiedInstructions = true
        }
    }

    private var rejectionIsPresented: Binding<Bool> {
        Binding(
            get: { rejectionMessage != nil },
            set: { if !$0 { rejectionMessage = nil } }
        )
    }
}
