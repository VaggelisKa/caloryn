import SwiftUI

struct IngredientAmountPickerView: View {
    let ingredient: RecipeIngredientDraft
    var onSave: (RecipeIngredientDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: IngredientAmountDraft
    @FocusState private var isAmountFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var amountFieldWidth: CGFloat = 104

    init(ingredient: RecipeIngredientDraft, onSave: @escaping (RecipeIngredientDraft) -> Void) {
        self.ingredient = ingredient
        self.onSave = onSave
        self._amount = State(
            initialValue: IngredientAmountDraft(
                nutritionPer100g: ingredient.nutritionPer100g,
                initialGrams: ingredient.portionGrams
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ingredientHeader
                    caloriePreview
                    amountSection
                    macroPreview
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .calorynSheetCanvas()
            .navigationTitle("Ingredient amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FoodLogSheetTitle(title: "Ingredient amount")
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        // A `Button("Save")` has no label view to colour, and a toolbar
                        // button takes neither the AccentColor asset nor `.tint()` under
                        // Liquid Glass — only `.foregroundStyle` on the label works. The
                        // ternary keeps the disabled state visible, which a flat ink
                        // would silently throw away.
                        Text("Save")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(amount.canSave ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                    }
                    .disabled(!amount.canSave)
                }
            }
            .onAppear {
                isAmountFocused = true
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var ingredientHeader: some View {
        FoodLogSheetHeader(
            name: ingredient.name,
            lines: [ingredient.brand]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    private var caloriePreview: some View {
        FoodLogCaloriePreview(
            calories: amount.previewCalories.rounded().truncatedSafely,
            tint: CalorynTheme.textPrimary,
            identifier: "ingredientAmount.calories"
        )
    }

    /// The weight that goes into the recipe, typed into a `surface` well.
    /// The label and the well share a line, until accessibility sizes: there the label
    /// goes above, and the well, sized with the text (a fixed 104pt left about 80pt for a
    /// number that needs 99pt at AX5), takes the line under it. One layout swapped with
    /// `AnyLayout`, so the field keeps its identity and focus across the switch.
    private var amountSection: some View {
        let stacks = dynamicTypeSize.isAccessibilitySize
        let layout = stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 10))

        return VStack(alignment: .leading, spacing: 10) {
            FoodLogSectionTitle("How much")

            layout {
                Text("Measured amount")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .frame(maxWidth: stacks ? nil : .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    TextField("100", text: $amount.gramsText)
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .calorynInputField(isFocused: isAmountFocused)
                        .frame(width: min(amountFieldWidth, 220))

                    Text("g")
                        .font(CalorynTheme.bodyText)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }
        }
    }

    private var macroPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            FoodLogSectionTitle("In this amount")

            FoodLogValueRows(
                rows: [
                    FoodLogValueRows.Row(id: "protein", label: "Protein", value: amount.previewProtein.spacedMacroFormatted),
                    FoodLogValueRows.Row(id: "carbs", label: "Carbs", value: amount.previewCarbs.spacedMacroFormatted),
                    FoodLogValueRows.Row(id: "fat", label: "Fat", value: amount.previewFat.spacedMacroFormatted),
                ]
            )
        }
    }

    private func save() {
        var updated = ingredient
        updated.portionGrams = amount.grams
        onSave(updated)
        dismiss()
    }
}

#Preview {
    IngredientAmountPickerView(
        ingredient: RecipeIngredientDraft(
            name: "Tomato",
            brand: nil,
            portionGrams: 100,
            caloriesPer100g: 18,
            proteinPer100g: 0.9,
            carbsPer100g: 3.9,
            fatPer100g: 0.2,
            sortOrder: 0
        ),
        onSave: { _ in }
    )
}
