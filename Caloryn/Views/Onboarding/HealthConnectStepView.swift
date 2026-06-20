import SwiftUI

struct HealthConnectStepView: View {
    var onComplete: () -> Void

    @AppStorage(AppleHealthAdjustmentSettings.adjustmentEnabledKey) private var healthAdjustmentEnabled = false
    @AppStorage(AppleHealthAdjustmentSettings.authorizationRequestedKey) private var healthAuthorizationRequested = false
    @State private var isRequestingAuthorization = false
    @State private var statusMessage: String?

    private var isHealthAvailable: Bool {
        HealthKitService.isHealthDataAvailable
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(CalorynTheme.sage)
                        .frame(width: 108, height: 108)
                        .adaptiveGlassCircle()
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        Text("Adjust with Apple Health")
                            .font(CalorynTheme.sectionTitle)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("Optional. Caloryn can read Active Energy only, then add a conservative calorie credit on-device.")
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    VStack(spacing: 12) {
                        healthPoint(icon: "flame.fill", title: "70% credit", detail: "Workout energy increases today's budget conservatively.")
                        healthPoint(icon: "lock.fill", title: "Local calculation", detail: "Health data is not exported or sent to food search.")
                        healthPoint(icon: "switch.2", title: "Your control", detail: "You can turn this off later in Settings.")
                    }
                    .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)

                    if let statusMessage {
                        Text(statusMessage)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.terracotta)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }

            VStack(spacing: 12) {
                Button {
                    Task {
                        await connectAppleHealth()
                    }
                } label: {
                    HStack {
                        if isRequestingAuthorization {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isHealthAvailable ? "Connect Apple Health" : "Apple Health Unavailable")
                            .font(.system(.headline, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .adaptiveGlassProminentButton()
                .tint(CalorynTheme.sage)
                .disabled(!isHealthAvailable || isRequestingAuthorization)

                Button {
                    AppleHealthAdjustmentSettings.disable()
                    onComplete()
                } label: {
                    Text("Skip for Now")
                        .font(CalorynTheme.bodyText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(CalorynTheme.textSecondary)
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 24)
        }
        .navigationBarBackButtonHidden(isRequestingAuthorization)
    }

    private func healthPoint(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CalorynTheme.sage)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(detail)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func connectAppleHealth() async {
        guard isHealthAvailable else {
            statusMessage = "Apple Health is not available on this device."
            return
        }

        isRequestingAuthorization = true
        defer { isRequestingAuthorization = false }
        statusMessage = nil

        let update = await AppleHealthAdjustmentSettings.enable()
        healthAdjustmentEnabled = update.isEnabled
        healthAuthorizationRequested = update.authorizationRequested
        statusMessage = update.message
        guard update.isEnabled else { return }
        onComplete()
    }
}

#Preview {
    NavigationStack {
        HealthConnectStepView { }
    }
}
