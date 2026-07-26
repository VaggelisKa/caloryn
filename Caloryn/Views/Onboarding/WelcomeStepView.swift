import SwiftUI

struct WelcomeCardsGraphic: View {
    @State private var showBack = false
    @State private var showMiddle = false
    @State private var showFront = false
    @State private var expandToList = false
    
    var body: some View {
        ZStack {
            // Back card (Dinner)
            LogCardMock(icon: "moon.stars.fill", title: "Dinner", cals: "650", color: CalorynTheme.terracotta)
                .scaleEffect(expandToList ? 0.9 : 0.85)
                .offset(y: !showBack ? 0 : (expandToList ? 85 : -40))
                .opacity(showBack ? (expandToList ? 1.0 : 0.6) : 0)
                .zIndex(1)
                
            // Middle card (Lunch)
            LogCardMock(icon: "sun.max.fill", title: "Lunch", cals: "820", color: CalorynTheme.carbColor)
                .scaleEffect(expandToList ? 0.9 : 0.92)
                .offset(y: !showMiddle ? 20 : (expandToList ? 0 : -15))
                .opacity(showMiddle ? (expandToList ? 1.0 : 0.8) : 0)
                .zIndex(2)
                
            // Front card (Breakfast)
            LogCardMock(icon: "sunrise.fill", title: "Breakfast", cals: "450", color: CalorynTheme.sage)
                .scaleEffect(expandToList ? 0.9 : 1.0)
                .offset(y: !showFront ? 40 : (expandToList ? -85 : 10))
                .opacity(showFront ? 1.0 : 0)
                .shadow(color: .black.opacity(expandToList ? 0.04 : 0.08), radius: 15, y: 8)
                .zIndex(3)
        }
        .frame(height: 250)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showBack = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25)) {
                showMiddle = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                showFront = true
            }
            
            // Pause, then slide them out into a list
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(1.5)) {
                expandToList = true
            }
        }
    }
}

struct LogCardMock: View {
    let icon: String
    let title: String
    let cals: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(color)
                .clipShape(Circle())
                
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text("\(cals) kcal")
                    .font(CalorynTheme.numericCaption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.sage)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 40)
    }
}

struct WelcomeStepView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                WelcomeCardsGraphic()

                VStack(spacing: 12) {
                    Text("Caloryn")
                        .font(CalorynTheme.brandTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text("Track your calories.\nSimple, private, fast.")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(CalorynTheme.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .adaptiveGlassProminentButton()
                .accessibilityIdentifier("onboarding.getStarted")

                Text("No account needed. Your data stays on-device.")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 40)
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        WelcomeStepView { }
    }
}
