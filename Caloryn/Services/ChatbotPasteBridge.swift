import SwiftUI
import UIKit

struct ChatbotPasteBridge: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("chatbotPasteboardGeneration") private var pasteboardGeneration = 0

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                pasteboardGeneration += 1
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .background else { return }
                pasteboardGeneration += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: UIPasteboard.changedNotification)) { _ in
                pasteboardGeneration += 1
            }
    }
}
