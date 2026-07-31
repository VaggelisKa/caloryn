import Testing
@testable import Caloryn

/// Covers the profile editor's draft: seeding, the discard contract, and the
/// save-time recalculation that used to be reachable only by driving the form.
@MainActor
@Suite("Profile edit draft")
struct ProfileEditDraftTests {

    // MARK: - Seeding

    @Test("Seeding from a profile copies every editable fact")
    func seedingCopiesTheProfile() {
        let profile = makeProfile()

        let draft = ProfileEditDraft(profile: profile)

        #expect(draft.age == profile.age)
        #expect(draft.sex == profile.sex)
        #expect(draft.heightCm == profile.heightCm)
        #expect(draft.weightKg == profile.weightKg)
        #expect(draft.activityLevel == profile.activityLevel)
    }

    // MARK: - Discard contract

    @Test("Mutating the draft leaves the profile untouched until apply")
    func mutationDoesNotTouchTheProfile() {
        let profile = makeProfile()
        let targetBefore = profile.dailyCalorieTarget

        var draft = ProfileEditDraft(profile: profile)
        draft.age = 55
        draft.sex = .female
        draft.heightCm = 150
        draft.weightKg = 95
        draft.activityLevel = .veryActive

        #expect(draft.age == 55)
        #expect(profile.age == 30)
        #expect(profile.sex == .male)
        #expect(profile.heightCm == 178)
        #expect(profile.weightKg == 78)
        #expect(profile.activityLevel == .moderatelyActive)
        #expect(profile.dailyCalorieTarget == targetBefore)
    }

    // MARK: - Apply

    @Test("Apply writes every edited fact back")
    func applyWritesAllFields() {
        let profile = makeProfile()

        var draft = ProfileEditDraft(profile: profile)
        draft.age = 41
        draft.sex = .female
        draft.heightCm = 165
        draft.weightKg = 61.5
        draft.activityLevel = .lightlyActive
        draft.apply(to: profile)

        #expect(profile.age == 41)
        #expect(profile.sex == .female)
        #expect(profile.heightCm == 165)
        #expect(profile.weightKg == 61.5)
        #expect(profile.activityLevel == .lightlyActive)
    }

    @Test("Apply moves the calorie target with the new facts")
    func applyRecalculatesTheTarget() {
        let profile = makeProfile()
        let targetBefore = profile.dailyCalorieTarget

        var draft = ProfileEditDraft(profile: profile)
        draft.weightKg = 110
        draft.activityLevel = .veryActive
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget > targetBefore)
    }

    /// The user's chosen split must survive the edit: the ratios are derived
    /// from the pre-edit targets and re-applied to the recalculated calorie
    /// target, so the grams move but the proportions do not.
    @Test("Apply preserves the macro split the saved grams represented")
    func applyPreservesTheMacroSplit() {
        let profile = makeProfile()
        // A deliberately non-default split, so preservation is distinguishable
        // from a silent reset to 30/40/30.
        profile.recalculate(proteinRatio: 0.40, carbRatio: 0.35, fatRatio: 0.25)
        let splitBefore = profile.macroRatios

        var draft = ProfileEditDraft(profile: profile)
        draft.weightKg = 110
        draft.activityLevel = .veryActive
        draft.apply(to: profile)

        let splitAfter = profile.macroRatios
        #expect(abs(splitAfter.protein - splitBefore.protein) < 0.01)
        #expect(abs(splitAfter.carbs - splitBefore.carbs) < 0.01)
        #expect(abs(splitAfter.fat - splitBefore.fat) < 0.01)

        // And the grams reconcile to the new target, proving the split was
        // re-applied rather than the old grams kept.
        let calories = profile.proteinTargetG * 4
            + profile.carbTargetG * 4
            + profile.fatTargetG * 9
        #expect(abs(calories - Double(profile.dailyCalorieTarget)) < 20)
    }

    @Test("Applying an unchanged draft leaves the targets where they were")
    func unchangedApplyIsAFixedPoint() {
        let profile = makeProfile()
        let targetBefore = profile.dailyCalorieTarget
        let proteinBefore = profile.proteinTargetG

        let draft = ProfileEditDraft(profile: profile)
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget == targetBefore)
        #expect(abs(profile.proteinTargetG - proteinBefore) < 0.01)
    }

    @Test("Apply respects a manual calorie override, recomputing only the grams")
    func applyKeepsAManualTarget() {
        let profile = makeProfile()
        profile.manualOverride = true
        profile.dailyCalorieTarget = 1_800

        var draft = ProfileEditDraft(profile: profile)
        draft.weightKg = 110
        draft.apply(to: profile)

        #expect(profile.dailyCalorieTarget == 1_800)
    }

    // MARK: - Helpers

    private func makeProfile() -> UserProfile {
        UserProfile(
            age: 30,
            sex: .male,
            heightCm: 178,
            weightKg: 78,
            activityLevel: .moderatelyActive
        )
    }
}
