import SwiftUI
import UIKit

struct CalorieRingView: View {
    let calorieBudget: ActivityCalorieBudget
    let ringSize: CGFloat
    var onDetailsRequested: (() -> Void)? = nil

    @ScaledMetric private var numberSize: CGFloat = 44
    @State private var animatedRingProgress: Double = 0
    @State private var isDetailsPressing = false

    private var animatedBaseProgress: Double {
        calorieBudget.hasDynamicIncrease ? min(animatedRingProgress, calorieBudget.baseProgressEnd) : animatedRingProgress
    }

    private var animatedDynamicProgress: Double {
        guard calorieBudget.hasDynamicIncrease, animatedRingProgress > calorieBudget.baseProgressEnd else {
            return calorieBudget.baseProgressEnd
        }
        return min(animatedRingProgress, 1)
    }

    private var dynamicTargetColor: Color {
        CalorynTheme.carbColor
    }

    private var centerContentWidth: CGFloat {
        max(96, ringSize * 0.62)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    CalorynTheme.sage.opacity(0.15),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )

            Circle()
                .trim(
                    from: calorieBudget.baseProgressEnd,
                    to: calorieBudget.hasDynamicIncrease ? 1 : calorieBudget.baseProgressEnd
                )
                .stroke(
                    dynamicTargetColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(calorieBudget.hasDynamicIncrease ? 1 : 0)

            Circle()
                .trim(from: 0, to: animatedBaseProgress)
                .stroke(
                    calorieBudget.isOver ? CalorynTheme.terracotta : CalorynTheme.sage,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(animatedRingProgress < 0.01 ? 0 : 1)

            Circle()
                .trim(from: calorieBudget.baseProgressEnd, to: animatedDynamicProgress)
                .stroke(
                    calorieBudget.isOver ? CalorynTheme.terracotta : dynamicTargetColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(calorieBudget.hasDynamicIncrease && animatedDynamicProgress > calorieBudget.baseProgressEnd ? 1 : 0)

            VStack(spacing: 2) {
                if calorieBudget.isOver {
                    Text("\(calorieBudget.overAmount)")
                        .font(.system(size: numberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(CalorynTheme.terracotta)
                        .contentTransition(.numericText())

                    Text("over")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta.opacity(0.85))
                } else {
                    Text("\(calorieBudget.remaining)")
                        .font(.system(size: numberSize, weight: .bold, design: .rounded))
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .contentTransition(.numericText())

                    Text("remaining")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                Text("\(calorieBudget.roundedConsumed) eaten")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(calorieBudget.isOver ? CalorynTheme.terracotta.opacity(0.7) : CalorynTheme.textSecondary.opacity(0.75))
                    .padding(.top, 6)

                dynamicTargetCue
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(20)
        .glassCircle()
        .contentShape(Circle())
        .scaleEffect(isDetailsPressing ? 0.94 : 1)
        .animation(.smooth(duration: 0.2), value: isDetailsPressing)
        .animation(.smooth(duration: 0.35), value: calorieBudget.dynamicAdjustment)
        .animation(.smooth(duration: 0.35), value: calorieBudget.adjustedTarget)
        .animation(.smooth(duration: 0.35), value: calorieBudget.isActivityLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(calorieBudget.isOver
            ? "\(calorieBudget.roundedConsumed) eaten, \(calorieBudget.overAmount) calories over target of \(calorieBudget.adjustedTarget)"
            : "\(calorieBudget.roundedConsumed) eaten, \(calorieBudget.remaining) remaining of \(calorieBudget.adjustedTarget)"
        )
        .accessibilityHint(onDetailsRequested == nil ? "" : "Tap or long press to show nutrition details.")
        .accessibilityAddTraits(onDetailsRequested == nil ? [] : .isButton)
        .accessibilityAction(named: Text("Show nutrition details")) {
            requestDetails()
        }
        .onTapGesture(perform: requestDetails)
        .onLongPressGesture(
            minimumDuration: 0.45,
            maximumDistance: 24,
            pressing: setDetailsPressing,
            perform: requestDetails
        )
        .onAppear {
            animatedRingProgress = calorieBudget.displayedRingProgress
        }
        .onChange(of: calorieBudget.displayedRingProgress) { _, newProgress in
            withAnimation(.smooth(duration: 0.45)) {
                animatedRingProgress = newProgress
            }
        }
    }

    @ViewBuilder
    private var dynamicTargetCue: some View {
        if calorieBudget.isActivityLoading {
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)

                Text("updating")
                    .lineLimit(1)
            }
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(CalorynTheme.textSecondary)
            .frame(maxWidth: centerContentWidth)
            .padding(.top, 2)
        } else if calorieBudget.hasDynamicIncrease {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .bold))

                Text("+\(calorieBudget.dynamicIncrease) dynamic")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(dynamicTargetColor)
                .frame(maxWidth: centerContentWidth)
                .padding(.top, 2)
                .accessibilityLabel("\(calorieBudget.dynamicIncrease) calorie auto-adjust increase")
        } else if calorieBudget.hasDynamicReduction {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 9, weight: .bold))

                Text("\(abs(calorieBudget.dynamicAdjustment)) dynamic")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(CalorynTheme.textSecondary)
                .frame(maxWidth: centerContentWidth)
                .padding(.top, 2)
                .accessibilityLabel("\(abs(calorieBudget.dynamicAdjustment)) calorie auto-adjust reduction")
        }
    }

