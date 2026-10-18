import SwiftUI

/// The Caloryn mark (`PlateWelcome`): the Today donut with all four meals at an equal share,
/// and a bite taken out of its top-left — a page-coloured disc over the ring.
///
/// Built from the same `CalorieDonutView` as the Today hero, so it is the app's real ring
/// rather than a drawing of one. The ring grows its meals into place as it appears and the
/// bite follows, together well under a second, so the welcome screen is settled long before
/// `ThemeScreenshotTests` photographs it.
struct WelcomePlateMark: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBitten = false

    /// Four equal meals and a budget they exactly fill: no remaining sector, no over.
    private static let summary = CalorieDonutSummary(
        mealTotals: [.breakfast: 1, .lunch: 1, .dinner: 1, .snack: 1],
        budget: 4,
        isOver: false
    )

    /// Decoration, so it does not grow with the text: the board's 200pt, and smaller at
    /// accessibility sizes so the name, tagline and button keep the room.
    private var size: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 140 : 200
    }

    var body: some View {
        // The board's 200pt mark is a ring of radius 80 and width 28: 188pt across, with
        // the bite a 68pt disc centred at (42, 38).
        ZStack(alignment: .topLeading) {
            CalorieDonutView(summary: Self.summary, size: size * 0.94)
                .frame(width: size, height: size)

            Circle()
                .fill(CalorynTheme.pageBackground)
                .frame(width: size * 0.34, height: size * 0.34)
                .scaleEffect(isBitten ? 1 : 0.001)
                .position(x: size * 0.21, y: size * 0.19)
        }
        .frame(width: size, height: size)
        // Decorative: the name directly under it is the heading.
        .accessibilityHidden(true)
        .onAppear {
            guard !isBitten else { return }
            guard !reduceMotion else {
                isBitten = true
                return
            }
            // After the ring's own 0.55s reveal, so the bite is taken from a full plate.
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(0.5)) {
                isBitten = true
            }
        }
    }
}

struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        // At least a screen tall, so the spacers centre the mark as the board does; taller
        // when large text needs it, and then it scrolls rather than truncating the tagline.
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // The root of the onboarding `NavigationStack`, and the first screen a
        // new user ever sees. Without a canvas it rendered on the system window
        // background — pure white in light mode, near-black in dark — while
        // every screen reached afterwards is `pageBackground`.
        .calorynPageCanvas()
        // No back button to theme: this screen deliberately hides the bar, and
        // it is the stack root, so `calorynDrillDownNavigation()` does not apply.
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
                        .tracking(-1)
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
