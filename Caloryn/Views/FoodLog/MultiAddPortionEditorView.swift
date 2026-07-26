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
                "\(Int((value * 1000).rounded()))mg"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    @Binding private var item: MultiAddDraftItem
    private let destinationDescription: String
    private let originalSnapshot: FoodLogEntrySnapshot
    private let portionOptions: [Double]

    @State private var portionGrams: Double

    init(
        item: Binding<MultiAddDraftItem>,
        destinationDescription: String
    ) {
        _item = item
        self.destinationDescription = destinationDescription
        let snapshot = item.wrappedValue.snapshot
        originalSnapshot = snapshot
        portionOptions = Self.portionOptions(around: snapshot.portionGrams)
        _portionGrams = State(initialValue: snapshot.portionGrams)
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
        }
        .calorynSheetCanvas()
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
            Text("\(Int(editedSnapshot.nutrition.calories.rounded()))")
                .font(CalorynTheme.displayNumber)
                .foregroundStyle(CalorynTheme.sage)
                .contentTransition(.numericText())
                .animation(
                    .smooth(duration: 0.3),
                    value: Int(editedSnapshot.nutrition.calories.rounded())
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

            Picker("Portion in grams", selection: $portionGrams) {
                ForEach(portionOptions, id: \.self) { grams in
                    Text(Self.formattedPickerValue(grams))
                        .tag(grams)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .clipped()
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

                Text("\(Self.formattedPickerValue(portionGrams))g")
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

    private func save() {
        item.snapshot = editedSnapshot
        dismiss()
    }

    private static func portionOptions(around initialPortion: Double) -> [Double] {
        let maximum = max(500, Int(ceil(initialPortion * 4 / 5) * 5))
        var values = stride(from: 5, through: maximum, by: 5).map(Double.init)
        if initialPortion > 0, !values.contains(initialPortion) {
            values.append(initialPortion)
            values.sort()
        }
        return values
    }

    private static func formattedPickerValue(_ grams: Double) -> String {
        if grams.rounded() == grams {
            return "\(Int(grams))"
        }
        return grams.formatted(.number.precision(.fractionLength(0...1)))
    }
}
