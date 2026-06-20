enum ProfileEditActivityLevelPolicy {
    static let lockedExplanation = "Auto-adjust uses Apple Health activity instead."

    static func isLocked(for profile: UserProfile) -> Bool {
        profile.effectiveEnergyCalculationMode == .dynamicHealth
    }
}
