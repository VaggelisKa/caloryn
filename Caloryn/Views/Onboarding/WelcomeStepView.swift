import SwiftUI

struct WelcomePlateMark: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBitten = false

    private static let summary = CalorieDonutSummary(
        mealTotals: [.breakfast: 1, .lunch: 1, .dinner: 1, .snack: 1],
        budget: 4,
        isOver: false
    )

    private var size: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 140 : 200
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            CalorieDonutView(summary: Self.summary, size: size * 0.94)
                .frame(width: size, height: size)

            Circle()
                .fill(CalorynTheme.backgroundPrimary)
                .frame(width: size * 0.34, height: size * 0.34)
                .scaleEffect(isBitten ? 1 : 0.001)
                .position(x: size * 0.21, y: size * 0.19)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .onAppear {
            guard !isBitten else { return }
            guard !reduceMotion else {
                isBitten = true
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.5)) {
                isBitten = true
            }
        }
    }
}

struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .calorynPageCanvas()
        .toolbarVisibility(.hidden, for: .navigationBar)
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 44) {
                WelcomePlateMark()

                VStack(spacing: 10) {
                    Text("Caloryn")
                        .font(CalorynTheme.brandTitle)
                        .tracking(-0.5)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Track your calories.\nSimple, private, fast.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 24)

            VStack(spacing: 14) {
                Button(action: onContinue) {
                    Text("Get started")
                }
                .calorynPrimaryButton()
                .accessibilityIdentifier("onboarding.getStarted")

                Text("No account needed. Your data stays on-device.")
                    .font(OnboardingTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 12)
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeStepView { }
    }
}
