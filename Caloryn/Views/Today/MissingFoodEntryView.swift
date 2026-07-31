import SwiftUI
import SwiftData

/// Editor for a log entry whose saved food has been deleted: edits use the
/// nutrition snapshot recorded on the entry itself.
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
    @State private var errorMessage: String?

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
                    Label {
                        Text("The original saved food is missing. Editing uses the nutrition and quality values recorded in this log entry.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CalorynTheme.terracotta)
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)

                Section("Entry") {
                    LabeledContent("Food", value: entry.foodName)

                    TextField("Portion (g)", value: $portionGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Portion in grams")
                        .accessibilityIdentifier("missingEntry.portion")

                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date.now.tomorrow,
                        displayedComponents: .date
                    )

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }

                    if mealType == .snack {
                        Stepper("Snack slot: \(snackIndex)", value: $snackIndex, in: 1...20)
                            .accessibilityIdentifier("missingEntry.snackSlot")
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Log Entry", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(CalorynTheme.cardBackground)
            }
            .calorynFormStyle()
            .calorynSheetCanvas()
            .navigationTitle("Edit Portion")
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
                        Text("Save")
                            .font(CalorynTheme.toolbarAction)
                            .foregroundStyle(
                                FavoriteFoodLogging.isSafePortion(portionGrams)
                                    ? CalorynTheme.sage
                                    : CalorynTheme.textSecondary
                            )
                    }
                    .disabled(!FavoriteFoodLogging.isSafePortion(portionGrams))
                    .accessibilityIdentifier("missingEntry.save")
                }
            }
            .confirmationDialog("Delete Log Entry", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("Remove \(entry.foodName) from your log?")
            }
            .alert("Couldn’t Update Entry", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
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
