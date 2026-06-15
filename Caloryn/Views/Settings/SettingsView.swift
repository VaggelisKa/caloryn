import SwiftUI
import SwiftData

private let nutrientGoalExpansionAnimation = Animation.smooth(duration: 0.24)
private let nutrientGoalAnimationDuration: TimeInterval = 0.24
private let nutrientGoalPickerHeight: CGFloat = 32

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.updatedAt, order: .reverse) private var profiles: [UserProfile]
    @Query private var allEntries: [FoodLogEntry]
    @AppStorage("themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("showNutriscore") private var showNutriscore = true
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage(AppleHealthAdjustmentSettings.adjustmentEnabledKey) private var appleHealthAdjustmentEnabled = false

    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var showRestartAlert = false
    @State private var isRequestingHealthAuthorization = false
    @State private var healthStatusMessage: String?

    private var profile: UserProfile? { profiles.first }
    private var isHealthAvailable: Bool { AppleHealthAdjustmentSettings.isHealthAvailable }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection

                if let profile {
                    goalSection(profile)
                    profileSection(profile)
                }

                appleHealthSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showExportSheet) {
                if let url = exportURL {
                    ShareSheet(url: url)
                }
            }
            .alert("Restart Required", isPresented: $showRestartAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("iCloud sync changes will take effect the next time you open the app.")
            }
        }
    }

    private var appleHealthSection: some View {
        Section {
            Toggle(isOn: appleHealthToggleBinding) {
                Label("Apple Health Adjustment", systemImage: "heart.text.square")
            }
            .tint(CalorynTheme.sage)
            .disabled(!isHealthAvailable || isRequestingHealthAuthorization)

            if isRequestingHealthAuthorization {
                HStack(spacing: 8) {
                    ProgressView()

                    Text("Requesting Apple Health access")
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            if appleHealthAdjustmentEnabled {
                LabeledContent("Credit", value: AppleHealthAdjustmentSettings.activeEnergyCreditPolicyText)
            }

            if let healthStatusMessage {
                Text(healthStatusMessage)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.terracotta)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text(appleHealthFooterText)
        }
    }

    private var appleHealthToggleBinding: Binding<Bool> {
        Binding(
            get: {
                appleHealthAdjustmentEnabled
            },
            set: { isOn in
                if isOn {
                    Task {
                        await enableAppleHealthAdjustment()
                    }
                } else {
                    disableAppleHealthAdjustment()
                }
            }
        )
    }

    private var appleHealthFooterText: String {
        AppleHealthAdjustmentSettings.footerText(isEnabled: appleHealthAdjustmentEnabled)
    }

    @MainActor
    private func enableAppleHealthAdjustment() async {
        guard !isRequestingHealthAuthorization else { return }

        isRequestingHealthAuthorization = true
        healthStatusMessage = nil
        defer {
            isRequestingHealthAuthorization = false
        }

        let update = await AppleHealthAdjustmentSettings.enable()
        appleHealthAdjustmentEnabled = update.isEnabled
        healthStatusMessage = update.message
    }

    private func disableAppleHealthAdjustment() {
        let update = AppleHealthAdjustmentSettings.disable()
        appleHealthAdjustmentEnabled = update.isEnabled
        healthStatusMessage = update.message
    }

    private var appearanceSection: some View {
        Section {
            Picker("Appearance", selection: $themePreferenceRaw) {
                ForEach(ThemePreference.allCases, id: \.self) { preference in
                    Label(preference.displayName, systemImage: preference.icon)
                        .tag(preference.rawValue)
                }
            }
            .tint(CalorynTheme.sage)

            Toggle(isOn: $showNutriscore) {
                Label("Show Nutri-Score", systemImage: "leaf")
            }
            .tint(CalorynTheme.sage)
        } header: {
            Text("Appearance")
        } footer: {
            Text("Display nutrition quality scores from Open Food Facts on foods and in your daily summary.")
        }
    }

    private func goalSection(_ profile: UserProfile) -> some View {
        Section {
            HStack {
                Label("Calories", systemImage: "flame.fill")
                    .foregroundStyle(CalorynTheme.textPrimary)
                Spacer()
                Text(profile.dailyCalorieTarget.kcalFormatted)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(CalorynTheme.sage)
            }

            if !profile.manualOverride {
                HStack {
                    Label("Adjustment", systemImage: "plusminus")
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Text(adjustmentLabel(for: profile.calorieDeficit))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            ForEach(goalSummaryNutrients(for: profile)) { nutrient in
                HStack {
                    Label(nutrient.displayName, systemImage: nutrient.systemImage)
                        .foregroundStyle(CalorynTheme.textPrimary)

                    Spacer()

                    Text(goalSummaryText(for: nutrient, in: profile))
                        .font(CalorynTheme.numericBody)
                        .foregroundStyle(nutrient.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }

            NavigationLink("Edit Goal") {
                GoalEditView(profile: profile)
            }
        } header: {
            Text("Goal")
        }
    }

    private func goalSummaryNutrients(for profile: UserProfile) -> [TrackedNutrient] {
        TrackedNutrient.allCases.filter { profile.target(for: $0) != nil }
    }

    private func goalSummaryText(for nutrient: TrackedNutrient, in profile: UserProfile) -> String {
        guard let target = profile.target(for: nutrient) else { return "Not set" }
        let formattedTarget = nutrient.unit.formatted(target)

        switch profile.goalKind(for: nutrient) {
        case .minimum:
            return "At least \(formattedTarget)"
        case .target:
            return formattedTarget
        case .maximum:
            return "At most \(formattedTarget)"
        }
    }

    private func adjustmentLabel(for deficit: Double) -> String {
        if deficit > 0 {
            return "-\(Int(deficit)) kcal"
        } else if deficit < 0 {
            return "+\(Int(abs(deficit))) kcal"
        }
        return "Maintenance"
    }

    private func profileSection(_ profile: UserProfile) -> some View {
        Section {
            LabeledContent("Age", value: "\(profile.age)")
            LabeledContent("Sex", value: profile.sex.displayName)
            LabeledContent("Height", value: "\(Int(profile.heightCm)) cm")
            LabeledContent("Weight", value: String(format: "%.1f kg", profile.weightKg))
            LabeledContent("Activity", value: profile.activityLevel.displayName)

            NavigationLink("Edit Profile") {
                ProfileEditView(profile: profile)
            }
        } header: {
            Text("Profile")
        }
    }

    private var dataSection: some View {
        Section {
            Toggle(isOn: $iCloudSyncEnabled) {
                Label("iCloud Sync", systemImage: "icloud")
            }
            .tint(CalorynTheme.sage)
            .onChange(of: iCloudSyncEnabled) {
                showRestartAlert = true
            }

            Button {
                exportURL = CSVExporter.exportURL(from: allEntries)
                if exportURL != nil {
                    showExportSheet = true
                }
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(allEntries.isEmpty)
        } header: {
            Text("Data")
        } footer: {
            if iCloudSyncEnabled {
                Text("Your food log syncs automatically across your devices via iCloud.")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)

            Link(destination: URL(string: "https://caloryn.app/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundStyle(CalorynTheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(CalorynTheme.textSecondary)
                }
            }

            HStack {
                Text("Food data by")
                Spacer()
                Link("Open Food Facts", destination: URL(string: "https://openfoodfacts.org")!)
                    .font(CalorynTheme.caption)
            }
        } header: {
            Text("About")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, FoodItem.self, FoodLogEntry.self, RecipeIngredient.self, configurations: config)
    let context = ModelContext(container)
    let profile = UserProfile(age: 30, sex: .male, heightCm: 175, weightKg: 70, activityLevel: .moderatelyActive, dailyCalorieTarget: 2000)
    context.insert(profile)
    try? context.save()
    return SettingsView()
        .modelContainer(container)
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Goal Edit

private enum GoalEditFocus: Hashable {
    case manualTarget
    case nutrient(TrackedNutrient)
}

struct GoalEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    @FocusState private var focusedField: GoalEditFocus?
    @State private var targetText: String = ""
    @State private var manualOverride = false
    @State private var calorieDeficit: Double = 500
    @State private var proteinRatio: Double = 0.30
    @State private var carbRatio: Double = 0.40
    @State private var fatRatio: Double = 0.30
    @State private var nutrientTargetTexts: [TrackedNutrient: String] = [:]
    @State private var nutrientGoalKinds: [TrackedNutrient: NutrientGoalKind] = [:]

    private var macroTotal: Double { proteinRatio + carbRatio + fatRatio }
    private var isMacroValid: Bool { abs(macroTotal - 1.0) <= 0.01 }
    private var manualTarget: Int? { Int(targetText) }
    private var isManualTargetValid: Bool { !manualOverride || (manualTarget ?? 0) >= 1000 }
    private var areNutrientGoalsValid: Bool {
        TrackedNutrient.editableGoalNutrients.allSatisfy { nutrient in
            let text = nutrientTargetTexts[nutrient, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty || storedTarget(from: text, for: nutrient) != nil
        }
    }

    private var calculatedTarget: Int {
        NutritionCalculator.defaultTarget(tdee: profile.tdee, deficit: calorieDeficit)
    }

    private var effectiveCalorieTarget: Int {
        manualOverride ? (manualTarget ?? calculatedTarget) : calculatedTarget
    }

    private var previewProteinTarget: Double {
        NutritionCalculator.macroGrams(calories: Double(effectiveCalorieTarget), ratio: proteinRatio, caloriesPerGram: 4)
    }

    private var previewCarbTarget: Double {
        NutritionCalculator.macroGrams(calories: Double(effectiveCalorieTarget), ratio: carbRatio, caloriesPerGram: 4)
    }

    private var previewFatTarget: Double {
        NutritionCalculator.macroGrams(calories: Double(effectiveCalorieTarget), ratio: fatRatio, caloriesPerGram: 9)
    }

    private var deficitLabel: String {
        if calorieDeficit > 0 {
            return "-\(Int(calorieDeficit)) kcal/day (lose weight)"
        } else if calorieDeficit < 0 {
            return "+\(Int(abs(calorieDeficit))) kcal/day (gain weight)"
        }
        return "Maintenance (no change)"
    }

    var body: some View {
        Form {
            Section("Daily Calorie Target") {
                Toggle("Manual Override", isOn: $manualOverride)
                    .tint(CalorynTheme.sage)
                    .onChange(of: manualOverride) { _, isManual in
                        if isManual {
                            targetText = "\(calculatedTarget)"
                        }
                    }

                if manualOverride {
                    HStack {
                        TextField("Target", text: $targetText)
                            .keyboardType(.numberPad)
                            .font(CalorynTheme.numericBody)
                            .focused($focusedField, equals: .manualTarget)
                            .calorynInputField(isFocused: focusedField == .manualTarget)
                        Text("kcal")
                            .foregroundStyle(CalorynTheme.textSecondary)
                    }
                } else {
                    LabeledContent("Calculated TDEE", value: "\(Int(profile.tdee)) kcal")
                    LabeledContent("Target", value: "\(calculatedTarget) kcal")
                }
            }

            if !manualOverride {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Surplus")
                                .font(.caption2)
                                .foregroundStyle(CalorynTheme.textSecondary)
                            Slider(value: $calorieDeficit, in: -500...1000, step: 50)
                                .tint(CalorynTheme.sage)
                            Text("Deficit")
                                .font(.caption2)
                                .foregroundStyle(CalorynTheme.textSecondary)
                        }

                        Text(deficitLabel)
                            .font(CalorynTheme.caption)
                            .foregroundStyle(CalorynTheme.terracotta)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } header: {
                    Text("Calorie Adjustment")
                } footer: {
                    Text("Positive values create a deficit for weight loss, negative values create a surplus for weight gain.")
                }
            }

            Section("Macro Goals") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protein: \(Int(proteinRatio * 100))% · \(previewProteinTarget.macroFormatted)")
                    Slider(value: $proteinRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.proteinColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Carbs: \(Int(carbRatio * 100))% · \(previewCarbTarget.macroFormatted)")
                    Slider(value: $carbRatio, in: 0.10...0.60, step: 0.05)
                        .tint(CalorynTheme.carbColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fat: \(Int(fatRatio * 100))% · \(previewFatTarget.macroFormatted)")
                    Slider(value: $fatRatio, in: 0.10...0.50, step: 0.05)
                        .tint(CalorynTheme.fatColor)
                }

                let total = proteinRatio + carbRatio + fatRatio
                if abs(total - 1.0) > 0.01 {
                    Text("Ratios should total 100% (currently \(Int(total * 100))%)")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            }

            Section {
                ForEach(TrackedNutrient.editableGoalNutrients) { nutrient in
                    NutrientGoalEditRow(
                        nutrient: nutrient,
                        targetText: targetTextBinding(for: nutrient),
                        goalKind: goalKindBinding(for: nutrient),
                        isInvalid: isInvalidTarget(for: nutrient),
                        focusedField: $focusedField
                    )
                }

                if !areNutrientGoalsValid {
                    Text("Goal values must be positive numbers. Leave a field blank to remove that goal.")
                        .font(CalorynTheme.caption)
                        .foregroundStyle(CalorynTheme.terracotta)
                }
            } header: {
                Text("Additional Nutrient Goals")
            } footer: {
                Text("These goals appear anywhere the nutrient is shown. Sodium and cholesterol are entered in milligrams.")
            }
        }
        .navigationTitle("Edit Goal")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    profile.manualOverride = manualOverride
                    profile.calorieDeficit = calorieDeficit
                    if manualOverride, let manualTarget {
                        profile.dailyCalorieTarget = manualTarget
                    }
                    profile.recalculate(proteinRatio: proteinRatio, carbRatio: carbRatio, fatRatio: fatRatio)
                    saveAdditionalNutrientGoals()
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(!isMacroValid || !isManualTargetValid || !areNutrientGoalsValid)
            }
        }
        .onAppear {
            targetText = "\(profile.dailyCalorieTarget)"
            manualOverride = profile.manualOverride
            calorieDeficit = profile.calorieDeficit
            let cal = Double(profile.dailyCalorieTarget)
            if cal > 0 {
                proteinRatio = (profile.proteinTargetG * 4.0) / cal
                carbRatio = (profile.carbTargetG * 4.0) / cal
                fatRatio = (profile.fatTargetG * 9.0) / cal
            }
            loadAdditionalNutrientGoals()
        }
    }

    private func targetTextBinding(for nutrient: TrackedNutrient) -> Binding<String> {
        Binding(
            get: { nutrientTargetTexts[nutrient, default: ""] },
            set: { newValue in
                let currentValue = nutrientTargetTexts[nutrient, default: ""]
                guard currentValue != newValue else { return }
                nutrientTargetTexts[nutrient] = newValue
            }
        )
    }

    private func goalKindBinding(for nutrient: TrackedNutrient) -> Binding<NutrientGoalKind> {
        Binding(
            get: { nutrientGoalKinds[nutrient, default: nutrient.defaultGoalKind] },
            set: { nutrientGoalKinds[nutrient] = $0 }
        )
    }

    private func loadAdditionalNutrientGoals() {
        for nutrient in TrackedNutrient.editableGoalNutrients {
            if let target = profile.target(for: nutrient) {
                nutrientTargetTexts[nutrient] = nutrient.unit.inputFormatted(target)
            } else {
                nutrientTargetTexts[nutrient] = ""
            }
            nutrientGoalKinds[nutrient] = profile.goalKind(for: nutrient)
        }
    }

    private func saveAdditionalNutrientGoals() {
        for nutrient in TrackedNutrient.editableGoalNutrients {
            let text = nutrientTargetTexts[nutrient, default: ""]
            let target = storedTarget(from: text, for: nutrient)
            profile.setGoalKind(nutrientGoalKinds[nutrient, default: nutrient.defaultGoalKind], for: nutrient)
            profile.setTarget(target, for: nutrient)
        }
    }

    private func isInvalidTarget(for nutrient: TrackedNutrient) -> Bool {
        let text = nutrientTargetTexts[nutrient, default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
        return !text.isEmpty && storedTarget(from: text, for: nutrient) == nil
    }

    private func storedTarget(from text: String, for nutrient: TrackedNutrient) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !normalized.isEmpty, let input = Double(normalized), input > 0 else {
            return nil
        }

        return nutrient.unit.storedValue(fromInput: input)
    }
}

private struct NutrientGoalEditRow: View {
    let nutrient: TrackedNutrient
    @Binding var targetText: String
    @Binding var goalKind: NutrientGoalKind
    let isInvalid: Bool
    @FocusState.Binding var focusedField: GoalEditFocus?
    @State private var isGoalTypePickerRendered = false
    @State private var isGoalTypePickerVisible = false

    private var hasValue: Bool {
        !targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isGoalTypePickerVisible ? 8 : 0) {
            HStack(spacing: 10) {
                Label(nutrient.displayName, systemImage: nutrient.systemImage)
                    .foregroundStyle(CalorynTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                TextField("Optional", text: $targetText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .nutrient(nutrient))
                    .multilineTextAlignment(.trailing)
                    .font(CalorynTheme.numericBody)
                    .foregroundStyle(isInvalid ? CalorynTheme.terracotta : CalorynTheme.textPrimary)
                    .calorynInputField(isFocused: focusedField == .nutrient(nutrient))
                    .frame(width: 92)
                    .accessibilityLabel("\(nutrient.displayName) goal in \(nutrient.unit.inputUnitLabel)")

                Text(nutrient.unit.inputUnitLabel)
                    .font(CalorynTheme.caption)
                    .foregroundStyle(CalorynTheme.textSecondary)
                    .frame(width: 24, alignment: .leading)
            }

            if isGoalTypePickerRendered {
                Picker("Goal type", selection: $goalKind) {
                    ForEach(NutrientGoalKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(height: isGoalTypePickerVisible ? nutrientGoalPickerHeight : 0, alignment: .top)
                .opacity(isGoalTypePickerVisible ? 1 : 0)
                .scaleEffect(y: isGoalTypePickerVisible ? 1 : 0.97, anchor: .top)
                .clipped()
                .allowsHitTesting(isGoalTypePickerVisible)
                .accessibilityHidden(!isGoalTypePickerVisible)
                .accessibilityLabel("\(nutrient.displayName) goal type")
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            isGoalTypePickerRendered = hasValue
            isGoalTypePickerVisible = hasValue
        }
        .onChange(of: hasValue) { _, shouldShow in
            updateGoalTypePickerVisibility(shouldShow)
        }
    }

    private func updateGoalTypePickerVisibility(_ shouldShow: Bool) {
        if shouldShow {
            isGoalTypePickerRendered = true
            DispatchQueue.main.async {
                guard hasValue else { return }
                withAnimation(nutrientGoalExpansionAnimation) {
                    isGoalTypePickerVisible = true
                }
            }
        } else {
            withAnimation(nutrientGoalExpansionAnimation) {
                isGoalTypePickerVisible = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + nutrientGoalAnimationDuration) {
                guard !hasValue else { return }
                isGoalTypePickerRendered = false
            }
        }
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Personal Info") {
                Stepper("Age: \(profile.age)", value: $profile.age, in: 16...100)

                Picker("Sex", selection: $profile.sex) {
                    ForEach(Sex.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Height: \(Int(profile.heightCm)) cm")
                    Slider(value: $profile.heightCm, in: 120...220, step: 1)
                        .tint(CalorynTheme.sage)
                }

                VStack(alignment: .leading) {
                    Text("Weight: \(String(format: "%.1f", profile.weightKg)) kg")
                    Slider(value: $profile.weightKg, in: 40...200, step: 0.5)
                        .tint(CalorynTheme.sage)
                }
            }

            Section("Activity Level") {
                Picker("Activity", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let cal = Double(profile.dailyCalorieTarget)
                    let proteinRatio = cal > 0 ? (profile.proteinTargetG * 4.0) / cal : 0.30
                    let carbRatio    = cal > 0 ? (profile.carbTargetG    * 4.0) / cal : 0.40
                    let fatRatio     = cal > 0 ? (profile.fatTargetG     * 9.0) / cal : 0.30
                    profile.recalculate(proteinRatio: proteinRatio, carbRatio: carbRatio, fatRatio: fatRatio)
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