    private var accessibilityDescription: String {
        let activityDescription = calorieBudget.hasDynamicIncrease ? ", includes \(calorieBudget.dynamicIncrease) calorie auto-adjust increase" : ""

        if calorieBudget.isOver {
            return "Calorie ring, \(calorieBudget.roundedConsumed) eaten, \(calorieBudget.overAmount) calories over a \(calorieBudget.adjustedTarget) calorie goal\(activityDescription)"
        } else {
            return "Calorie ring, \(calorieBudget.remaining) remaining of \(calorieBudget.adjustedTarget) calories, \(calorieBudget.roundedConsumed) eaten\(activityDescription)"
        }
    }

    private func setDetailsPressing(_ pressing: Bool) {
        guard onDetailsRequested != nil else { return }
        guard isDetailsPressing != pressing else { return }
        if pressing {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred(intensity: 0.55)
        }
        isDetailsPressing = pressing
    }

    private func requestDetails() {
        guard let onDetailsRequested else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.75)
        isDetailsPressing = false
        onDetailsRequested()
    }
}

#Preview("Ring - Static Estimate") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 1200,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 500,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .lifestyleEstimate,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Auto-adjust") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 2070,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 500,
            recentActiveEnergySamples: previewActivitySamples,
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Dynamic Learning") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 920,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 180,
            recentActiveEnergySamples: Array(previewActivitySamples.prefix(3)),
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Dynamic Reduction") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 1440,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 120,
            recentActiveEnergySamples: previewActivitySamples,
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date.now) ?? .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Dynamic Unavailable") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 760,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: [],
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: "Apple Health permission wasn't given. Allow Active Energy for Caloryn in the Health app, then try again.",
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Over Adjusted Target") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 2450,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 500,
            recentActiveEnergySamples: previewActivitySamples,
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: false,
            activityMessage: nil,
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Loading Activity") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 1200,
            staticTarget: 2000,
            bmr: 1700,
            calorieDeficit: 300,
            activeEnergyKcal: 0,
            recentActiveEnergySamples: previewActivitySamples,
            calculationMode: .dynamicHealth,
            isManualOverride: false,
            isActivityLoading: true,
            activityMessage: nil,
            date: .now
        ),
        ringSize: 220
    )
    .padding()
}

private let previewActivitySamples: [DailyActiveEnergySample] = (1...10).compactMap { offset in
    guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date.now.startOfDay) else {
        return nil
    }

    return DailyActiveEnergySample(date: date, activeEnergyKcal: 300)
}
