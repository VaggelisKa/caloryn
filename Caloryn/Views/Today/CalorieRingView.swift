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
        calorieBudget.hasActivityCredit ? min(animatedRingProgress, calorieBudget.baseProgressEnd) : animatedRingProgress
    }

    private var animatedCreditProgress: Double {
        guard calorieBudget.hasActivityCredit, animatedRingProgress > calorieBudget.baseProgressEnd else {
            return calorieBudget.baseProgressEnd
        }
        return min(animatedRingProgress, 1)
    }

    private var activityCreditColor: Color {
        CalorynTheme.carbColor
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
                    to: calorieBudget.hasActivityCredit ? 1 : calorieBudget.baseProgressEnd
                )
                .stroke(
                    activityCreditColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(calorieBudget.hasActivityCredit ? 1 : 0)

            Circle()
                .trim(from: 0, to: animatedBaseProgress)
                .stroke(
                    calorieBudget.isOver ? CalorynTheme.terracotta : CalorynTheme.sage,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(animatedRingProgress < 0.01 ? 0 : 1)

            Circle()
                .trim(from: calorieBudget.baseProgressEnd, to: animatedCreditProgress)
                .stroke(
                    calorieBudget.isOver ? CalorynTheme.terracotta : activityCreditColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(calorieBudget.hasActivityCredit && animatedCreditProgress > calorieBudget.baseProgressEnd ? 1 : 0)

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

                activityCreditCue
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(20)
        .glassCircle()
        .contentShape(Circle())
        .scaleEffect(isDetailsPressing ? 0.94 : 1)
        .animation(.smooth(duration: 0.2), value: isDetailsPressing)
        .animation(.smooth(duration: 0.35), value: calorieBudget.activityCredit)
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
    private var activityCreditCue: some View {
        if calorieBudget.isActivityLoading {
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)

                Text("updating")
                    .lineLimit(1)
            }
            .font(.system(.caption2, design: .rounded, weight: .medium))
            .foregroundStyle(CalorynTheme.textSecondary)
            .padding(.top, 2)
        } else if calorieBudget.hasActivityCredit {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9, weight: .bold))

                Text("+\(calorieBudget.activityCredit) activity")
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(activityCreditColor)
                .padding(.top, 2)
                .accessibilityLabel("\(calorieBudget.activityCredit) calorie activity credit")
        }
    }

    private var accessibilityDescription: String {
        let activityDescription = calorieBudget.hasActivityCredit ? ", includes \(calorieBudget.activityCredit) calorie activity credit" : ""

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

#Preview("Ring - No Activity") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 1200,
            baseTarget: 2000,
            activeEnergyKcal: 0,
            isActivityAdjustmentEnabled: false,
            isActivityLoading: false,
            activityMessage: nil
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Activity Credit") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 2070,
            baseTarget: 2000,
            activeEnergyKcal: 500,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: false,
            activityMessage: nil
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Over Adjusted Target") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 2450,
            baseTarget: 2000,
            activeEnergyKcal: 500,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: false,
            activityMessage: nil
        ),
        ringSize: 220
    )
    .padding()
}

#Preview("Ring - Loading Activity") {
    CalorieRingView(
        calorieBudget: ActivityCalorieBudget(
            consumed: 1200,
            baseTarget: 2000,
            activeEnergyKcal: 0,
            isActivityAdjustmentEnabled: true,
            isActivityLoading: true,
            activityMessage: nil
        ),
        ringSize: 220
    )
    .padding()
}
