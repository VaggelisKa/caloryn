import SwiftData
import SwiftUI

struct MealReuseSelectionView: View {
    private struct CopyPresentation: Identifiable {
        let id = UUID()
        let snapshots: [FoodLogEntrySnapshot]
        let sourceName: String
        let defaultMeal: MealType
        let defaultSnackIndex: Int
    }

    @Environment(\.dismiss) private var dismiss

    let entries: [FoodLogEntry]
    let destinationDate: Date

    @State private var selectedIDs: Set<UUID>
    @State private var showingTemplateCreation = false
    @State private var copyPresentation: CopyPresentation?

    @MainActor
    init(
        entries: [FoodLogEntry],
        initiallySelectedIDs: Set<UUID>,
        destinationDate: Date
    ) {
        self.entries = entries.sorted(by: Self.entrySort)
        self.destinationDate = destinationDate
        _selectedIDs = State(initialValue: initiallySelectedIDs)
    }

    private var selectedEntries: [FoodLogEntry] {
        entries.filter { selectedIDs.contains($0.id) }
    }

    private var suggestedMeal: MealType {
        MealTemplateCommands.suggestedMeal(for: selectedEntries)
    }

    private var suggestedSnackIndex: Int {
        MealTemplateCommands.suggestedSnackIndex(
            for: selectedEntries,
            meal: suggestedMeal
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(entries) { entry in
                        selectionRow(entry)
                    }
                } header: {
                    Text("Logged Items")
                } footer: {
                    Text("Choose a whole meal or only the items you want to reuse.")
                }

                Section {
                    Button {
                        showingTemplateCreation = true
                    } label: {
                        Label("Save as Reusable Meal", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedEntries.isEmpty)
                    .accessibilityIdentifier("mealReuse.saveTemplate")

                    Button {
                        Task { @MainActor in
                            copyPresentation = CopyPresentation(
                                snapshots: selectedEntries.map(FoodLogEntrySnapshot.init(entry:)),
                                sourceName: selectedEntries.count == entries.count
                                    ? "Selected meal"
                                    : "\(selectedEntries.count) selected items",
                                defaultMeal: suggestedMeal,
                                defaultSnackIndex: suggestedSnackIndex
                            )
                        }
                    } label: {
                        Label("Copy Selected Entries", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(selectedEntries.isEmpty)
                    .accessibilityIdentifier("mealReuse.copySelected")
                } header: {
                    Text("Reuse")
                }
            }
            .navigationTitle("Select Entries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(selectedIDs.count == entries.count ? "Clear" : "Select All") {
                        if selectedIDs.count == entries.count {
                            selectedIDs.removeAll()
                        } else {
                            selectedIDs = Set(entries.map(\.id))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingTemplateCreation) {
                MealTemplateCreationView(
                    entries: selectedEntries,
                    defaultMeal: suggestedMeal,
                    defaultSnackIndex: suggestedSnackIndex
                ) {
                    showingTemplateCreation = false
                    dismiss()
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $copyPresentation) { presentation in
                NavigationStack {
                    MealLogConfirmationView(
                        snapshots: presentation.snapshots,
                        sourceName: presentation.sourceName,
                        initialDate: destinationDate,
                        initialMeal: presentation.defaultMeal,
                        initialSnackIndex: presentation.defaultSnackIndex
                    ) {
                        copyPresentation = nil
                        dismiss()
                    }
                }
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func selectionRow(_ entry: FoodLogEntry) -> some View {
        let isSelected = selectedIDs.contains(entry.id)

        return Button {
            if isSelected {
                selectedIDs.remove(entry.id)
            } else {
                selectedIDs.insert(entry.id)
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CalorynTheme.sage : CalorynTheme.textSecondary)
                    .font(CalorynTheme.inlineIcon)

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.foodName)
                        .font(CalorynTheme.itemTitle)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Text("\(entry.mealType.displayName) · \(Int(entry.portionGrams.rounded()))g")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }

                Spacer(minLength: 8)

                Text(entry.calories.kcalFormatted)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.textPrimary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.foodName), \(Int(entry.portionGrams.rounded())) grams, \(entry.mealType.displayName)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to \(isSelected ? "remove" : "include") this item")
        .accessibilityIdentifier("mealReuse.entry.\(entry.id.uuidString)")
    }

    private static func entrySort(_ lhs: FoodLogEntry, _ rhs: FoodLogEntry) -> Bool {
        if lhs.mealType.sortOrder != rhs.mealType.sortOrder {
            return lhs.mealType.sortOrder < rhs.mealType.sortOrder
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct MealTemplateCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entries: [FoodLogEntry]
    let onSaved: () -> Void

    @State private var name = ""
    @State private var defaultMeal: MealType
    @State private var defaultSnackIndex: Int
    @State private var operationID = UUID()
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var nameIsFocused: Bool

    init(
        entries: [FoodLogEntry],
        defaultMeal: MealType,
        defaultSnackIndex: Int,
        initialName: String = "",
        onSaved: @escaping () -> Void
    ) {
        self.entries = entries
        self.onSaved = onSaved
        _name = State(initialValue: initialName)
        _defaultMeal = State(initialValue: defaultMeal)
        _defaultSnackIndex = State(initialValue: defaultSnackIndex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Reusable Meal") {
                    TextField("Meal name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameIsFocused)
                        .accessibilityIdentifier("mealTemplate.name")

                    Picker("Default meal", selection: $defaultMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }

                    if defaultMeal == .snack {
                        Stepper("Default snack slot: \(defaultSnackIndex)", value: $defaultSnackIndex, in: 1...20)
                            .accessibilityIdentifier("mealTemplate.defaultSnackSlot")
                    }
                }

                Section("Items") {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.foodName)
                            Spacer()
                            Text("\(Int(entry.portionGrams.rounded()))g")
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Save Reusable Meal", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(CalorynTheme.sage)
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier("mealTemplate.save")
                }
            }
            .navigationTitle("Save Reusable Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Couldn’t Save Meal", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
            .task {
                nameIsFocused = true
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try MealTemplateCommands.createTemplate(
                name: name,
                entries: entries,
                defaultMeal: defaultMeal,
                defaultSnackIndex: defaultSnackIndex,
                modelContext: modelContext,
                operationID: operationID
            )
            onSaved()
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

struct MealLogConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.name) private var availableFoods: [FoodItem]

    let snapshots: [FoodLogEntrySnapshot]
    let sourceName: String
    let onLogged: () -> Void

    @State private var destinationDate: Date
    @State private var destinationMeal: MealType
    @State private var destinationSnackIndex: Int
    @State private var operationID = UUID()
    @State private var isLogging = false
    @State private var errorMessage: String?

    init(
        snapshots: [FoodLogEntrySnapshot],
        sourceName: String,
        initialDate: Date,
        initialMeal: MealType,
        initialSnackIndex: Int = 0,
        onLogged: @escaping () -> Void
    ) {
        self.snapshots = snapshots
        self.sourceName = sourceName
        self.onLogged = onLogged
        _destinationDate = State(initialValue: initialDate.startOfDay)
        _destinationMeal = State(initialValue: initialMeal)
        _destinationSnackIndex = State(
            initialValue: DailyFoodLogCommands.normalizedSnackIndex(
                for: initialMeal,
                requestedSnackIndex: initialSnackIndex
            )
        )
    }

    private var missingSourceCount: Int {
        MealTemplateCommands.missingSourceCount(
            in: snapshots,
            availableFoods: availableFoods
        )
    }

    var body: some View {
        Form {
            Section {
                DatePicker(
                    "Date",
                    selection: $destinationDate,
                    in: ...Date.now.tomorrow,
                    displayedComponents: .date
                )
                .accessibilityIdentifier("mealReuse.destinationDate")

                Picker("Meal", selection: $destinationMeal) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.displayName).tag(meal)
                    }
                }
                .accessibilityIdentifier("mealReuse.destinationMeal")

                if destinationMeal == .snack {
                    Stepper("Snack slot: \(destinationSnackIndex)", value: $destinationSnackIndex, in: 1...20)
                        .accessibilityIdentifier("mealReuse.destinationSnackSlot")
                }

                Text("Every selected item will be added to \(destinationMeal.displayName(snackIndex: normalizedDestinationSnackIndex)) on \(destinationDate.shortFormatted).")
                    .font(.footnote)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .accessibilityIdentifier("mealReuse.destinationSummary")
            } header: {
                Text("Destination")
            }

            if missingSourceCount > 0 {
                Section {
                    Label {
                        Text(missingSourceMessage)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(CalorynTheme.terracotta)
                    }
                    .accessibilityIdentifier("mealReuse.missingSourceWarning")

                    Text("Caloryn will use the names, portions, nutrition, and quality values saved with this meal. The new log entries stay editable.")
                        .font(.footnote)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            Section("Items") {
                ForEach(Array(snapshots.enumerated()), id: \.offset) { _, snapshot in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(snapshot.foodName)
                                .font(CalorynTheme.itemTitle)
                            Text("\(Int(snapshot.portionGrams.rounded()))g")
                                .font(CalorynTheme.caption)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        Spacer(minLength: 8)

                        Text(snapshot.nutrition.calories.kcalFormatted)
                            .font(CalorynTheme.numericBody)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Button {
                    log()
                } label: {
                    if isLogging {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(logButtonTitle, systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(CalorynTheme.sage)
                .disabled(isLogging || snapshots.isEmpty)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("mealReuse.confirm")
            }
        }
        .navigationTitle(sourceName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Couldn’t Add Meal", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var missingSourceMessage: String {
        let noun = missingSourceCount == 1 ? "item is" : "items are"
        return "\(missingSourceCount) source \(noun) no longer available"
    }

    private var logButtonTitle: String {
        let noun = snapshots.count == 1 ? "Item" : "Items"
        return "Add \(snapshots.count) \(noun)"
    }

    private func log() {
        guard !isLogging else { return }
        isLogging = true
        defer { isLogging = false }

        do {
            let plan = try MealTemplateCommands.plan(
                sourceName: sourceName,
                snapshots: snapshots,
                destinationDate: destinationDate,
                destinationMeal: destinationMeal,
                destinationSnackIndex: destinationSnackIndex,
                operationID: operationID
            )
            try MealTemplateCommands.log(
                plan: plan,
                availableFoods: availableFoods,
                modelContext: modelContext
            )
            onLogged()
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

    private var normalizedDestinationSnackIndex: Int {
        DailyFoodLogCommands.normalizedSnackIndex(
            for: destinationMeal,
            requestedSnackIndex: destinationSnackIndex
        )
    }
}

struct MealTemplateLibraryRow: View {
    let template: MealTemplate

    private var snapshots: [FoodLogEntrySnapshot] {
        (try? MealTemplateCommands.snapshots(for: template)) ?? []
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(CalorynTheme.inlineIcon)
                .foregroundStyle(CalorynTheme.sage)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(template.name)
                    .font(CalorynTheme.itemTitle)
                    .foregroundStyle(CalorynTheme.textPrimary)

                Text(detailText)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(CalorynTheme.numericMicroCaption)
                .foregroundStyle(CalorynTheme.textSecondary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(detailText)")
        .accessibilityHint("Double tap to choose a destination")
    }

    private var detailText: String {
        guard !snapshots.isEmpty else { return "Unavailable template" }
        let itemLabel = snapshots.count == 1 ? "1 item" : "\(snapshots.count) items"
        let calories = snapshots.reduce(0) { $0 + $1.nutrition.calories }
        return "\(itemLabel) · \(calories.kcalFormatted) · defaults to \(template.defaultMeal.displayName(snackIndex: template.defaultSnackIndex))"
    }
}
