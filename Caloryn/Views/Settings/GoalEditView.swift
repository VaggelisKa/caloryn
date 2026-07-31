import SwiftUI
import SwiftData

private let nutrientGoalExpansionAnimation = Animation.smooth(duration: 0.24)
private let nutrientGoalAnimationDuration: TimeInterval = 0.24
private let nutrientGoalPickerHeight: CGFloat = 32

private enum GoalEditFocus: Hashable {
    case manualTarget
    case nutrient(TrackedNutrient)
}

struct GoalEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: GoalEditFocus?

    /// Every rule this screen applies lives in the draft; the view reads it and
    /// renders. See `GoalEditDraft`.
    @State private var draft: GoalEditDraft

    init(profile: UserProfile) {
        self.profile = profile
        _draft = State(initialValue: GoalEditDraft(profile: profile))
    }

    private var calculatedTarget: Int { draft.calculatedTarget(tdee: profile.tdee) }
    private var previewProteinTarget: Double { draft.proteinTargetGrams(tdee: profile.tdee) }
    private var previewCarbTarget: Double { draft.carbTargetGrams(tdee: profile.tdee) }
    private var previewFatTarget: Double { draft.fatTargetGrams(tdee: profile.tdee) }

    var body: some View {
        Form {
            Section("Daily Calorie Target") {
                Toggle("Manual Override", isOn: $draft.manualOverride)
                    .accessibilityIdentifier("goalEdit.manualOverride")
                    .onChange(of: draft.manualOverride) { _, isManual in
                        draft.manualOverrideChanged(to: isManual, tdee: profile.tdee)
                    }

                if draft.manualOverride {
                    HStack {
                        TextField("Target", text: $draft.targetText)
                            .keyboardType(.numberPad)
                            .font(CalorynTheme.numericBody)
                            .focused($focusedField, equals: .manualTarget)
                            .calorynInputField(isFocused: focusedField == .manualTarget)
                            .accessibilityIdentifier("goalEdit.target")
                        Text("kcal")
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                } else {
                    LabeledContent("Estimated Daily Burn", value: "\(profile.tdee.truncatedSafely) kcal")
                    LabeledContent("Target", value: "\(calculatedTarget) kcal")
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            if !draft.manualOverride {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Surplus")
                                .font(CalorynTheme.microCaption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                            Slider(value: $draft.calorieDeficit, in: -500...1000, step: 50)
                            Text("Deficit")
                                .font(CalorynTheme.microCaption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        Text(draft.deficitLabel)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.terracotta)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } header: {
                    Text("Calorie Adjustment")
                } footer: {
                    Text("Positive values create a deficit for weight loss, negative values create a surplus for weight gain.")
                }
                .listRowBackground(CalorynTheme.cardBackground)
            }

            Section("Macro Goals") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protein: \((draft.proteinRatio * 100).truncatedSafely)% · \(previewProteinTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.proteinRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.proteinColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carbs: \((draft.carbRatio * 100).truncatedSafely)% · \(previewCarbTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.carbRatio, in: 0.10...0.60, step: 0.05)
                        .tint(CalorynTheme.carbColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fat: \((draft.fatRatio * 100).truncatedSafely)% · \(previewFatTarget.macroFormatted)")
                        .font(CalorynTheme.numericBody)
                    Slider(value: $draft.fatRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.fatColor)
                }

                if !draft.isMacroValid {
                    Text("Ratios should total 100% (currently \((draft.macroTotal * 100).truncatedSafely)%)")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                ForEach(TrackedNutrient.editableGoalNutrients) { nutrient in
                    NutrientGoalEditRow(
                        nutrient: nutrient,
                        targetText: targetTextBinding(for: nutrient),
                        goalKind: goalKindBinding(for: nutrient),
                        isInvalid: draft.isInvalidTarget(for: nutrient),
                        focusedField: $focusedField
                    )
                }

                if !draft.areNutrientGoalsValid {
                    Text("Goal values must be positive numbers. Leave a field blank to remove that goal.")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            } header: {
                Text("Additional Nutrient Goals")
            } footer: {
                Text("These goals appear anywhere the nutrient is shown. Sodium and cholesterol are entered in milligrams.")
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if draft.disablesAppleHealthAdjustment {
                        AppleHealthAdjustmentSettings.disable()
                    }
                    draft.apply(to: profile)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(draft.canSave ? CalorynTheme.sage : CalorynTheme.textSecondary)
                }
                .accessibilityIdentifier("goalEdit.save")
                .disabled(!draft.canSave)
            }
        }
        .onAppear {
            draft.loadNutrientGoals(from: profile)
        }
    }

    private func targetTextBinding(for nutrient: TrackedNutrient) -> Binding<String> {
        Binding(
            get: { draft.targetText(for: nutrient) },
            set: { newValue in
                guard draft.targetText(for: nutrient) != newValue else { return }
                draft.nutrientTargetTexts[nutrient] = newValue
            }
        )
    }

    private func goalKindBinding(for nutrient: TrackedNutrient) -> Binding<NutrientGoalKind> {
        Binding(
            get: { draft.goalKind(for: nutrient) },
            set: { draft.nutrientGoalKinds[nutrient] = $0 }
        )
    }
}

private struct NutrientGoalEditRow: View {
    let nutrient: TrackedNutrient
    @Binding var targetText: String
    @Binding var goalKind: NutrientGoalKind
    let isInvalid: Bool
    @FocusState.Binding var focusedField: GoalEditFocus?
    @State private var isGoalTypePickerRendered = false
    @State private var isGoalTypePickerVisible = false

    private var hasValue: Bool {
        NutrientGoalPickerVisibility.isVisible(targetText: targetText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isGoalTypePickerVisible ? 8 : 0) {
            HStack(spacing: 10) {
                Label(nutrient.displayName, systemImage: nutrient.systemImage)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                TextField("Optional", text: $targetText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .nutrient(nutrient))
                    .multilineTextAlignment(.trailing)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(isInvalid ? CalorynTheme.terracotta : CalorynTheme.textPrimary)
                    .calorynInputField(isFocused: focusedField == .nutrient(nutrient))
                    .frame(width: 92)
                    .accessibilityLabel("\(nutrient.displayName) goal in \(nutrient.unit.inputUnitLabel)")

                Text(nutrient.unit.inputUnitLabel)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
            }

            if isGoalTypePickerRendered {
                Picker("Goal type", selection: $goalKind) {
                    ForEach(NutrientGoalKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: isGoalTypePickerVisible ? nutrientGoalPickerHeight : 0, alignment: .top)
                .opacity(isGoalTypePickerVisible ? 1 : 0)
                .scaleEffect(y: isGoalTypePickerVisible ? 1 : 0.97, anchor: .top)
                .clipped()
                .allowsHitTesting(isGoalTypePickerVisible)
                .accessibilityHidden(!isGoalTypePickerVisible)
                .accessibilityLabel("\(nutrient.displayName) goal type")
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            isGoalTypePickerRendered = hasValue
            isGoalTypePickerVisible = hasValue
        }
        .onChange(of: hasValue) { _, shouldShow in
            updateGoalTypePickerVisibility(shouldShow)
        }
    }

    private func updateGoalTypePickerVisibility(_ shouldShow: Bool) {
        if shouldShow {
            isGoalTypePickerRendered = true
            DispatchQueue.main.async {
                guard hasValue else { return }
                withAnimation(nutrientGoalExpansionAnimation) {
                    isGoalTypePickerVisible = true
                }
            }
        } else {
            withAnimation(nutrientGoalExpansionAnimation) {
                isGoalTypePickerVisible = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + nutrientGoalAnimationDuration) {
                guard !hasValue else { return }
                isGoalTypePickerRendered = false
            }
        }
    }
}
