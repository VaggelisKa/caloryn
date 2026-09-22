import SwiftUI
import UIKit

struct CalorieRingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let calorieBudget: ActivityCalorieBudget
    let ringSize: CGFloat
    var onDetailsRequested: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var animatedRingProgress: Double = 0
    @State private var hasAppeared = false
    @State private var fadeInTask: Task<Void, Never>?
    @ScaledMetric private var numberSize: CGFloat = 44

    private var summary: CalorieRingSummary {
        CalorieRingSummary(budget: calorieBudget)
    }

    private var dynamicTargetColor: Color {
        CalorynTheme.carbColor
    }

    /// The semantic accent the summary decided, mapped onto the theme here.
    private var accentColor: Color {
        switch summary.accent {
        case .withinBudget: CalorynTheme.sage
        case .overBudget: CalorynTheme.terracotta
        }
    }

    private var dynamicArcColor: Color {
        switch summary.accent {
        case .withinBudget: dynamicTargetColor
        case .overBudget: CalorynTheme.terracotta
        }
    }

    private var centerContentWidth: CGFloat {
        max(96, ringSize * 0.62)
    }

    private var ringSurfaceSize: CGFloat {
        ringSize + 40
    }

    var body: some View {
        Group {
            if onDetailsRequested != nil {
                Button(action: requestDetails) {
                    ringVisual
                }
                .buttonStyle(CalorieRingButtonStyle())
            } else {
                ringVisual
            }
        }
    }

    private var ringVisual: some View {
        Group {
            if accessibilityReduceMotion {
                summarySurface(progress: calorieBudget.displayedRingProgress)
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
            } else {
                summarySurface(progress: animatedRingProgress)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(ringUpdateAnimation, value: calorieBudget.dynamicAdjustment)
                    .animation(ringUpdateAnimation, value: calorieBudget.adjustedTarget)
                    .animation(ringUpdateAnimation, value: calorieBudget.isActivityLoading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.accessibilityLabel)
        .accessibilityValue(summary.accessibilityValue)
        .accessibilityHint(CalorieRingSummary.accessibilityHint(isInteractive: onDetailsRequested != nil))
        .onAppear(perform: appear)
        .onDisappear(perform: disappear)
        .onChange(of: calorieBudget.displayedRingProgress) { _, newProgress in
            updateRingProgress(newProgress)
        }
        .onChange(of: accessibilityReduceMotion) { _, reduceMotion in
            guard reduceMotion else { return }
            setCurrentValuesWithoutAnimation()
        }
    }

    @ViewBuilder
    private func summarySurface(progress: Double) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilitySummary
        } else {
            ringSurface(progress: progress)
        }
    }

    private func ringSurface(progress: Double) -> some View {
        let ringProgress = CalorieRingProgress(
            budget: calorieBudget,
            animatedProgress: progress
        )

        return ZStack {
            Circle()
                .stroke(
                    CalorynTheme.sage.opacity(0.18),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )

            arc(ringProgress.dynamicTrack, color: dynamicTargetColor.opacity(0.42))

            arc(ringProgress.baseArc, color: accentColor)

            arc(ringProgress.dynamicArc, color: dynamicArcColor)

            VStack(spacing: 2) {
                if summary.isOver {
                    Text("\(summary.centerValue)")
                        .font(CalorynTheme.ringNumber(size: numberSize))
                        .foregroundStyle(CalorynTheme.terracotta)
                        .contentTransition(centerValueTransition)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: centerContentWidth)

                    Text(summary.centerCaption)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta.opacity(0.85))
                } else {
                    Text("\(summary.centerValue)")
                        .font(CalorynTheme.ringNumber(size: numberSize))
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .contentTransition(centerValueTransition)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: centerContentWidth)

                    Text(summary.centerCaption)
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                Text(summary.eatenText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(summary.isOver ? CalorynTheme.terracotta.opacity(0.7) : CalorynTheme.textSecondary.opacity(0.75))
                    .padding(.top, 6)

                dynamicTargetCue
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(20)
        .background {
            Circle()
                .fill(CalorynTheme.cardBackground.opacity(0.82))
                .frame(width: ringSurfaceSize, height: ringSurfaceSize)
                .overlay {
                    Circle()
                        .stroke(CalorynTheme.cardSeparator.opacity(0.7), lineWidth: 0.8)
                }
        }
        .compositingGroup()
        .clipShape(Circle())
        .contentShape(Circle())
    }

    private var accessibilitySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calorie summary")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)
                .textCase(.uppercase)

            Text("\(summary.centerValue)")
                .font(CalorynTheme.largeNumber)
                .foregroundStyle(summary.isOver ? CalorynTheme.terracotta : CalorynTheme.textPrimary)
                .contentTransition(centerValueTransition)

            Text(summary.centerCaption)
                .font(CalorynTheme.itemTitle)
                .foregroundStyle(summary.isOver ? CalorynTheme.terracotta : CalorynTheme.textPrimary)

            Text(summary.eatenText)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)

            accessibilityCue
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CalorynTheme.cardBackground.opacity(0.82))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(CalorynTheme.cardSeparator.opacity(0.7), lineWidth: 0.8)
                }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessibilityCue: some View {
        switch summary.cue {
        case .none:
            EmptyView()
        case .updating:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Updating calorie target")
            }
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
        case .increase:
            Label(summary.cue.accessibilityLabel ?? "", systemImage: "flame.fill")
                .font(CalorynTheme.caption)
                .foregroundStyle(dynamicTargetColor)
        case .reduction:
            Label(summary.cue.accessibilityLabel ?? "", systemImage: "arrow.down.circle.fill")
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }

    private func appear() {
        hasAppeared = false
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedRingProgress = calorieBudget.displayedRingProgress
        }
        fadeInTask?.cancel()
        guard !accessibilityReduceMotion else {
            hasAppeared = true
            return
        }

        fadeInTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.28)) { hasAppeared = true }
            fadeInTask = nil
        }
    }

    private func disappear() {
        fadeInTask?.cancel()
        fadeInTask = nil
        hasAppeared = false
    }

    private func setCurrentValuesWithoutAnimation() {
        fadeInTask?.cancel()
        fadeInTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            animatedRingProgress = calorieBudget.displayedRingProgress
            hasAppeared = true
        }
    }

    private var centerValueTransition: ContentTransition {
        accessibilityReduceMotion ? .identity : .numericText()
    }

    private var ringUpdateAnimation: Animation? {
        accessibilityReduceMotion ? nil : .smooth(duration: 0.35)
    }

    private func updateRingProgress(_ newProgress: Double) {
        guard !accessibilityReduceMotion else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                animatedRingProgress = newProgress
            }
            return
        }

        withAnimation(.smooth(duration: 0.45)) {
            animatedRingProgress = newProgress
        }
    }

    /// One progress arc, drawn from the top: the span comes from
    /// `CalorieRingProgress`, the stroke and the rotation stay here.
    private func arc(_ arc: CalorieRingProgress.Arc, color: Color) -> some View {
        Circle()
            .trim(from: arc.start, to: arc.end)
            .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .opacity(arc.isVisible ? 1 : 0)
    }

    @ViewBuilder
    private var dynamicTargetCue: some View {
        switch summary.cue {
        case .none:
            EmptyView()
        case .updating:
            HStack(spacing: 5) {
                ProgressView()
                    .controlSize(.mini)

                Text(summary.cue.text ?? "")
                    .lineLimit(1)
            }
            .font(CalorynTheme.microCaption)
            .foregroundStyle(CalorynTheme.textSecondary)
            .frame(maxWidth: centerContentWidth)
            .padding(.top, 2)
        case .increase:
            cueLabel(iconName: "flame.fill", color: dynamicTargetColor)
        case .reduction:
            cueLabel(iconName: "arrow.down.circle.fill", color: CalorynTheme.textSecondary)
        }
    }

    private func cueLabel(iconName: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
                .font(CalorynTheme.compactIcon)

            Text(summary.cue.text ?? "")
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
            .font(CalorynTheme.numericMicroCaptionEmphasized)
            .foregroundStyle(color)
            .frame(maxWidth: centerContentWidth)
            .padding(.top, 2)
            .accessibilityLabel(summary.cue.accessibilityLabel ?? "")
    }

    private func requestDetails() {
        guard let onDetailsRequested else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.75)
        onDetailsRequested()
    }
}

private struct CalorieRingButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(accessibilityReduceMotion ? 1 : (configuration.isPressed ? 0.94 : 1))
            .animation(
                accessibilityReduceMotion ? nil : .smooth(duration: 0.2),
                value: configuration.isPressed
            )
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
