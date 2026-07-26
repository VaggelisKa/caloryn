#if DEBUG
import Foundation

/// Launch-argument contract between the app and `CalorynUITests`.
///
/// UI tests must never depend on state left behind by an earlier test, so the
/// app swaps in a fresh in-memory store and seeds a named fixture when these
/// arguments are present. All of this is compiled out of release builds.
enum UITestConfiguration {
    /// Presence of this flag switches the app to an in-memory store with
    /// CloudKit disabled, so each launch starts from a known-empty database.
    static let resetFlag = "-uitest-reset"

    /// Followed by a `Fixture` raw value, e.g. `-uitest-seed loggedDay`.
    static let seedFlag = "-uitest-seed"

    /// Named starting states a UI test can request.
    enum Fixture: String {
        /// No profile at all, so the app opens onboarding.
        case empty
        /// A completed profile with no logged food.
        case profileOnly
        /// A profile plus one breakfast entry logged today.
        case loggedDay
        /// A profile plus reusable custom foods, one of them favorited.
        case customFoods
        /// A profile plus thirty days of entries, for History assertions.
        case history
        /// Exact historical targets and entries that produce one recurring History pattern.
        case historyPattern
        /// Exact historical targets and entries that intentionally produce no recurring pattern.
        case historyNoPattern
    }

    static var isActive: Bool {
        arguments.contains(resetFlag)
    }

    static var fixture: Fixture? {
        guard let flagIndex = arguments.firstIndex(of: seedFlag),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Fixture(rawValue: arguments[flagIndex + 1])
    }

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }
}
#endif
