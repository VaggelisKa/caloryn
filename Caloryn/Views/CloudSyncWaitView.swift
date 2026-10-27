import SwiftUI

struct CloudSyncWaitView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isSpinning = false
    @State private var isBreathing = false

    private static let summary = CalorieDonutSummary(
        mealTotals: [.breakfast: 1, .lunch: 1, .dinner: 1, .snack: 1],
        budget: 4,
        isOver: false
    )

    private var size: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 120 : 160
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .calorynPageCanvas()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cloudSync.waiting")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                isSpinning = true
            }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 44) {
                CalorieDonutView(summary: Self.summary, size: size)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .scaleEffect(isBreathing ? 1.04 : 0.96)

                VStack(spacing: 10) {
                    Text("Checking iCloud")
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("Checking iCloud, in progress")

                    Text("If you have used Caloryn on another device, your profile and food log will appear in a moment.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    CloudSyncWaitView()
}
