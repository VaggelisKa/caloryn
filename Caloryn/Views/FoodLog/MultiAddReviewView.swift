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
            List {
                if let recoveryState {
                    recoverySection(recoveryState)
                }

                itemsSection
            }
            .calorynPlainListStyle()
            .foodLogBottomAction {
                commitButton
            }
            .calorynSheetCanvas()
            .navigationTitle("Review items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    FoodLogSheetTitle(title: "Review items")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(CalorynTheme.toolbarIcon)
                            .foregroundStyle(
                                isCommitting ? CalorynTheme.textSecondary : CalorynTheme.textPrimary
                            )
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

    private var commitButton: some View {
        Button {
            commit()
        } label: {
            if isCommitting {
                ProgressView()
                    .tint(CalorynTheme.textSecondary)
            } else {
                Text(commitTitle)
            }
        }
        .calorynPrimaryButton()
        .disabled(isCommitting || items.isEmpty || recoveryState != nil)
        .accessibilityIdentifier("multiAdd.commit")
    }

    private static let rowInsets = EdgeInsets(
        top: 10,
        leading: CalorynTheme.pagePadding,
        bottom: 10,
        trailing: CalorynTheme.pagePadding
    )

    private func sectionTitleRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .textCase(nil)
            .listRowInsets(Self.rowInsets)
            .listRowSeparator(.hidden, edges: .top)
            .calorynHairlineSeparators()
    }

    @ViewBuilder
    private var itemsSection: some View {
        sectionTitleRow {
            VStack(alignment: .leading, spacing: 3) {
                Text("Selected items")
                    .font(CalorynTheme.sectionHeaderTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)
                Text(destinationDescription)
                    .font(CalorynTypeface.text(.footnote))
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityIdentifier("multiAdd.destinationSummary")
            }
            .padding(.top, 4)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }

        Section {
            ForEach($items) { $item in
                NavigationLink {
                    MultiAddPortionEditorView(
                        item: $item,
                        destinationDescription: destinationDescription,
                        destinationMeal: destinationMeal
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
                        .tint(CalorynTheme.swipeActionTint)
                    }
                }
                .accessibilityIdentifier("multiAdd.item.\(item.id.uuidString)")
                .listRowInsets(Self.rowInsets)
                .calorynHairlineSeparators()
            }
        }
    }

    private func reviewRow(_ item: MultiAddDraftItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.snapshot.foodName)
                    .font(FoodRowTypography.name)
                    .foregroundStyle(CalorynTheme.textPrimary)

                if let mealName = item.originMealName,
                   isFirstComponentFromMeal(item) {
                    Text("Part of \(mealName)")
                        .font(FoodRowTypography.detail)
                        .foregroundStyle(CalorynTheme.textSecondary)
                        .accessibilityIdentifier(
                            "multiAdd.originMeal.\(item.id.uuidString)"
                        )
                }

                portionText(for: item)
                    .font(FoodRowTypography.detail)
                    .foregroundStyle(CalorynTheme.textSecondary)
            }

            Spacer(minLength: 8)

            FoodRowFigure(
                figure: "\(item.snapshot.nutrition.calories.rounded().truncatedSafely)",
                caption: "kcal"
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the portion editor")
    }

    private func portionText(for item: MultiAddDraftItem) -> some View {
        Text(formattedPortion(item.snapshot.portionGrams))
            .accessibilityIdentifier("multiAdd.portion.\(item.id.uuidString)")
    }

    @ViewBuilder
    private func recoverySection(_ state: MultiAddPartialBatch) -> some View {
        sectionTitleRow {
            Text("Recovery needed")
                .font(CalorynTheme.sectionHeaderTitle)
                .foregroundStyle(CalorynTheme.textPrimary)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
        }

        Section {
            Label {
                Text("\(state.persistedCount) of \(state.expectedCount) items already exist for this add operation.")
                    .foregroundStyle(CalorynTheme.textPrimary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .accessibilityIdentifier("multiAdd.partialState")

            Text("Choose whether to replace the partial add or keep it and add only the missing items.")
                .font(CalorynTypeface.text(.footnote))
                .foregroundStyle(CalorynTheme.textSecondary)

            Button(role: .destructive) {
                recover(using: .removeAndRetry)
            } label: {
                Text("Remove partial add and retry")
                    .foregroundStyle(isCommitting ? CalorynTheme.textSecondary : CalorynTheme.textPrimary)
            }
            .disabled(isCommitting)
            .accessibilityIdentifier("multiAdd.recovery.replace")

            Button {
                recover(using: .keepAddedAndContinue)
            } label: {
                Text("Keep added items and continue")
                    .foregroundStyle(isCommitting ? CalorynTheme.textSecondary : CalorynTheme.textPrimary)
            }
            .disabled(isCommitting)
            .accessibilityIdentifier("multiAdd.recovery.continue")
        }
        .listRowInsets(Self.rowInsets)
        .calorynHairlineSeparators()
    }

    private var commitTitle: String {
        let noun = items.count == 1 ? "item" : "items"
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
        return "\(destinationDate.shortFormatted), \(mealName)"
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
            return "\(portion.truncatedSafely) g"
        }
        return "\(portion.formatted(.number.precision(.fractionLength(0...1)))) g"
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
