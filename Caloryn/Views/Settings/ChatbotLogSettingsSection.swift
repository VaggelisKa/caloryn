import SwiftUI
import UIKit

struct ChatbotLogSettingsSection: View {
    @State private var hasCopiedInstructions = false

    var body: some View {
        Section {
            Button(action: copyInstructions) {
                HStack {
                    Text(hasCopiedInstructions ? "Instructions copied" : "Copy instructions for your chatbot")
                        .font(CalorynTheme.bodyText)
                        .contentTransition(.opacity)
                    Spacer(minLength: 12)
                    Image(systemName: hasCopiedInstructions ? "checkmark" : "doc.on.doc")
                        .font(CalorynTheme.toolbarIcon)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(CalorynTheme.accent)
                .contentShape(Rectangle())
            }
            .accessibilityHint("Copies a message that tells your chatbot how to write a Caloryn link")
            .accessibilityIdentifier("settings.copyChatbotInstructions")
        } header: {
            SettingsSectionTitle("Log from a chatbot")
        } footer: {
            SettingsSectionFooter("Paste these instructions into your chatbot once. Then copy its reply and paste it in the add-food sheet.")
        }
    }

    private func copyInstructions() {
        UIPasteboard.general.string = ChatbotLogInstructions.text
        CalorynHaptics.success()
        withAnimation(.smooth(duration: 0.2)) {
            hasCopiedInstructions = true
        }
    }
}
