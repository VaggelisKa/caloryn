import SwiftUI

/// "Your daily plate" (`PlateGoal`): the target as an empty plate inside a dotted ring of
/// what you burn, the slider that sets the gap between them, the rows the number is worked
/// out from, and a way to type a number instead.
struct GoalSummaryStepView: View {
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let activityLevel: ActivityLevel
    @Binding var calorieDeficit: Double
    var onContinue: (Int, Bool) -> Void

    /// Every rule this step applies lives in the draft; the view reads it and
    /// renders. See `OnboardingGoalSummaryDraft`.
    @State private var draft = OnboardingGoalSummaryDraft()
    @FocusState private var isManualTargetFocused: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var targetSize: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var plateSize: CGFloat = 132
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The drawing is decoration, so it stops growing well before the number does.
    private var plateDiameter: CGFloat { min(plateSize, 160) }

    /// The answers from the earlier steps, which this step only reads. The
    /// deficit is the container's, because the saved profile keeps it.
    private var basis: OnboardingGoalSummaryDraft.Basis {
        OnboardingGoalSummaryDraft.Basis(
            age: age,
            sex: sex,
            heightCm: heightCm,
            weightKg: weightKg,
            activityLevel: activityLevel,
            calorieDeficit: calorieDeficit
        )
    }

    private var displayTarget: Int { draft.displayTarget(basis: basis) }

