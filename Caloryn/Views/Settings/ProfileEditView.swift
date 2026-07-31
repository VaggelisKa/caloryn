import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Bindable var profile: UserProfile
    @Environment(\.dismiss) private var dismiss

    /// The editable state; the profile is only written on Save. See
    /// `ProfileEditDraft`.
    @State private var draft: ProfileEditDraft

    init(profile: UserProfile) {
        self.profile = profile
        _draft = State(initialValue: ProfileEditDraft(profile: profile))
    }

    private var isActivityLevelLocked: Bool {
        ProfileEditActivityLevelPolicy.isLocked(for: profile)
    }

    var body: some View {
        Form {
            Section("Personal Info") {
                Stepper("Age: \(draft.age)", value: $draft.age, in: 16...100)

                Picker("Sex", selection: $draft.sex) {
                    ForEach(Sex.allCases) { s in
                        Text(s.displayName).tag(s)
                    }
                }

                VStack(alignment: .leading) {
                    Text("Height: \(draft.heightCm.truncatedSafely) cm")
                    Slider(value: $draft.heightCm, in: 120...220, step: 1)
                }

                VStack(alignment: .leading) {
                    Text("Weight: \(String(format: "%.1f", draft.weightKg)) kg")
                    Slider(value: $draft.weightKg, in: 40...200, step: 0.5)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                Picker("Activity", selection: $draft.activityLevel) {
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
                    draft.apply(to: profile)
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
