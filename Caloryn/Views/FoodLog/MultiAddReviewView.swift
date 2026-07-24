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
                if let recoveryState {
                    recoverySection(recoveryState)
                }

                itemsSection
            }
            .safeAreaInset(edge: .bottom) {
                commitBar
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                    }
                    .disabled(isCommitting)
                    .accessibilityLabel("Close")
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

    private var commitBar: some View {
        VStack(spacing: 0) {
            Button {
                commit()
            } label: {
                Group {
                    if isCommitting {
                        ProgressView()
                    } else {
                        Text(commitTitle)
                            .font(CalorynTheme.buttonLabel)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .adaptiveGlassProminentButton()
            .tint(CalorynTheme.sage)
            .disabled(isCommitting || items.isEmpty || recoveryState != nil)
            .padding(.horizontal, CalorynTheme.pagePadding)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .accessibilityIdentifier("multiAdd.commit")
        }
        .background(.regularMaterial)
    }

    private var itemsSection: some View {
        Section {
            ForEach($items) { $item in
                NavigationLink {
                    MultiAddPortionEditorView(
                        item: $item,
                        destinationDescription: destinationDescription
                    )
                } label: {
                    reviewRow(item)
                }
                .disabled(recoveryState != nil)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if recoveryState == nil {
                        Button(role: .destructive) {
                            remove(item.id)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .accessibilityLabel("Remove \(item.snapshot.foodName)")
                    }
                }
                .accessibilityIdentifier("multiAdd.item.\(item.id.uuidString)")
            }
        } header: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selected Items")
                Text(destinationDescription)
                    .font(CalorynTheme.caption)
                    .accessibilityIdentifier("multiAdd.destinationSummary")
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func reviewRow(_ item: MultiAddDraftItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.snapshot.foodName)
                .font(CalorynTheme.itemTitle)
                .foregroundStyle(CalorynTheme.textPrimary)

            if let mealName = item.originMealName,
               isFirstComponentFromMeal(item) {
                Text("From Meal: \(mealName)")
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityIdentifier(
                        "multiAdd.originMeal.\(item.id.uuidString)"
                    )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    portionText(for: item)

                    Text("·")
                        .accessibilityHidden(true)

                    calorieText(for: item)
                }

                VStack(alignment: .leading, spacing: 2) {
                    portionText(for: item)
                    calorieText(for: item)
                }
            }
            .font(CalorynTheme.caption)
            .foregroundStyle(CalorynTheme.textSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the portion editor")
    }

    private func portionText(for item: MultiAddDraftItem) -> some View {
        Text(formattedPortion(item.snapshot.portionGrams))
            .accessibilityIdentifier("multiAdd.portion.\(item.id.uuidString)")
    }

    private func calorieText(for item: MultiAddDraftItem) -> some View {
        Text("\(Int(item.snapshot.nutrition.calories.rounded())) kcal")
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
        return "Log \(items.count) \(noun)"
    }

    private var destinationDescription: String {
        let snackIndex = DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )
        let mealName = destinationMeal
            .displayName(snackIndex: snackIndex)
            .lowercased()
        let calendar = Calendar.current

        if calendar.isDateInToday(destinationDate) {
            return "Today’s \(mealName)"
        }
        if calendar.isDateInYesterday(destinationDate) {
            return "Yesterday’s \(mealName)"
        }
        if calendar.isDateInTomorrow(destinationDate) {
            return "Tomorrow’s \(mealName)"
        }
        return "\(destinationDate.shortFormatted) · \(mealName)"
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