    /// What the plate, the rows and the captions say. See `OnboardingGoalPlate`.
    private var plate: OnboardingGoalPlate {
        OnboardingGoalPlate(basis: basis, target: displayTarget)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                OnboardingStepHeader(
                    title: "Your daily plate",
                    subtitle: "Worked out from your age, height, weight and how active you are. Change it any time."
                )

                targetDisplay

                paceSection

                sourcesSection
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            OnboardingActionBar {
                Button { onContinue(displayTarget, draft.appliesManualTarget) } label: {
                    Text("Continue")
                }
                .calorynPrimaryButton()
                .accessibilityIdentifier("onboarding.goalSummary.continue")
            }
        }
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .onChange(of: basis.calculatedTarget) {
            draft.calculatedTargetChanged(basis: basis)
        }
        .onAppear {
            draft.seedManualTarget(basis: basis)
        }
    }

    // MARK: - The plate and its number

    /// The plate left of the number, as `PlateGoal` draws it. At accessibility sizes the
    /// number needs the whole width, so the plate goes above it instead.
    private var targetDisplay: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 18))

        return layout {
            plateDrawing

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTarget.formatted())
                    .font(CalorynTheme.heroNumber(size: targetSize))
                    .tracking(-targetSize * 0.01)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: Double(displayTarget)))
                    .animation(.smooth(duration: 0.3), value: displayTarget)
                    .accessibilityIdentifier("onboarding.goalSummary.target")

                Text("kcal a day")
                    .font(CalorynTheme.cardSubtitle.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(plate.explanation)
                    .font(OnboardingTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The empty plate, sized to the target, inside a dotted ring sized to the daily burn.
    /// Both are drawn proportional to their area (`OnboardingGoalPlate`), the larger filling
    /// the frame; the board's ring sits at 97% of the frame and the plate's rim at 94%.
    private var plateDrawing: some View {
        ZStack {
            Circle()
                .stroke(
                    CalorynTheme.dataPrimary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                )
                .frame(
                    width: plateDiameter * 0.97 * plate.burnDiameterRatio,
                    height: plateDiameter * 0.97 * plate.burnDiameterRatio
                )

            CalorieDonutView(
                summary: CalorieDonutSummary(mealTotals: [:], budget: Double(displayTarget), isOver: false),
                size: plateDiameter * 0.94 * plate.plateDiameterRatio,
                animated: false
            )
        }
        .frame(width: plateDiameter, height: plateDiameter)
        .animation(.smooth(duration: 0.35), value: plate.plateDiameterRatio)
        .animation(.smooth(duration: 0.35), value: plate.burnDiameterRatio)
        .accessibilityHidden(true)
    }

    // MARK: - How fast

    private var paceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            OnboardingAdaptiveRow(alignment: .firstTextBaseline, spacing: 8) {
                OnboardingSectionTitle("How fast")
            } trailing: {
                Text(plate.paceCaption)
                    .font(OnboardingTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .contentTransition(.numericText())
            }

            OnboardingSlider(
                value: $calorieDeficit,
                range: OnboardingGoalPlate.adjustmentRange,
                step: OnboardingGoalPlate.adjustmentStep,
                label: "Daily calorie adjustment"
            )
            .disabled(draft.useManualOverride)
            .accessibilityValue(plate.paceCaption)

            scaleLabels
        }
        .opacity(draft.useManualOverride ? 0.45 : 1)
        .animation(.smooth(duration: 0.2), value: draft.useManualOverride)
    }

    /// "Gain" and "Lose" at the ends, "Keep" under the point where the adjustment is zero —
    /// a third of the way along, not the middle, because the range leans towards losing.
    ///
    /// "Keep" is pinned to a point on the track while "Gain" grows from the edge, so past
    /// the second accessibility size the two collide (from about AX4 on a 375pt phone).
    /// The labels stop growing there; they are hidden from VoiceOver, which reads the
    /// slider's own value instead.
    private var scaleLabels: some View {
        ZStack(alignment: .leading) {
            Text("Gain")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Lose")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .overlay {
            GeometryReader { proxy in
                // The thumb travels between half its own width from each end.
                let thumbInset: CGFloat = 14
                let travel = max(0, proxy.size.width - 2 * thumbInset)
                Text("Keep")
                    .fixedSize()
                    .position(
                        x: thumbInset + travel * OnboardingGoalPlate.maintenanceFraction,
                        y: proxy.size.height / 2
                    )
            }
        }
        .font(OnboardingTypography.scaleLabel)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .foregroundStyle(CalorynTheme.textSecondary)
        .accessibilityHidden(true)
    }

    // MARK: - Where the number comes from

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingSectionTitle("Where the number comes from")
                .padding(.bottom, 8)

            OnboardingHairline()
            sourceRow("At rest", value: plate.restText)
            OnboardingHairline()
            sourceRow(activityLevel.displayName.sentenceCased, value: plate.burnText)
            OnboardingHairline()
            sourceRow("Your adjustment", value: plate.adjustmentText)

            if draft.useManualOverride {
                manualTargetField
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(.smooth(duration: 0.25)) {
                    draft.useManualOverride.toggle()
                }
                isManualTargetFocused = draft.useManualOverride
            } label: {
                Text(draft.useManualOverride ? "Use the worked-out number instead" : "Set a number yourself instead")
                    .font(OnboardingTypography.link)
                    .foregroundStyle(CalorynTheme.accent)
                    .underline(true, color: CalorynTheme.separator)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func sourceRow(_ label: String, value: String) -> some View {
        OnboardingAdaptiveRow(spacing: 8) {
            Text(label)
                .font(OnboardingTypography.rowText)
                .foregroundStyle(CalorynTheme.textPrimary)
        } trailing: {
            Text(value)
                .font(OnboardingTypography.rowValue)
                .foregroundStyle(CalorynTheme.textPrimary)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var manualTargetField: some View {
        HStack(spacing: 10) {
            TextField("Calories", text: $draft.manualTargetText)
                .keyboardType(.numberPad)
                .font(CalorynTheme.numericBody)
                .focused($isManualTargetFocused)
                .calorynInputField(isFocused: isManualTargetFocused)
                .accessibilityLabel("Your daily calories")

            Text("kcal a day")
                .font(OnboardingTypography.rowText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        GoalSummaryStepView(
            age: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            activityLevel: .moderatelyActive,
            calorieDeficit: .constant(500)
        ) { _, _ in }
    }
}
