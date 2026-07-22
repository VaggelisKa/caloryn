import SwiftData
import SwiftUI

struct MultiAddReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let onLogged: () -> Void

    @State private var items: [MultiAddDraftItem]
    private let destinationDate: Date
    private let destinationMeal: MealType
    private let destinationSnackIndex: Int
    @State private var operationID: UUID
    @State private var isCommitting = false
    @State private var recoveryState: MultiAddPartialBatch?
    @State private var errorMessage: String?

    init(
        groups: [MultiAddSelectionGroup],
        initialDate: Date,
        initialMeal: MealType,
        initialSnackIndex: Int = 0,
        operationID: UUID = UUID(),
        initialRecoveryState: MultiAddPartialBatch? = nil,
        onLogged: @escaping () -> Void
    ) {
        self.onLogged = onLogged
        _items = State(initialValue: groups.flatMap(\.items))
        destinationDate = initialDate.startOfDay
        destinationMeal = initialMeal
        destinationSnackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: initialMeal,
            requestedSnackIndex: initialSnackIndex
        )
        _operationID = State(initialValue: operationID)
        _recoveryState = State(initialValue: initialRecoveryState)
    }

    var body: some View {
        NavigationStack {
            Form {
                destinationSection

                if let recoveryState {
                    recoverySection(recoveryState)
                }

                itemsSection

                Section {
                    Button {
                        commit()
                    } label: {
                        if isCommitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(commitTitle, systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(CalorynTheme.sage)
                    .disabled(isCommitting || items.isEmpty || recoveryState != nil)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("multiAdd.commit")
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isCommitting)
                }
            }
            .interactiveDismissDisabled(isCommitting)
            .alert("Couldn’t Add Items", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
        }
    }

    private var destinationSection: some View {
        Section {
            LabeledContent("Date", value: destinationDate.shortFormatted)
                .accessibilityIdentifier("multiAdd.destinationDate")

            LabeledContent(
                "Meal",
                value: destinationMeal.displayName(snackIndex: destinationSnackIndex)
            )
            .accessibilityIdentifier("multiAdd.destinationMeal")

            Text(destinationSummary)
                .font(.footnote)
                .foregroundStyle(CalorynTheme.textSecondary)
                .accessibilityIdentifier("multiAdd.destinationSummary")
        } header: {
            Text("Destination")
        }
    }

    private var itemsSection: some View {
        Section {
            ForEach($items) { $item in
                reviewRow(item: $item)
            }
        } header: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selected Items")
                Label(destinationDescription, systemImage: "calendar")
                    .font(CalorynTheme.caption)
            }
            .accessibilityElement(children: .combine)
        } footer: {
            Text("Review every portion before adding. All items use the destination shown above.")
        }
    }

    private func reviewRow(item: Binding<MultiAddDraftItem>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.wrappedValue.snapshot.foodName)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Spacer(minLength: 8)

                Button(role: .destructive) {
                    remove(item.wrappedValue.id)
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(recoveryState != nil)
                .accessibilityLabel("Remove \(item.wrappedValue.snapshot.foodName)")
            }

            if let mealName = item.wrappedValue.originMealName,
               isFirstComponentFromMeal(item.wrappedValue) {
                Label("From Meal: \(mealName)", systemImage: "fork.knife")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityIdentifier(
                        "multiAdd.originMeal.\(item.wrappedValue.id.uuidString)"
                    )
            }

            Stepper(
                value: portionBinding(for: item),
                in: 1...100_000,
                step: 1
            ) {
                Text("Portion: \(formattedPortion(item.wrappedValue.snapshot.portionGrams))")
                    .font(CalorynTheme.bodyText)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .disabled(recoveryState != nil)
            .accessibilityLabel("Portion for \(item.wrappedValue.snapshot.foodName)")
            .accessibilityValue(formattedPortion(item.wrappedValue.snapshot.portionGrams))
            .accessibilityHint("Adjusts this item in 1 gram steps")
            .accessibilityIdentifier("multiAdd.portion.\(item.wrappedValue.id.uuidString)")
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("multiAdd.item.\(item.wrappedValue.id.uuidString)")
    }

    private func recoverySection(_ state: MultiAddPartialBatch) -> some View {
        Section {
            Label {
                Text("\(state.persistedCount) of \(state.expectedCount) items already exist for this add operation.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(CalorynTheme.terracotta)
            }
            .accessibilityIdentifier("multiAdd.partialState")

            Text("Choose whether to replace the partial add or keep it and add only the missing items.")
                .font(.footnote)
                .foregroundStyle(CalorynTheme.textSecondary)

            Button("Remove Partial Add and Retry", role: .destructive) {
                recover(using: .removeAndRetry)
            }
            .disabled(isCommitting)
            .accessibilityIdentifier("multiAdd.recovery.replace")

            Button("Keep Added Items and Continue") {
                recover(using: .keepAddedAndContinue)
            }
            .disabled(isCommitting)
            .accessibilityIdentifier("multiAdd.recovery.continue")
        } header: {
            Text("Recovery Needed")
        }
    }

    private var commitTitle: String {
        let noun = items.count == 1 ? "Item" : "Items"
        return "Add \(items.count) \(noun)"
    }

    private var destinationSummary: String {
        "Each selected item will be added to \(destinationDescription)."
    }

    private var destinationDescription: String {
        let snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )
        return "\(destinationMeal.displayName(snackIndex: snackIndex)) on \(destinationDate.shortFormatted)"
    }

    private func portionBinding(
        for item: Binding<MultiAddDraftItem>
    ) -> Binding<Double> {
        Binding(
            get: { item.wrappedValue.snapshot.portionGrams },
            set: { portion in
                item.wrappedValue.snapshot = item.wrappedValue.snapshot
                    .scaled(toPortionGrams: portion)
            }
        )
    }

    private func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    private func isFirstComponentFromMeal(_ item: MultiAddDraftItem) -> Bool {
        guard let mealID = item.originMealID else { return false }
        return items.first { $0.originMealID == mealID }?.id == item.id
    }

    private func formattedPortion(_ portion: Double) -> String {
        if portion.rounded() == portion {
            return "\(Int(portion)) grams"
        }
        return "\(portion.formatted(.number.precision(.fractionLength(0...1)))) grams"
    }

    private func commit() {
        performCommit(recoveryAction: nil)
    }

    private func recover(using action: MultiAddCommands.RecoveryAction) {
        performCommit(recoveryAction: action)
    }

    private func performCommit(
        recoveryAction: MultiAddCommands.RecoveryAction?
    ) {
        guard !isCommitting else { return }
        isCommitting = true
        errorMessage = nil

        Task { @MainActor in
            // Give SwiftUI a render turn after disabling the controls so the
            // progress state is visible before the synchronous transaction.
            await Task.yield()
            defer { isCommitting = false }

            do {
                let plan = try MultiAddCommands.plan(
                    items: items,
                    destinationDate: destinationDate,
                    destinationMeal: destinationMeal,
                    destinationSnackIndex: destinationSnackIndex,
                    operationID: operationID
                )
                let outcome = try MultiAddCommands.commit(
                    plan: plan,
                    modelContainer: modelContext.container,
                    recoveryAction: recoveryAction
                )
                switch outcome {
                case .completed:
                    recoveryState = nil
                    onLogged()
                case .needsRecovery(let state):
                    recoveryState = state
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
