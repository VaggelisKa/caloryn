import SwiftUI

struct MultiAddPortionEditorView: View {
    private struct Nutrient: Identifiable {
        enum Unit {
            case grams
            case milligramsFromGrams
        }

        let id: String
        let label: String
        let value: Double
        let unit: Unit

        var formattedValue: String {
            switch unit {
            case .grams:
                value.macroFormatted
            case .milligramsFromGrams:
                "\((value * 1000).rounded().truncatedSafely)mg"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @Binding private var item: MultiAddDraftItem
    private let destinationDescription: String
    private let originalSnapshot: FoodLogEntrySnapshot
    private let quickGramOptions: [Int]

    @State private var portionGrams: Double
    @State private var gramsInput: String

    /// Owned here rather than inside the field, so a tap anywhere on the page
    /// can clear it. See `dismissesGramKeypadOnTap`.
    @FocusState private var isGramsFieldFocused: Bool

    init(
        item: Binding<MultiAddDraftItem>,
        destinationDescription: String
    ) {
        _item = item
        self.destinationDescription = destinationDescription
        let snapshot = item.wrappedValue.snapshot
        originalSnapshot = snapshot
        quickGramOptions = Self.quickGramOptions(around: snapshot.portionGrams)
        _portionGrams = State(initialValue: snapshot.portionGrams)
        _gramsInput = State(initialValue: PortionSelection.formattedGrams(snapshot.portionGrams))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                foodHeader
                caloriePreview
                portionPicker
                nutritionPreview
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.bottom, 100)
            .dismissesGramKeypadOnTap($isGramsFieldFocused)
        }
        // See `PortionPickerView` — interactive dismissal ignores a drag that
        // never reaches the keypad.
        .scrollDismissesKeyboard(.immediately)
        .calorynSheetCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit Portion")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: save) {
                    Text("Save Portion")
                        .font(CalorynTheme.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .adaptiveGlassProminentButton()
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
                .accessibilityIdentifier("multiAdd.editor.save")
            }
            .background(.regularMaterial)
        }
    }

    private var editedSnapshot: FoodLogEntrySnapshot {
        originalSnapshot.scaled(toPortionGrams: portionGrams)
    }

    private var foodHeader: some View {
        VStack(spacing: 4) {
            Text(originalSnapshot.foodName)
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text(destinationDescription)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)

            if let mealName = item.originMealName {
                Text("From Meal: \(mealName)")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var caloriePreview: some View {
        VStack(spacing: 4) {
            Text("\(editedSnapshot.nutrition.calories.rounded().truncatedSafely)")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .contentTransition(.numericText())
                .animation(
                    .smooth(duration: 0.3),
                    value: editedSnapshot.nutrition.calories.rounded().truncatedSafely
                )

            Text("calories")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    private var portionPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PORTION SIZE")

                Spacer()

                Text("GRAMS")
            }
            .font(CalorynTheme.sectionEyebrow)
            .foregroundStyle(CalorynTheme.textSecondary)

            GramAmountField(
                text: $gramsInput,
                quickOptions: quickGramOptions,
                identifierPrefix: "multiAdd.editor",
                isFocused: $isGramsFieldFocused,
                onTextChange: {
                    // The calorie readout follows every keystroke; text that is
                    // not yet a number leaves the portion alone.
                    if let typed = PortionSelection.parsedGrams(gramsInput) {
                        portionGrams = Double(typed)
                    }
                },
                onCommit: commitGramsInput,
                onQuickOption: { grams in
                    portionGrams = Double(grams)
                    gramsInput = PortionSelection.formattedGrams(portionGrams)
                }
            )
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
        .accessibilityIdentifier("multiAdd.editor.portion")
    }

    private var nutritionPreview: some View {
        let nutrients = nutritionDetails

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NUTRITION")
                    .font(CalorynTheme.sectionEyebrow)
                    .foregroundStyle(CalorynTheme.textSecondary)

                Spacer()

                Text("\(PortionSelection.formattedGrams(portionGrams))g")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.3), value: portionGrams)
            }

            VStack(spacing: 0) {
                ForEach(nutrients) { nutrient in
                    nutrientRow(nutrient)
                        .padding(.vertical, 7)

                    if nutrient.id != nutrients.last?.id {
                        Divider()
                            .foregroundStyle(CalorynTheme.stone.opacity(0.3))
                    }
                }
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var nutritionDetails: [Nutrient] {
        let nutrition = editedSnapshot.nutrition
        return [
            Nutrient(id: "protein", label: "Protein", value: nutrition.proteinG, unit: .grams),
            Nutrient(id: "carbs", label: "Carbs", value: nutrition.carbsG, unit: .grams),
            Nutrient(id: "fat", label: "Fat", value: nutrition.fatG, unit: .grams),
            Nutrient(id: "fiber", label: "Fiber", value: nutrition.fiberG, unit: .grams),
            nutrient("sugars", "Sugars", nutrition.sugarsG),
            nutrient("saturated-fat", "Saturated fat", nutrition.saturatedFatG),
            nutrient(
                "sodium",
                "Sodium",
                nutrition.sodiumG,
                unit: .milligramsFromGrams
            )
        ].compactMap { $0 }
    }

    private func nutrientRow(_ nutrient: Nutrient) -> some View {
        HStack {
            Text(nutrient.label)
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)

            Spacer()

            Text(nutrient.formattedValue)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(CalorynTheme.textPrimary)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: nutrient.formattedValue)
        }
        .accessibilityElement(children: .combine)
    }

    private func nutrient(
        _ id: String,
        _ label: String,
        _ value: Double?,
        unit: Nutrient.Unit = .grams
    ) -> Nutrient? {
        value.map { Nutrient(id: id, label: label, value: $0, unit: unit) }
    }

    private func commitGramsInput() {
        if let typed = PortionSelection.parsedGrams(gramsInput) {
            portionGrams = Double(typed)
        }
        gramsInput = PortionSelection.formattedGrams(portionGrams)
    }

    private func save() {
        // The keypad need not have been dismissed, so an uncommitted edit
        // would otherwise be dropped on the way out.
        commitGramsInput()
        item.snapshot = editedSnapshot
        dismiss()
    }

    /// There is no `FoodItem` here — a draft item carries only a snapshot — so
    /// the shortcuts scale off the portion being edited rather than off a
    /// serving size, falling back to round numbers when that is unusable.
    private static func quickGramOptions(around initialPortion: Double) -> [Int] {
        guard initialPortion.isFinite, initialPortion > 0 else {
            return PortionSelection.fallbackQuickGramOptions
        }
        let options = [0.5, 1, 2]
            .map { (initialPortion * $0).rounded() }
            .filter { $0 >= Double(PortionSelection.minimumGrams) && $0 <= Double(PortionSelection.maximumGrams) }
            .map(\.truncatedSafely)

        let deduplicated = NSOrderedSet(array: options).array as? [Int] ?? []
        return deduplicated.count == PortionSelection.quickGramOptionCount
            ? deduplicated
            : PortionSelection.fallbackQuickGramOptions
    }
}
