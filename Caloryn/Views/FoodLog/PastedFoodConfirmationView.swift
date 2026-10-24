import SwiftData
import SwiftUI

struct PastedFoodConfirmationView: View {
    let mealType: MealType
    let snackIndex: Int
    let logDate: Date
    let onAdded: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query private var entriesOnLogDate: [FoodLogEntry]

    @State private var confirmation: PastedFoodConfirmation
    @State private var showingAlreadyLoggedPrompt = false
    @State private var errorMessage: String?

    init(
        confirmation: PastedFoodConfirmation,
        mealType: MealType,
        snackIndex: Int,
        logDate: Date,
        onAdded: @escaping () -> Void
    ) {
        self.mealType = mealType
        self.snackIndex = snackIndex
        self.logDate = logDate
        self.onAdded = onAdded
        _confirmation = State(initialValue: confirmation)

        let dayStart = Calendar.current.startOfDay(for: logDate)
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) ?? .distantFuture
        _entriesOnLogDate = Query(filter: FoodLogEntryWindow.logged(in: dayStart..<dayEnd))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                PastedFoodConfirmationForm(confirmation: $confirmation, mealType: mealType)
            }
            .scrollDismissesKeyboard(.immediately)
            .calorynSheetCanvas()
            .calorynInlineTitle("Pasted food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(CalorynTheme.accent)
                    }
                    .accessibilityIdentifier("pastedFood.cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addTapped()
                    } label: {
                        Text("Add")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(
                                confirmation.canAdd ? CalorynTheme.accent : CalorynTheme.textTertiary
                            )
                    }
                    .disabled(!confirmation.canAdd)
                    .accessibilityIdentifier("pastedFood.add")
                }
            }
            .alert("Already logged — add again?", isPresented: $showingAlreadyLoggedPrompt) {
                Button("Add Again", action: add)
                    .accessibilityIdentifier("pastedFood.alreadyLogged.addAgain")
                Button("Cancel", role: .cancel) {}
                    .accessibilityIdentifier("pastedFood.alreadyLogged.cancel")
            } message: {
                Text(verbatim: confirmation.alreadyLoggedMessage(locale: locale))
            }
            .alert("Couldn’t Add Food", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private func addTapped() {
        guard confirmation.canAdd else { return }
        let isAlreadyLogged = entriesOnLogDate.contains {
            confirmation.matchesLoggedFood(named: $0.foodName, calories: $0.calories)
        }
        if isAlreadyLogged {
            showingAlreadyLoggedPrompt = true
        } else {
            add()
        }
    }

    private func add() {
        guard let portionGrams = confirmation.portionGrams else { return }
        do {
            let entry = try DailyFoodLogCommands.logImported(
                name: confirmation.name,
                calories: confirmation.kcal,
                portionGrams: portionGrams,
                proteinG: confirmation.proteinG,
                carbsG: confirmation.carbsG,
                fatG: confirmation.fatG,
                mealType: mealType,
                snackIndex: snackIndex,
                logDate: logDate,
                modelContext: modelContext
            )
            do {
                try modelContext.save()
            } catch {
                modelContext.delete(entry)
                throw error
            }
            CalorynHaptics.success()
            onAdded()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

struct PastedFoodConfirmationForm: View {
    @Binding var confirmation: PastedFoodConfirmation
    let mealType: MealType

    @Environment(\.locale) private var locale
    @FocusState private var isGramsFocused: Bool
    @ScaledMetric(relativeTo: .title) private var nameSize: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            CreationFormSection(
                "Nutrition",
                footer: "Totals for the whole portion, as your chatbot sent them. Changing the portion weight doesn’t change them."
            ) {
                valueRow("Calories", value: confirmation.caloriesText(locale: locale), identifier: "pastedFood.calories")
                ForEach(PastedFoodConfirmation.Macro.allCases, id: \.self) { macro in
                    valueRow(
                        macro.label,
                        value: confirmation.amountText(of: macro, locale: locale),
                        identifier: "pastedFood.\(macro.label.lowercased())"
                    )
                }
            }

            CreationFormSection("Portion and meal") {
                portionRow
                mealRow
            }
        }
        .padding(.horizontal, CalorynTheme.pagePadding)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: confirmation.name)
                .font(CalorynTypeface.fixed(size: nameSize, weight: .heavy))
                .tracking(-nameSize * 0.005)
                .foregroundStyle(CalorynTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("pastedFood.name")

            Text("Nothing is saved until you tap Add.")
                .font(CalorynTypeface.text(.subheadline))
                .foregroundStyle(CalorynTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueRow(_ label: String, value: String, identifier: String) -> some View {
        CreationFormSheetRow {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(verbatim: label)
                    .font(CreationFormTypography.rowLabel)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text(verbatim: value)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(
                        value == PastedFoodConfirmation.notProvided
                            ? CalorynTheme.textSecondary
                            : CalorynTheme.textPrimary
                    )
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(identifier)
        }
    }

    private var portionRow: some View {
        CreationFormSheetRow {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Portion")
                        .font(CreationFormTypography.rowLabel)
                        .foregroundStyle(CalorynTheme.textPrimary)
                        .accessibilityHidden(true)

                    Spacer(minLength: 8)

                    TextField("0", text: $confirmation.gramsInput)
                        .font(CalorynTheme.numericBody)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($isGramsFocused)
                        .frame(maxWidth: 112)
                        .calorynInputField(isFocused: isGramsFocused)
                        .accessibilityLabel("Portion in grams")
                        .accessibilityIdentifier("pastedFood.grams")

                    Text("g")
                        .font(CreationFormTypography.rowLabel)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityHidden(true)
                }

                if let reason = confirmation.addBlockedReason(locale: locale) {
                    Label {
                        Text(verbatim: reason)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                    }
                    .font(CreationFormTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("pastedFood.addBlockedReason")
                }
            }
        }
    }

    private var mealRow: some View {
        CreationFormSheetRow {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Meal")
                    .font(CreationFormTypography.rowLabel)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text(verbatim: mealType.displayName)
                    .font(CreationFormTypography.rowLabel.weight(.semibold))
                    .foregroundStyle(mealType.ink)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("pastedFood.meal")
        }
    }
}
