import SwiftUI
import SwiftData

private let nutrientGoalExpansionAnimation = Animation.smooth(duration: 0.24)
private let nutrientGoalAnimationDuration: TimeInterval = 0.24

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
            Section {
                Toggle(isOn: $draft.manualOverride) {
                    SettingsToggleLabel(title: "Manual override")
                }
                .accessibilityIdentifier("goalEdit.manualOverride")
                .onChange(of: draft.manualOverride) { _, isManual in
                    draft.manualOverrideChanged(to: isManual, tdee: profile.tdee)
                }

                if draft.manualOverride {
                    HStack(spacing: 10) {
                        TextField("Target", text: $draft.targetText)
                            .keyboardType(.numberPad)
                            .font(CalorynTheme.numericBody)
                            .foregroundStyle(CalorynTheme.textPrimary)
                            .focused($focusedField, equals: .manualTarget)
                            .calorynInputField(isFocused: focusedField == .manualTarget)
                            .accessibilityIdentifier("goalEdit.target")
                        Text("kcal")
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                } else {
                    SettingsValueRow(
                        title: "Estimated daily burn",
                        value: "\(profile.tdee.truncatedSafely) kcal"
                    )
                    SettingsValueRow(title: "Target", value: "\(calculatedTarget) kcal", valueIsInk: true)
                }
            } header: {
                SettingsSectionTitle("Daily calorie target")
            }
            .listRowBackground(CalorynTheme.cardBackground)

            if !draft.manualOverride {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(draft.deficitLabel)
                            .font(CalorynTheme.itemTitle.monospacedDigit())
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Slider(value: $draft.calorieDeficit, in: -500...1000, step: 50)
                            .tint(CalorynTheme.textPrimary)
                            .accessibilityLabel("Calorie adjustment")
                            .accessibilityValue(draft.deficitLabel)

                        HStack {
                            Text("Surplus")
                            Spacer()
                            Text("Deficit")
                        }
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                } header: {
                    SettingsSectionTitle("Calorie adjustment")
                } footer: {
                    SettingsSectionFooter("Positive values create a deficit for weight loss, negative values create a surplus for weight gain.")
                }
                .listRowBackground(CalorynTheme.cardBackground)
            }

            Section {
                MacroGoalSliderRow(
                    name: "Protein",
                    ratio: $draft.proteinRatio,
                    range: 0.10...0.50,
                    gramsText: previewProteinTarget.spacedMacroFormatted
                )
                MacroGoalSliderRow(
                    name: "Carbs",
                    ratio: $draft.carbRatio,
                    range: 0.10...0.60,
                    gramsText: previewCarbTarget.spacedMacroFormatted
                )
                MacroGoalSliderRow(
                    name: "Fat",
                    ratio: $draft.fatRatio,
                    range: 0.10...0.50,
                    gramsText: previewFatTarget.spacedMacroFormatted
                )

                if !draft.isMacroValid {
                    SettingsWarningText("Ratios should total 100% (currently \((draft.macroTotal * 100).truncatedSafely)%)")
                }
            } header: {
                SettingsSectionTitle("Macro goals")
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
                    SettingsWarningText("Goal values must be positive numbers. Leave a field blank to remove that goal.")
                }
            } header: {
                SettingsSectionTitle("Additional nutrient goals")
            } footer: {
                SettingsSectionFooter("These goals appear anywhere the nutrient is shown. Sodium and cholesterol are entered in milligrams.")
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .calorynInlineTitle("Edit goal")
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
                        .foregroundStyle(draft.canSave ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
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

/// One macro's share of the day: its name, the grams the share comes to, the percentage in
/// ink, and an ink slider. Macros are told apart by name, never colour.
private struct MacroGoalSliderRow: View {
    let name: String
    @Binding var ratio: Double
    let range: ClosedRange<Double>
    let gramsText: String

    private var percentText: String { "\((ratio * 100).truncatedSafely)%" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text(gramsText)
                    .font(CalorynTheme.cardSubtitle.monospacedDigit())
                    .foregroundStyle(CalorynTheme.textSecondary)

                Text(percentText)
                    .font(CalorynTheme.numericBody.weight(.semibold))
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .accessibilityHidden(true)

            Slider(value: $ratio, in: range, step: 0.05)
                .tint(CalorynTheme.textPrimary)
                .accessibilityLabel(name)
                .accessibilityValue("\(percentText), \(gramsText)")
        }
        .padding(.vertical, 2)
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
        VStack(alignment: .leading, spacing: isGoalTypePickerVisible ? 10 : 0) {
            HStack(spacing: 10) {
                Text(nutrient.displayName.sentenceCased)
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                if isInvalid {
                    // The field's own text stays ink; this glyph says which field the
                    // group's warning is about, without leaning on a colour.
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(CalorynTheme.compactIcon)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .accessibilityHidden(true)
                }

                TextField("Optional", text: $targetText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .nutrient(nutrient))
                    .multilineTextAlignment(.trailing)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .calorynInputField(isFocused: focusedField == .nutrient(nutrient))
                    .frame(width: 92)
                    .accessibilityLabel("\(nutrient.displayName) goal in \(nutrient.unit.inputUnitLabel)")
                    .accessibilityValue(isInvalid ? "\(targetText), not a valid goal" : targetText)

                Text(nutrient.unit.inputUnitLabel)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
            }

            if isGoalTypePickerRendered {
                goalKindChips
                    .frame(height: isGoalTypePickerVisible ? nil : 0, alignment: .top)
                    .opacity(isGoalTypePickerVisible ? 1 : 0)
                    .scaleEffect(y: isGoalTypePickerVisible ? 1 : 0.97, anchor: .top)
                    .clipped()
                    .allowsHitTesting(isGoalTypePickerVisible)
                    .accessibilityHidden(!isGoalTypePickerVisible)
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

    /// Minimum / Target / Maximum as chips: a small choice, so the vocabulary's chips rather
    /// than a segmented control, which ignores the ink tint. A wrapping layout, so at
    /// accessibility text sizes the three choices go onto further lines instead of being
    /// cut to a few letters each.
    private var goalKindChips: some View {
        ChipFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(NutrientGoalKind.allCases) { kind in
                Button {
                    goalKind = kind
                } label: {
                    Text(kind.displayName)
                        .calorynChip(isSelected: goalKind == kind)
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(goalKind == kind ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(nutrient.displayName) goal type")
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
