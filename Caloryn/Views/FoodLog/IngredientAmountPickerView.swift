import SwiftUI

struct IngredientAmountPickerView: View {
    let ingredient: RecipeIngredientDraft
    var onSave: (RecipeIngredientDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: IngredientAmountDraft
    @FocusState private var isAmountFocused: Bool

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
                VStack(spacing: 24) {
                    ingredientHeader
                    caloriePreview
                    amountSection
                    macroPreview
                }
                .padding(.horizontal, CalorynTheme.pagePadding)
                .padding(.bottom, 24)
            }
            .calorynSheetCanvas()
            .navigationTitle("Ingredient Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.sage)
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
                        // ternary keeps the disabled state visible, which a flat sage
                        // would silently throw away.
                        Text("Save")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(amount.canSave ? CalorynTheme.sage : CalorynTheme.textSecondary)
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
        VStack(spacing: 4) {
            Text(ingredient.name)
                .font(CalorynTheme.sectionTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .multilineTextAlignment(.center)

            if let brand = ingredient.brand, !brand.isEmpty {
                Text(brand)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .padding(.top, 8)
    }

    private var caloriePreview: some View {
        VStack(spacing: 4) {
            Text("\(Int(amount.previewCalories))")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: Int(amount.previewCalories))

            Text("calories")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .glassCard()
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AMOUNT")
                .font(CalorynTheme.sectionEyebrow)
                .foregroundStyle(CalorynTheme.textSecondary)

            HStack {
                Text("Measured amount")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer()

                TextField("100", text: $amount.gramsText)
                    .font(CalorynTheme.numericBody)
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .calorynInputField(isFocused: isAmountFocused)
                    .frame(width: 92)

                Text("g")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }
        }
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
    }

    private var macroPreview: some View {
        HStack(spacing: CalorynTheme.cardSpacing) {
            macroPill("Protein", value: amount.previewProtein, color: CalorynTheme.proteinColor)
            macroPill("Carbs", value: amount.previewCarbs, color: CalorynTheme.carbColor)
            macroPill("Fat", value: amount.previewFat, color: CalorynTheme.fatColor)
        }
    }

    private func macroPill(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(CalorynTheme.caption)
                .foregroundStyle(CalorynTheme.textSecondary)
            Text(value.macroFormatted)
                .font(CalorynTheme.numericBody)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.3), value: value.macroFormatted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)
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
