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
            Section {
                ProfileAgeRow(age: $draft.age)

                ProfileSexRow(selection: $draft.sex)

                ProfileSliderRow(
                    title: "Height",
                    valueText: "\(draft.heightCm.truncatedSafely) cm",
                    value: $draft.heightCm,
                    range: 120...220,
                    step: 1
                )

                ProfileSliderRow(
                    title: "Weight",
                    valueText: draft.weightKg.kilogramsFormatted(),
                    value: $draft.weightKg,
                    range: 40...200,
                    step: 0.5
                )
            } header: {
                SettingsSectionTitle("Personal info")
            }
            .listRowBackground(CalorynTheme.cardBackground)

            Section {
                // A menu, not chips: five long names do not fit a row of chips.
                Picker("Activity", selection: $draft.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.displayName.sentenceCased).tag(level)
                    }
                }
                .foregroundStyle(CalorynTheme.textPrimary)
                .disabled(isActivityLevelLocked)
            } header: {
                SettingsSectionTitle("Activity level")
            } footer: {
                if isActivityLevelLocked {
                    SettingsSectionFooter(ProfileEditActivityLevelPolicy.lockedExplanation)
                }
            }
            .listRowBackground(CalorynTheme.cardBackground)
        }
        .calorynFormStyle()
        .calorynPageCanvas()
        .calorynDrillDownNavigation()
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .calorynConfirmation) {
                Button {
                    draft.apply(to: profile)
                    dismiss()
                } label: {
                    Text("Save")
                        .font(CalorynTheme.toolbarAction)
                        .foregroundStyle(CalorynTheme.textPrimary)
                }
            }
        }
    }
}

/// Age on the Plate stepper: a `surface` pill with round minus and plus buttons. A stock
/// `Stepper` draws its minus/plus pill in a system fill (#EEEEEF on the white group) that
/// no token reaches.
private struct ProfileAgeRow: View {
    @Binding var age: Int

    private static let range = 16...100

    var body: some View {
        HStack(spacing: 12) {
            Text("Age")
                .font(CalorynTheme.bodyText)
                .foregroundStyle(CalorynTheme.textPrimary)
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            CalorynStepperPill(
                accessibilityTitle: "Age",
                value: "\(age)",
                size: .compact,
                canDecrement: age > Self.range.lowerBound,
                canIncrement: age < Self.range.upperBound,
                onDecrement: { age = max(Self.range.lowerBound, age - 1) },
                onIncrement: { age = min(Self.range.upperBound, age + 1) }
            )
        }
    }
}

/// Male / Female as chips: a two-way choice, so the vocabulary's chips rather than a menu.
/// The chips go under the title when both will not fit beside it (from about AX3), as the
/// theme row does, rather than squeezing "Female" to "Fem…".
private struct ProfileSexRow: View {
    @Binding var selection: Sex

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                title

                Spacer(minLength: 8)

                chips
            }

            VStack(alignment: .leading, spacing: 10) {
                title
                chips
            }
        }
    }

    private var title: some View {
        Text("Sex")
            .font(CalorynTheme.bodyText)
            .foregroundStyle(CalorynTheme.textPrimary)
            .accessibilityHidden(true)
    }

    private var chips: some View {
        HStack(spacing: 6) {
            ForEach(Sex.allCases) { sex in
                Button {
                    selection = sex
                } label: {
                    Text(sex.displayName)
                        .calorynChip(isSelected: selection == sex)
                        .fixedSize()
                }
                .buttonStyle(.borderless)
                .accessibilityAddTraits(selection == sex ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sex")
    }
}

/// A measurement set with a slider: its name and value on one line, an ink slider under it.
private struct ProfileSliderRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsValueRow(title: title, value: valueText, valueIsInk: true)
                .accessibilityHidden(true)

            // Stepped without `Slider(step:)`, which draws a tick per step on iOS 26 — the
            // same slider onboarding sets height and weight with.
            OnboardingSlider(value: $value, range: range, step: step, label: title)
                .tint(CalorynTheme.textPrimary)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
        .padding(.vertical, 2)
    }
}
