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
                value.spacedMacroFormatted
            case .milligramsFromGrams:
                "\((value * 1000).rounded().truncatedSafely.formatted()) mg"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @Binding private var item: MultiAddDraftItem
    private let destinationDescription: String
    /// The meal the batch lands in, whose ink the calorie figure takes.
    private let destinationMeal: MealType
    private let originalSnapshot: FoodLogEntrySnapshot
    private let quickGramOptions: [Int]

    @State private var portionGrams: Double
    @State private var gramsInput: String

    /// Owned here rather than inside the field, so a tap anywhere on the page
    /// can clear it. See `dismissesGramKeypadOnTap`.
    @FocusState private var isGramsFieldFocused: Bool

    init(
        item: Binding<MultiAddDraftItem>,
        destinationDescription: String,
        destinationMeal: MealType
    ) {
        _item = item
        self.destinationDescription = destinationDescription
        self.destinationMeal = destinationMeal
        let snapshot = item.wrappedValue.snapshot
        originalSnapshot = snapshot
        quickGramOptions = Self.quickGramOptions(around: snapshot.portionGrams)
        _portionGrams = State(initialValue: snapshot.portionGrams)
        _gramsInput = State(initialValue: PortionSelection.formattedGrams(snapshot.portionGrams))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                foodHeader
                caloriePreview
                portionPicker
                nutritionPreview
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .dismissesGramKeypadOnTap($isGramsFieldFocused)
        }
        // See `PortionPickerView` — interactive dismissal ignores a drag that
        // never reaches the keypad.
        .scrollDismissesKeyboard(.immediately)
        .calorynSheetCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit portion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FoodLogSheetTitle(title: "Edit portion")
            }
        }
        .foodLogBottomAction {
            Button(action: save) {
                Text("Save portion")
            }
            .calorynPrimaryButton()
            .accessibilityIdentifier("multiAdd.editor.save")
        }
    }

    private var editedSnapshot: FoodLogEntrySnapshot {
        originalSnapshot.scaled(toPortionGrams: portionGrams)
    }

    private var foodHeader: some View {
        FoodLogSheetHeader(
            name: originalSnapshot.foodName,
            lines: [destinationDescription] + (item.originMealName.map { ["Part of \($0)"] } ?? [])
        )
    }

    private var caloriePreview: some View {
        FoodLogCaloriePreview(
            calories: editedSnapshot.nutrition.calories.rounded().truncatedSafely,
            tint: destinationMeal.ink,
            detail: "\(editedSnapshot.nutrition.proteinG.spacedMacroFormatted) protein",
            identifier: "multiAdd.editor.calories"
        )
    }

    private var portionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            FoodLogSectionTitle("How much")

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
                },
                onStep: { step in
                    portionGrams = PortionSelection.stepped(portionGrams, step)
                    gramsInput = PortionSelection.formattedGrams(portionGrams)
                }
            )
        }
        .accessibilityIdentifier("multiAdd.editor.portion")
    }

    private var nutritionPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            FoodLogSectionTitle("In this portion")

            FoodLogValueRows(
                rows: nutritionDetails.map { nutrient in
                    FoodLogValueRows.Row(
                        id: nutrient.id,
                        label: nutrient.label,
                        value: nutrient.formattedValue
                    )
                }
            )
        }
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
