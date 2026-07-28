import Foundation

/// How a day's logged Nutri-Score grades break down.
///
/// Takes the grades themselves rather than the entries. Two separate questions
/// live here and are deliberately not the same one: whether the day has any
/// grade at all (which decides if the card appears), and how the recognised
/// grades count up (which is what the card draws). A day whose only grade is
/// unrecognised still counts as having data — hiding the card would be claiming
/// the food was never graded.
enum NutriscoreDayDistribution {
    static let recognizedGrades = ["a", "b", "c", "d", "e"]

    /// Counts per recognised grade, in a-to-e order, omitting grades nothing was
    /// logged for. Matched case-insensitively: grades arrive from product data
    /// in both cases.
    static func distribution(of grades: [String?]) -> [(grade: String, count: Int)] {
        let logged = grades.compactMap { $0 }
        return recognizedGrades
            .map { grade in
                (grade, logged.filter { $0.lowercased() == grade }.count)
            }
            .filter { $0.count > 0 }
    }

    static func hasData(_ grades: [String?]) -> Bool {
        grades.contains { $0 != nil }
    }
}
