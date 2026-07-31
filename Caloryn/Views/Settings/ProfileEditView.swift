import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    private var isActivityLevelLocked: Bool {
        ProfileEditActivityLevelPolicy.isLocked(for: profile)
    }

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
                    Text("Height: \(profile.heightCm.truncatedSafely) cm")
                    Slider(value: $profile.heightCm, in: 120...220, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Weight: \(String(format: "%.1f", profile.weightKg)) kg")
                    Slider(value: $profile.weightKg, in: 40...200, step: 0.5)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                Picker("Activity", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .disabled(isActivityLevelLocked)
            } header: {
                Text("Activity Level")
            } footer: {
                if isActivityLevelLocked {
                    Text(ProfileEditActivityLevelPolicy.lockedExplanation)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    let ratios = ProfileEditMacroRatios(
                        dailyCalorieTarget: profile.dailyCalorieTarget,
                        proteinTargetG: profile.proteinTargetG,
                        carbTargetG: profile.carbTargetG,
                        fatTargetG: profile.fatTargetG
                    )
                    profile.recalculate(
                        proteinRatio: ratios.protein,
                        carbRatio: ratios.carbs,
                        fatRatio: ratios.fat
                    )
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(CalorynTheme.sage)
                }
            }
        }
    }
}
