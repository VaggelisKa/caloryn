import SwiftUI

struct AppleHealthOptInCard: View {
    @Binding var isEnabled: Bool
    let message: String?

    private var isHealthAvailable: Bool {
        AppleHealthAdjustmentSettings.isHealthAvailable
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $isEnabled) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CalorynTheme.sage)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(EnergyCalculationMode.dynamicHealth.displayName)
                            .font(CalorynTheme.itemTitle)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Text(isHealthAvailable ? "Uses Apple Health when activity data is available." : "Apple Health is not available on this device.")
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
            .tint(CalorynTheme.sage)
            .disabled(!isHealthAvailable)
            .onChange(of: isHealthAvailable, initial: true) {
                if !isHealthAvailable {
                    isEnabled = false
                }
            }

            HStack(spacing: 10) {
                Label(AppleHealthAdjustmentSettings.dynamicEnergyShortText, systemImage: "flame.fill")
                Label("On-device", systemImage: "lock.fill")
            }
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)

            if let message {
                Text(message)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AppleHealthOptInCard(isEnabled: .constant(false), message: nil)
        .padding()
}
