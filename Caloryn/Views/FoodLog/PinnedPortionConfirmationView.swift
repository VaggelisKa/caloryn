import SwiftData
import SwiftUI

struct PinnedPortionConfirmationView: View {
    let foodItem: FoodItem
    let mealType: MealType
    let logDate: Date
    let snackIndex: Int
    var onLogged: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var portionGrams: Double
    @State private var errorMessage: String?

    init(
        foodItem: FoodItem,
        mealType: MealType,
        logDate: Date,
        snackIndex: Int = 0,
        onLogged: (() -> Void)? = nil
    ) {
        self.foodItem = foodItem
        self.mealType = mealType
        self.logDate = logDate
        self.snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: mealType,
            requestedSnackIndex: snackIndex
        )
        self.onLogged = onLogged
        _portionGrams = State(initialValue: PinnedFoodLogging.suggestedPortion(for: foodItem))
    }

    private var destinationDescription: String {
        "\(logDate.shortFormatted) · \(mealType.displayName(snackIndex: snackIndex))"
    }

    private var maximumPortion: Double {
        PinnedFoodLogging.maximumConfirmationPortion(for: foodItem)
    }

    private var calories: Double {
        foodItem.calories(forGrams: portionGrams)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 5) {
                    Text(foodItem.name)
                        .font(CalorynTheme.sectionTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Label(destinationDescription, systemImage: "calendar")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
                .accessibilityElement(children: .combine)

                VStack(spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Quantity")
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textPrimary)

                        Spacer()

                        Text("\(Int(portionGrams.rounded()))g")
                            .font(CalorynTheme.compactNumber)
                            .foregroundStyle(CalorynTheme.sage)
                            .contentTransition(.numericText())
                    }

                    Stepper(
                        "Portion in grams",
                        value: $portionGrams,
                        in: 5...maximumPortion,
                        step: 5
                    )
                    .labelsHidden()
                    .accessibilityLabel("Portion for \(foodItem.name)")
                    .accessibilityValue("\(Int(portionGrams.rounded())) grams")

                    Divider()

                    HStack {
                        Text("Calories")
                            .font(CalorynTheme.bodyText)
                            .foregroundStyle(CalorynTheme.textSecondary)
                        Spacer()
                        Text("\(Int(calories.rounded())) kcal")
                            .font(CalorynTheme.numericBody)
                            .foregroundStyle(CalorynTheme.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
                .glassCard(cornerRadius: CalorynTheme.smallCornerRadius)

                Button(action: logConfirmedPortion) {
                    Label("Log to \(mealType.displayName)", systemImage: "plus.circle.fill")
                        .font(CalorynTheme.buttonLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .adaptiveGlassProminentButton()
                .tint(CalorynTheme.sage)
                .accessibilityLabel(
                    "Log \(foodItem.name), \(Int(portionGrams.rounded())) grams, to \(destinationDescription)"
                )
                .accessibilityHint("Adds this portion to the selected day and meal")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 8)
            .calorynPageCanvas()
            .navigationTitle("Choose Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Couldn’t Log Favorite", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func logConfirmedPortion() {
        let plan = PinnedFoodLogging.confirmedPlan(
            for: foodItem,
            portionGrams: portionGrams,
            destinationMeal: mealType,
            destinationDate: logDate,
            destinationSnackIndex: snackIndex
        )

        do {
            try PinnedFoodLogging.log(
                plan: plan,
                food: foodItem,
                modelContext: modelContext
            )
            dismiss()
            onLogged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }
}

#Preview("Pinned quantity confirmation") {
    let food = FoodItem(
        name: "Morning Skyr",
        brand: "Arla",
        caloriesPer100g: 63,
        proteinPer100g: 11,
        carbsPer100g: 4,
        fatPer100g: 0,
        defaultServingG: 170,
        servingDescription: "1 cup (170g)"
    )
    return PinnedPortionConfirmationView(
        foodItem: food,
        mealType: .breakfast,
        logDate: .now
    )
    .modelContainer(
        for: [UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self],
        inMemory: true
    )
}
