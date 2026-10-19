import SwiftUI
import SwiftData

struct MissingFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: FoodLogEntry
    let onDelete: () -> Void

    @State private var date: Date
    @State private var mealType: MealType
    @State private var snackIndex: Int
    @State private var portionGrams: Double
    @State private var showingDeleteConfirmation = false
    @State private var isPickingDate = false
    @State private var errorMessage: String?
    @FocusState private var isPortionFocused: Bool

    init(entry: FoodLogEntry, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.onDelete = onDelete
        _date = State(initialValue: entry.date)
        _mealType = State(initialValue: entry.mealType)
        _snackIndex = State(initialValue: max(1, entry.snackIndex))
        _portionGrams = State(initialValue: entry.portionGrams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("The original saved food is missing. Editing uses the nutrition and quality values recorded in this log entry.")
                        .font(TodayPlateFont.detailsNote)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(CalorynTheme.backgroundSecondary)
                .listRowSeparatorTint(CalorynTheme.separator)

                Section {
                    LabeledContent("Food") {
                        Text(entry.foodName)
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }

                    LabeledContent("Portion") {
                        HStack(spacing: 6) {
                            TextField("Portion (g)", value: $portionGrams, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .monospacedDigit()
                                .focused($isPortionFocused)
                                .accessibilityLabel("Portion in grams")
                                .accessibilityIdentifier("missingEntry.portion")
                                .frame(maxWidth: 96)
                                .calorynInputField(isFocused: isPortionFocused)

                            Text("g")
                                .foregroundStyle(CalorynTheme.textSecondary)
                                .accessibilityHidden(true)
                        }
                    }

                    dateRow

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Meal")

                        mealChips
                    }
                    .padding(.vertical, 4)

                    if mealType == .snack {
                        HStack(spacing: 12) {
                            Text("Snack slot")
                                .accessibilityHidden(true)

                            Spacer(minLength: 8)

                            CalorynStepperPill(
                                accessibilityTitle: "Snack slot",
                                value: "\(snackIndex)",
                                size: .compact,
                                canDecrement: snackIndex > Self.snackSlots.lowerBound,
                                canIncrement: snackIndex < Self.snackSlots.upperBound,
                                onDecrement: { snackIndex = max(Self.snackSlots.lowerBound, snackIndex - 1) },
                                onIncrement: { snackIndex = min(Self.snackSlots.upperBound, snackIndex + 1) }
                            )
                            .accessibilityIdentifier("missingEntry.snackSlot")
                        }
                    }
                } header: {
                    sectionHeader("Entry")
                }
                .foregroundStyle(CalorynTheme.textPrimary)
                .listRowBackground(CalorynTheme.backgroundSecondary)
                .listRowSeparatorTint(CalorynTheme.separator)

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Delete log entry")
                            .foregroundStyle(CalorynTheme.accent)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(CalorynTheme.backgroundSecondary)
            }
            .calorynFormStyle()
            .calorynSheetCanvas()
            .calorynInlineTitle("Edit portion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(CalorynTheme.accent)
                    }
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(
                                FavoriteFoodLogging.isSafePortion(portionGrams)
                                    ? CalorynTheme.accent
                                    : CalorynTheme.textTertiary
                            )
                    }
                    .disabled(!FavoriteFoodLogging.isSafePortion(portionGrams))
                    .accessibilityIdentifier("missingEntry.save")
                }
            }
            .confirmationDialog("Delete log entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Remove \(entry.foodName) from your log?")
            }
            .alert("Couldn’t update entry", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private static let snackSlots = 1...20

    @ViewBuilder
    private var dateRow: some View {
        Button {
            withAnimation(.smooth(duration: 0.25)) {
                isPickingDate.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Text("Date")
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Text(date, format: .dateTime.day().month(.abbreviated).year())
                    .foregroundStyle(isPickingDate ? CalorynTheme.textPrimary : CalorynTheme.textSecondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Date")
        .accessibilityValue(Text(date, format: .dateTime.day().month(.wide).year()))
        .accessibilityHint(isPickingDate ? "Double tap to close the calendar" : "Double tap to choose a date")
        .accessibilityIdentifier("missingEntry.date")

        if isPickingDate {
            DatePicker(
                "Date",
                selection: $date,
                in: ...Date.now.tomorrow,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(CalorynTheme.accentControl)
        }
    }

    private var mealChips: some View {
        ChipFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(MealType.allCases) { meal in
                Button {
                    if mealType != meal { CalorynHaptics.selectionChanged() }
                    mealType = meal
                } label: {
                    Text(meal.displayName)
                        .calorynChip(isSelected: mealType == meal, meal: meal)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(meal.displayName)
                .accessibilityAddTraits(mealType == meal ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meal")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CalorynTheme.sectionHeaderTitle)
            .foregroundStyle(CalorynTheme.textPrimary)
            .textCase(nil)
    }

    private func save() {
        do {
            try DailyFoodLogCommands.saveSnapshotEntry(
                entry,
                date: date,
                mealType: mealType,
                portionGrams: portionGrams,
                modelContext: modelContext,
                snackIndex: snackIndex
            )
            CalorynHaptics.success()
            dismiss()
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
